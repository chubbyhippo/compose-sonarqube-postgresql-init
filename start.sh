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
# Starts the stack and waits until SonarQube answers. Triggers a database
# migration automatically after an image upgrade.
set -eu
cd "$(dirname "$0")"

URL=http://localhost:9000

docker compose up -d

printf 'waiting for SonarQube'
migrated=""
i=0
while [ "$i" -lt 120 ]; do
  i=$((i + 1))
  status=$(curl -s -m 5 "$URL/api/system/status" 2>/dev/null | sed -n 's/.*"status":"\([A-Z_]*\)".*/\1/p' || true)
  case "$status" in
    UP)
      printf '\n'
      echo "SonarQube ready at $URL"
      exit 0 ;;
    DB_MIGRATION_NEEDED)
      if [ -z "$migrated" ]; then
        printf '\ntriggering database migration\n'
        curl -s -X POST "$URL/api/system/migrate_db" >/dev/null || true
        migrated=1
      fi ;;
  esac
  state=$(docker compose ps --format '{{.State}}' sonarqube 2>/dev/null || true)
  case "$state" in
    exited|dead)
      printf '\n'
      echo "SonarQube container stopped unexpectedly; last logs:"
      docker compose logs --no-color --tail 25 sonarqube || true
      exit 1 ;;
  esac
  printf '.'
  sleep 5
done
printf '\n'
echo "timed out - check: docker compose logs sonarqube"
exit 1
