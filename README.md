# SonarQube + PostgreSQL

Local SonarQube (community build) on Docker Compose. All state lives in
named docker volumes - no database dumps, nothing secret in git.

## First time
```sh
./setup.sh
```
Starts the stack and configures everything (user, admin password, token).
Re-running it is safe; it skips whatever is already done.

## Afterwards
```sh
./start.sh
./stop.sh
```

## Login
http://localhost:9000
```
test
test
```
`setup.sh` deactivates the built-in `admin` account (`test` is an administrator).

## Token
`setup.sh` writes an analysis token to `.sonar-token` (git-ignored, chmod 600).

## Maven
```sh
mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=$(cat .sonar-token)
```

## Gradle
```sh
gradle test jacocoTestReport sonar -Dsonar.gradle.skipCompile=true -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=$(cat .sonar-token)
```

## Backup / restore
```sh
./exportdb.sh                # dump the database to sonar-<timestamp>.sql
./importdb.sh <dump.sql>     # REPLACE the database with a dump and restart
```
Dumps are plain `pg_dump` SQL and git-ignored. Importing a dump from an
older SonarQube version triggers the database migration on start - but only
within SonarQube's supported upgrade path; otherwise the startup log names
the intermediate version to go through first.

## Upgrading SonarQube
Bump the `sonarqube:` image tag in `compose.yaml`, then `./start.sh` -
if the new version needs a database migration it is triggered automatically.

## Full reset
```sh
docker compose down -v && ./setup.sh
```

## License
GPL-3.0-or-later - see [LICENSE](LICENSE). Scripts are POSIX sh.
