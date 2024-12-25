# Using sonar
## user/pass
```
admin
test
```
## token
```
sqp_f55ba45dd77c7b7785478b6f8e9a836c4c3aa070
```
## maven
```sh
mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_f55ba45dd77c7b7785478b6f8e9a836c4c3aa070
```
## gradle
```sh
gradle test jacocoTestReport sonar -Dsonar.gradle.skipCompile=true -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_f55ba45dd77c7b7785478b6f8e9a836c4c3aa070
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


