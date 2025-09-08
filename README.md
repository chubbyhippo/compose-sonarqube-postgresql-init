# Using sonar
## user/pass
```
admin
777777777aA_
```
## token
```
sqp_87765b5ff81b753f3fa7c52f802534fb065403c0
```
## maven
```sh
mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_87765b5ff81b753f3fa7c52f802534fb065403c0
```
## gradle
```sh
gradle test jacocoTestReport sonar -Dsonar.gradle.skipCompile=true -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_87765b5ff81b753f3fa7c52f802534fb065403c0
```
# Updating sonar
## remove init.sql
```sh
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch init.sql" --prune-empty --tag-name-filter cat -- --all
```
```sh
git push origin --force --all
```
```sh
git push origin --force --tags
```
## update init.sql
```sh
PGPASSWORD=sonar pg_dump -h localhost -p 6666 -U sonar -d sonar -f init.sql
```


