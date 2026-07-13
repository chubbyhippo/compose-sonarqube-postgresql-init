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
# Dumps the SonarQube PostgreSQL database to a plain SQL file. The dump is
# a consistent snapshot; the stack may keep running while it is taken.
# Usage: ./exportdb.sh [file]   (default: sonar-<timestamp>.sql)
set -eu
cd "$(dirname "$0")"

OUT="${1:-sonar-$(date +%Y%m%d-%H%M%S).sql}"
if [ -e "$OUT" ]; then
  echo "refusing to overwrite existing $OUT"
  exit 1
fi

docker compose up -d --wait db

echo "dumping database to $OUT"
if ! docker compose exec -T db pg_dump -U sonar -d sonar > "$OUT"; then
  rm -f "$OUT"
  echo "pg_dump failed"
  exit 1
fi
echo "done: $OUT ($(wc -c < "$OUT") bytes)"
