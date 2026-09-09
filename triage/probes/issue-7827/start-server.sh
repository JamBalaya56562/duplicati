#!/bin/bash
# Starts the Debug server the way the Synology package does, with the fake DSM CGI scripts.
# $1 = webroot folder (empty for the build's own webroot, which has the released ngclient)
S=/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/fakesyno
W=$(cygpath -w $S)
cd /c/Users/Jam/Documents/duplicati/Executables/Duplicati.Server/bin/Debug/net10.0
EXTRA=()
[ -n "$1" ] && EXTRA=(--webservice-webroot="$(cygpath -w "$1")")
export SYNO_DSM_AUTH_ENABLED=1
export SYNO_AUTHENTICATE_CGI="$W\\authenticate.cmd"
export SYNO_LOGIN_CGI="$W\\login.cmd"
export SYNO_ALL_USERS=1
export DUPLICATI_XSRF_FORWARDING_CONFIG="X-Syno-Token,SynoToken"
export DUPLICATI_ENABLE_IFRAME_HOSTING=true
export DUPLICATI__WEBSERVICE_PRE_AUTH_TOKENS=prekey-1234567890
export DUPLICATI__WEBSERVICE_PASSWORD=fake-test-password-1
export SETTINGS_ENCRYPTION_KEY=fake-test-key-1
exec /c/Users/Jam/AppData/Local/mise/dotnet-root/dotnet.exe Duplicati.Server.dll --webservice-allowed-hostnames="*" \
  --server-datafolder="$W\\data" --webservice-interface=loopback --webservice-port=8211 "${EXTRA[@]}" > $S/server.log 2>&1
