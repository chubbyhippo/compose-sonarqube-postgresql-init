# Using sonar
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
```
gradle test jacocoTestReport sonar -Dsonar.gradle.skipCompile=true -Dsonar.projectKey=test -Dsonar.projectName='test' -Dsonar.host.url=http://localhost:9000 -Dsonar.token=sqp_b23983382be5cbdc2f376768490d21b404158fd3
```


