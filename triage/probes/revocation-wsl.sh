#!/usr/bin/env bash
# Runs in WSL. $1 = Windows-side scratch directory as a /mnt/c path.
set -u
SCR="$1"
WORK="$HOME/revprobe"
export PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet"
if [ ! -x "$HOME/.dotnet/dotnet" ]; then
  curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir "$HOME/.dotnet" | tail -1
fi
dotnet --version || exit 2
rm -rf "$WORK"; mkdir -p "$WORK/tree" "$WORK/pki/trust" || exit 2
tar -xf "$SCR/send-mail.tar" -C "$WORK/tree" || exit 2
cp "$SCR/RevocationProbeTests.cs" "$WORK/tree/Duplicati/UnitTest/" || exit 2

# PKI: a private CA, trusted only through SSL_CERT_DIR in the test process
cd "$WORK/pki" || exit 2
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 3 -subj "/CN=probe-ca" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -keyout other.key -out other.crt -days 3 -subj "/CN=other-ca" -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null
cp ca.crt trust/; openssl rehash trust >/dev/null 2>&1
leaf() { # name ca san
  openssl req -newkey rsa:2048 -nodes -keyout "$1.key" -out "$1.csr" -subj "/CN=$1" 2>/dev/null
  cat > "$1.ext" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=$3
crlDistributionPoints=URI:http://127.0.0.1:9/probe.crl
authorityInfoAccess=OCSP;URI:http://127.0.0.1:9/ocsp
EOF
  openssl x509 -req -in "$1.csr" -CA "$2.crt" -CAkey "$2.key" -CAcreateserial -days 2 -sha256 -extfile "$1.ext" -out "$1.crt" 2>/dev/null
}
leaf unreachable ca "IP:127.0.0.1,DNS:localhost"
leaf untrusted other "IP:127.0.0.1,DNS:localhost"
leaf wrongname ca "DNS:not-this-host.example"
openssl x509 -in unreachable.crt -noout -ext crlDistributionPoints,authorityInfoAccess,subjectAltName

export PROBE_DIR="$WORK/pki" SSL_CERT_DIR="$WORK/pki/trust"
unset SSL_CERT_FILE
cd "$WORK/tree" || exit 2
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj -c Debug --filter "FullyQualifiedName~RevocationProbeTests" --logger "console;verbosity=normal" > "$WORK/test.log" 2>&1
echo "test rc=$?"
tr -d '\000' < "$WORK/test.log" | grep -aE 'PROBE |^\s*(Passed|Failed|Skipped) |Passed!|Failed!|error CS|Total tests|Expected|But was' | cut -c1-200
cp "$WORK/test.log" "$SCR/revprobe-test.log"
