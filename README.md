# Using sonar
## first time
```sh
./setup.sh
```
## start/stop
```sh
./start.sh
```
```sh
./stop.sh
```
## user/pass
http://localhost:9000
```
test
test
```
## token
```sh
eval "$(./env.sh)"
```
exports SONAR_TOKEN and SONAR_HOST_URL, the scanners pick them up
## maven
```sh
mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=$(cat .sonar-token)
```
## gradle
```sh
gradle test jacocoTestReport sonar -Dsonar.gradle.skipCompile=true -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=$(cat .sonar-token)
```
# Maintaining sonar
## export/import db
```sh
./exportdb.sh
```
```sh
./importdb.sh dump.sql
```
imports must be within sonarqube's supported upgrade path
## upgrade
bump the image tag in compose.yaml, then
```sh
./start.sh
```
## reset
```sh
docker compose down -v && ./setup.sh
```
# H2 variant
evaluation only, no export/import, data does not survive upgrades
```sh
COMPOSE_FILE=compose-h2.yaml ./setup.sh
```
same for start.sh/stop.sh, rerun setup.sh after switching variants
# License
GPL-3.0-or-later, see [LICENSE](LICENSE)
