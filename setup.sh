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
# First-time setup: starts the stack, creates the test/test user, gives it
# admin rights, neutralizes the default admin password, and writes an
# analysis token to .sonar-token. Leaves SonarQube running when done.
# Safe to re-run: skips whatever is already configured.
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

command -v docker >/dev/null 2>&1 || { echo "docker not found in PATH"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose v2 not available"; exit 1; }

# SonarQube's embedded Elasticsearch refuses to start below this
REQUIRED_MAP_COUNT=524288
current=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
if [ "$current" -lt "$REQUIRED_MAP_COUNT" ]; then
  say "raising vm.max_map_count from $current to $REQUIRED_MAP_COUNT (needs sudo)"
  sudo sysctl -w vm.max_map_count="$REQUIRED_MAP_COUNT"
fi

say "starting containers"
docker compose up -d

say "waiting for SonarQube at $URL"
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
        say "database migration needed - triggering it"
        curl -s -X POST "$URL/api/system/migrate_db" >/dev/null || true
        migrated=1
      fi ;;
  esac
  state=$(docker compose ps --format '{{.State}}' sonarqube 2>/dev/null || true)
  case "$state" in
    exited|dead)
      echo "SonarQube container stopped unexpectedly; last logs:"
      docker compose logs --no-color --tail 25 sonarqube || true
      exit 1 ;;
  esac
  sleep 5
done
if [ "$status" != "UP" ]; then
  echo "timed out waiting for SonarQube; last logs:"
  docker compose logs --tail 30 sonarqube || true
  exit 1
fi
echo "SonarQube $(curl -s "$URL/api/server/version") is UP"

valid() { curl -s -u "$1:$2" "$URL/api/authentication/validate" | grep -q '"valid":true'; }

# req METHOD URL USER:PASS [curl args...]
# response body ends up in $body; fails when http status >= 400
req() {
  req_method=$1; req_url=$2; req_auth=$3
  shift 3
  req_code=$(curl -s -o "$RESP" -w '%{http_code}' -u "$req_auth" -X "$req_method" "$req_url" "$@") || return 1
  body=$(cat "$RESP" 2>/dev/null || true)
  [ "$req_code" -lt 400 ]
}

# id of the JSON object (on stdin) whose field $1 equals $2
obj_id() { tr '{' '\n' | grep "\"$1\":\"$2\"" | head -n 1 | tr ',' '\n' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n 1; }

if valid "$SONAR_USER" "$SONAR_PASS"; then
  say "user $SONAR_USER/$SONAR_PASS already works - skipping account setup"
else
  if ! valid admin admin; then
    echo "neither $SONAR_USER/$SONAR_PASS nor admin/admin can log in."
    echo "this instance was configured with different credentials."
    echo "full reset: docker compose down -v && ./setup.sh"
    exit 1
  fi

  say "creating user $SONAR_USER"
  if ! req POST "$URL/api/users/create" admin:admin \
       --data "login=$SONAR_USER&name=$SONAR_USER&password=$SONAR_PASS"; then
    # v1 endpoint removed in newer versions - fall back to v2
    req POST "$URL/api/v2/users-management/users" admin:admin \
      -H 'Content-Type: application/json' \
      --data "{\"login\":\"$SONAR_USER\",\"name\":\"$SONAR_USER\",\"password\":\"$SONAR_PASS\"}" \
      || { echo "user creation failed: $body"; exit 1; }
  fi

  say "granting administrator rights to $SONAR_USER"
  if ! req POST "$URL/api/user_groups/add_user" admin:admin \
       --data "name=sonar-administrators&login=$SONAR_USER"; then
    # v1 endpoint removed in newer versions - fall back to v2
    gid=$(curl -s -u admin:admin "$URL/api/v2/authorizations/groups?q=sonar-administrators" | obj_id name sonar-administrators || true)
    uid=$(curl -s -u admin:admin "$URL/api/v2/users-management/users?q=$SONAR_USER" | obj_id login "$SONAR_USER" || true)
    if [ -z "$gid" ] || [ -z "$uid" ]; then echo "could not resolve group/user ids"; exit 1; fi
    req POST "$URL/api/v2/authorizations/group-memberships" admin:admin \
      -H 'Content-Type: application/json' \
      --data "{\"userId\":\"$uid\",\"groupId\":\"$gid\"}" \
      || { echo "granting admin rights failed: $body"; exit 1; }
  fi

  valid "$SONAR_USER" "$SONAR_PASS" || { echo "sanity check failed: $SONAR_USER cannot log in"; exit 1; }
fi

# runs on every invocation so a partially configured instance gets repaired
if valid admin admin; then
  say "deactivating built-in admin account (still has default password)"
  if ! req POST "$URL/api/users/deactivate" "$SONAR_USER:$SONAR_PASS" --data "login=admin"; then
    # v1 endpoint removed in newer versions - fall back to v2
    admin_id=$(curl -s -u "$SONAR_USER:$SONAR_PASS" "$URL/api/v2/users-management/users?q=admin" | obj_id login admin || true)
    [ -n "$admin_id" ] || { echo "could not resolve admin user id"; exit 1; }
    req DELETE "$URL/api/v2/users-management/users/$admin_id" "$SONAR_USER:$SONAR_PASS" \
      || { echo "deactivating admin failed: $body"; exit 1; }
  fi
fi

if [ ! -s "$TOKEN_FILE" ]; then
  say "generating analysis token -> $TOKEN_FILE"
  curl -s -u "$SONAR_USER:$SONAR_PASS" -X POST "$URL/api/user_tokens/revoke" --data "name=$TOKEN_NAME" >/dev/null || true
  resp=$(curl -s -u "$SONAR_USER:$SONAR_PASS" -X POST "$URL/api/user_tokens/generate" --data "name=$TOKEN_NAME" || true)
  token=$(printf '%s' "$resp" | tr ',' '\n' | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' | head -n 1 || true)
  [ -n "$token" ] || { echo "token generation failed: $resp"; exit 1; }
  printf '%s\n' "$token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE" 2>/dev/null || true
fi

say "done"
echo "  url:    $URL"
echo "  login:  $SONAR_USER / $SONAR_PASS   (built-in admin account is deactivated)"
echo "  token:  stored in $TOKEN_FILE"
echo "  scan:   mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.host.url=$URL -Dsonar.token=\$(cat $TOKEN_FILE)"
