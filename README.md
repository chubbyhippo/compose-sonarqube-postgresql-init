## user/pass
```
admin
test
```
## maven

```
mvn clean verify sonar:sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_b23983382be5cbdc2f376768490d21b404158fd3
```
## gradle
### build.gradle
```
plugins {
  id "org.sonarqube" version "4.2.1.3168"
}
```
### build.gradle.kts
```
plugins {
  id("org.sonarqube") version "4.2.1.3168"
}
```
### run
```
./gradlew sonar -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_b23983382be5cbdc2f376768490d21b404158fd3
```
