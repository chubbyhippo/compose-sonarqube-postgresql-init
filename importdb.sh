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
# REPLACES the SonarQube database with the given pg_dump SQL file, wipes
# the search index so it rebuilds from the restored data, and restarts
# SonarQube. Credentials/tokens become whatever the dump contains.
# Usage: ./importdb.sh <dump.sql>
set -eu
cd "$(dirname "$0")"

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: $0 <dump.sql>"
  exit 1
fi
IN=$1

if ! head -n 5 "$IN" | grep -q 'PostgreSQL database dump'; then
  echo "$IN does not look like a pg_dump SQL file"
  exit 1
fi

docker compose up -d --wait db

echo "stopping SonarQube"
docker compose stop sonarqube

echo "recreating database from $IN"
docker compose exec -T db psql -U sonar -d postgres -q -v ON_ERROR_STOP=1 \
  -c 'DROP DATABASE IF EXISTS sonar WITH (FORCE);'
docker compose exec -T db psql -U sonar -d postgres -q -v ON_ERROR_STOP=1 \
  -c 'CREATE DATABASE sonar OWNER sonar;'
docker compose exec -T db psql -U sonar -d sonar -q -v ON_ERROR_STOP=1 < "$IN" >/dev/null

echo "clearing search index (rebuilt on next start)"
docker compose run --rm --no-deps --entrypoint /bin/sh sonarqube -c 'rm -rf /opt/sonarqube/data/es*'

./start.sh
echo "import done - credentials and tokens are whatever the dump contains"
