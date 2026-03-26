@ECHO OFF
SET DIR=%~dp0
SET WRAPPER_JAR=%DIR%\gradle\wrapper\gradle-wrapper.jar
SET WRAPPER_SHARED_JAR=%DIR%\gradle\wrapper\gradle-wrapper-shared.jar
IF NOT EXIST "%WRAPPER_JAR%" (
  ECHO Gradle wrapper jar missing at %WRAPPER_JAR%
  EXIT /B 1
)
IF NOT EXIST "%WRAPPER_SHARED_JAR%" (
  ECHO Gradle wrapper shared jar missing at %WRAPPER_SHARED_JAR%
  EXIT /B 1
)
java -Xmx64m -classpath "%WRAPPER_JAR%;%WRAPPER_SHARED_JAR%" org.gradle.wrapper.GradleWrapperMain %*
