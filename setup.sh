#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 compose-sonarqube-postgresql-init contributors
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# first-time setup, safe to re-run
set -eu
cd "$(dirname "$0")"

URL=http://localhost:9000
SONAR_USER=test
SONAR_PASS=test
TOKEN_FILE=.sonar-token
TOKEN_NAME=cli

RESP="${TMPDIR:-/tmp}/sonar-setup-resp.$$"
trap 'rm -f "$RESP"' EXIT INT HUP TERM

say() { printf '\n== %s\n' "$*"; }

command -v docker >/dev/null 2>&1 || { echo "docker not found"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose not found"; exit 1; }

# elasticsearch won't start below this
REQUIRED_MAP_COUNT=524288
current=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
if [ "$current" -lt "$REQUIRED_MAP_COUNT" ]; then
  say "raising vm.max_map_count to $REQUIRED_MAP_COUNT"
  sudo sysctl -w vm.max_map_count="$REQUIRED_MAP_COUNT"
fi

say "starting containers"
docker compose up -d

say "waiting for sonarqube"
migrated=""
status=""
i=0
while [ "$i" -lt 120 ]; do
  i=$((i + 1))
  status=$(curl -s -m 5 "$URL/api/system/status" 2>/dev/null | sed -n 's/.*"status":"\([A-Z_]*\)".*/\1/p' || true)
  case "$status" in
    UP) break ;;
    DB_MIGRATION_NEEDED)
      if [ -z "$migrated" ]; then
        say "migrating database"
        curl -s -X POST "$URL/api/system/migrate_db" >/dev/null || true
        migrated=1
      fi ;;
  esac
  state=$(docker compose ps -a --format '{{.State}}' sonarqube 2>/dev/null || true)
  case "$state" in
    exited|dead)
      echo "sonarqube died, logs:"
      docker compose logs --no-color --tail 25 sonarqube || true
      exit 1 ;;
  esac
  sleep 5
done
if [ "$status" != "UP" ]; then
  echo "timed out, logs:"
  docker compose logs --tail 30 sonarqube || true
  exit 1
fi
echo "sonarqube $(curl -s "$URL/api/server/version") is up"

valid() { curl -s -u "$1:$2" "$URL/api/authentication/validate" | grep -q '"valid":true'; }

# req METHOD URL USER:PASS [curl args...], body in $body, fails on http >= 400
req() {
  req_method=$1; req_url=$2; req_auth=$3
  shift 3
  req_code=$(curl -s -o "$RESP" -w '%{http_code}' -u "$req_auth" -X "$req_method" "$req_url" "$@") || return 1
  body=$(cat "$RESP" 2>/dev/null || true)
  [ "$req_code" -lt 400 ]
}

# id of the json object whose field $1 equals $2
obj_id() { tr '{' '\n' | grep "\"$1\":\"$2\"" | head -n 1 | tr ',' '\n' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n 1; }

if valid "$SONAR_USER" "$SONAR_PASS"; then
  say "user $SONAR_USER already set up"
else
  if ! valid admin admin; then
    echo "cannot log in with $SONAR_USER/$SONAR_PASS or admin/admin"
    echo "reset with: docker compose down -v && ./setup.sh"
    exit 1
  fi

  say "creating user $SONAR_USER"
  if ! req POST "$URL/api/users/create" admin:admin \
       --data "login=$SONAR_USER&name=$SONAR_USER&password=$SONAR_PASS"; then
    # v2 fallback for versions without the v1 api
    req POST "$URL/api/v2/users-management/users" admin:admin \
      -H 'Content-Type: application/json' \
      --data "{\"login\":\"$SONAR_USER\",\"name\":\"$SONAR_USER\",\"password\":\"$SONAR_PASS\"}" \
      || { echo "user creation failed: $body"; exit 1; }
  fi

  say "granting admin rights"
  if ! req POST "$URL/api/user_groups/add_user" admin:admin \
       --data "name=sonar-administrators&login=$SONAR_USER"; then
    gid=$(curl -s -u admin:admin "$URL/api/v2/authorizations/groups?q=sonar-administrators" | obj_id name sonar-administrators || true)
    uid=$(curl -s -u admin:admin "$URL/api/v2/users-management/users?q=$SONAR_USER" | obj_id login "$SONAR_USER" || true)
    if [ -z "$gid" ] || [ -z "$uid" ]; then echo "could not resolve ids"; exit 1; fi
    req POST "$URL/api/v2/authorizations/group-memberships" admin:admin \
      -H 'Content-Type: application/json' \
      --data "{\"userId\":\"$uid\",\"groupId\":\"$gid\"}" \
      || { echo "granting admin rights failed: $body"; exit 1; }
  fi

  valid "$SONAR_USER" "$SONAR_PASS" || { echo "$SONAR_USER cannot log in"; exit 1; }
fi

if valid admin admin; then
  say "deactivating built-in admin"
  if ! req POST "$URL/api/users/deactivate" "$SONAR_USER:$SONAR_PASS" --data "login=admin"; then
    admin_id=$(curl -s -u "$SONAR_USER:$SONAR_PASS" "$URL/api/v2/users-management/users?q=admin" | obj_id login admin || true)
    [ -n "$admin_id" ] || { echo "could not resolve admin id"; exit 1; }
    req DELETE "$URL/api/v2/users-management/users/$admin_id" "$SONAR_USER:$SONAR_PASS" \
      || { echo "deactivating admin failed: $body"; exit 1; }
  fi
fi

token_valid() { [ -s "$TOKEN_FILE" ] && curl -s -u "$(cat "$TOKEN_FILE"):" "$URL/api/authentication/validate" | grep -q '"valid":true'; }

if ! token_valid; then
  say "generating token"
  curl -s -u "$SONAR_USER:$SONAR_PASS" -X POST "$URL/api/user_tokens/revoke" --data "name=$TOKEN_NAME" >/dev/null || true
  resp=$(curl -s -u "$SONAR_USER:$SONAR_PASS" -X POST "$URL/api/user_tokens/generate" --data "name=$TOKEN_NAME" || true)
  token=$(printf '%s' "$resp" | tr ',' '\n' | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -n 1 || true)
  [ -n "$token" ] || { echo "token generation failed: $resp"; exit 1; }
  printf '%s\n' "$token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE" 2>/dev/null || true
fi

say "done"
echo "  $URL"
echo "  $SONAR_USER / $SONAR_PASS"
echo "  token in $TOKEN_FILE"
echo '  eval "$(./env.sh)" to export SONAR_TOKEN'
