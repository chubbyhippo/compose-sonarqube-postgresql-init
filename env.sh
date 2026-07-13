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
# Prints export statements for the SonarQube token and server URL.
# A child process cannot modify its parent shell's environment, so load
# these into your current shell with:
#   eval "$(./env.sh)"
# The sonar scanners (CLI/Maven/Gradle) read SONAR_TOKEN and SONAR_HOST_URL
# automatically. On failure nothing is printed and the error goes to stderr.
set -eu
cd "$(dirname "$0")"

if [ ! -s .sonar-token ]; then
  echo "no .sonar-token found - run ./setup.sh first" >&2
  exit 1
fi
printf "export SONAR_TOKEN='%s'\n" "$(cat .sonar-token)"
printf "export SONAR_HOST_URL='%s'\n" "http://localhost:9000"
