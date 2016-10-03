# Sesame Gatling Tests

## Overview
Project containing stress and functional integration tests for various Sesame projects using the Gatling framework. See https://gatling.io.

Each test will generate HTML reports which are created in: `target/gatling/results.`

Tests are placed in the `com.sesamecom.loadtest` package.


## Requirements
* Maven
* Java 8


## Running Tests from the Command Line

### Send-CB-Listener Tests:
#### Functional Smoke Screen Test
```
mvn gatling:test
    -Dgatling.simulationClass=com.sesamecom.loadtest.sendcallbacklistener.ListenerFunctionalTest
    -DtargetBaseUrl=http://localhost:9997
```
#### Load Test
```
mvn gatling:test
    -Dgatling.simulationClass=com.sesamecom.loadtest.sendcallbacklistener.ListenerStressTest
    -DtargetBaseUrl=http://localhost:9997
```
#### Command Line Parameters

Parameter | Description
----------|------------
gatling:test | maven goal which invokes Gatling to run a test
gatling.simulationClass | Class name of the test to run. This is required when multiple tests are found.
targetBaseUrl | Sesame specific property which sets the target base URL for the test.


### Stats Service Functional Smokescreen Test:
```
mvn gatling:test 
    -Dgatling.simulationClass=com.sesamecom.loadtest.statservice.StatsFunctionalTest 
    -DstatsUrl=http://localhost:9998
```



## Working on systems with both Java 6 and 8
Gatling requires Java 8. Maven primarily uses the JAVA_HOME environmental variable to determine which version to use. Also be weary of compiler targets in the core settings.xml file.

Setting the JAVA_HOME to use Java 8 instead of 6. The scope of this change will only be within the console the command was run.
```
set JAVA_HOME=C:\Program Files\Java\jdk1.8.0_66
```

Verify which Java Maven is using
```
mvn -version
Maven home: C:\files\programs\apache-maven-3.2.5\bin\..
Java version: 1.8.0_66, vendor: Oracle Corporation
Java home: C:\Program Files\Java\jdk1.8.0_66\jre
Default locale: en_US, platform encoding: Cp1252
OS name: "windows 7", version: "6.1", arch: "amd64", family: "dos"
```


## References
* Gatling Framework: http://gatling.io
* Gatling Maven Plugin: http://gatling.io/docs/2.2.2/extensions/maven_archetype.html
