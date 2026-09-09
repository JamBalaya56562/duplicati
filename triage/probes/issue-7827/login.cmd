@echo off
rem Stands in for DSM's login.cgi: returns the session's SynoToken
echo %TIME% login cookie=[%HTTP_COOKIE%]>> "%~dp0auth.log"
echo {"SynoToken":"testsynotoken123"}
