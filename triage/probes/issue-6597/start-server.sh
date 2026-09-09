#!/bin/bash
# Starts the Debug server with its own data folder; the proxy in ../fakesyno adds the PreAuth header, so the UI opens without a login
S=/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/r6597
W=$(cygpath -w $S)
mkdir -p $S/data
cd /c/Users/Jam/Documents/duplicati/Executables/Duplicati.Server/bin/Debug/net10.0
export DUPLICATI__WEBSERVICE_PRE_AUTH_TOKENS=prekey-1234567890
export DUPLICATI__WEBSERVICE_PASSWORD=fake-test-password-2
export SETTINGS_ENCRYPTION_KEY=fake-test-key-2
exec /c/Users/Jam/AppData/Local/mise/dotnet-root/dotnet.exe Duplicati.Server.dll --webservice-allowed-hostnames="*" \
  --server-datafolder="$W\\data" --webservice-interface=loopback --webservice-port=8211 \
  --log-file="$W\\server.log" --log-level=Verbose > $S/server.out 2>&1
