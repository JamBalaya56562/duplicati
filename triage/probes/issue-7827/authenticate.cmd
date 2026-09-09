@echo off
rem Stands in for DSM's authenticate.cgi: accepts the request only with the expected X-Syno-Token
echo %TIME% authenticate token=[%HTTP_X_SYNO_TOKEN%] cookie=[%HTTP_COOKIE%]>> "%~dp0auth.log"
if "%HTTP_X_SYNO_TOKEN%"=="testsynotoken123" (
  echo admin
  exit /b 0
)
exit /b 5
