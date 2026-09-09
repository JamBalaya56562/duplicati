#!/bin/bash
#
# Captures the D-Bus introspection XML that `secrets.DBus.cs` is generated from.
#
# The recorded generation command introspects a live service:
#
#     dotnet dbus codegen --protocol-api --service org.freedesktop.secrets
#
# which needs a Linux session bus with a Secret Service implementation. This
# script stands one up in a container and dumps every object the generated file
# covers, so the XML can be kept under version control and regenerated anywhere.
#
# Usage:
#     docker run --rm -i ubuntu:22.04 bash -s < capture-secrets-introspection.sh > raw.txt
#
# Then keep the <interface> elements from raw.txt, drop the org.freedesktop.DBus.*
# standard ones, wrap what is left in a single <node>, and feed that to:
#
#     dotnet dbus codegen --protocol-api --namespace secrets.DBus merged.xml
#
# Three things are easy to get wrong, and all three cost interfaces silently:
#
#   * Objects that do not exist cannot be introspected, so a collection and an
#     item have to be created first. `--recurse` from /org/freedesktop/secrets
#     does not descend far enough on its own.
#   * Sessions and prompts live only as long as the connection that created
#     them. Each `gdbus` invocation opens its own connection, so by the time the
#     next command runs they are gone. They are created and introspected from
#     one Python connection below.
#   * org.freedesktop.impl.portal.Secret looks like it belongs to another
#     service, but gnome-keyring publishes it itself under a different path.
#
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq gnome-keyring dbus python3-dbus python3-secretstorage >/dev/null 2>&1

cat > /tmp/capture-inner.sh <<'INNER'
#!/bin/bash
set -euo pipefail

echo -n pw | gnome-keyring-daemon --unlock --components=secrets >/dev/null 2>&1 &
sleep 4

python3 - <<'PY'
import dbus
import secretstorage

# An item has to exist before the Item object can be introspected.
sc = secretstorage.dbus_init()
collection = secretstorage.get_default_collection(sc)
collection.create_item('probe', {'application': 'probe'}, b'secret')

bus = dbus.SessionBus()
DEST = 'org.freedesktop.secrets'


def xml_of(path):
    obj = bus.get_object(DEST, path)
    return str(obj.Introspect(dbus_interface='org.freedesktop.DBus.Introspectable'))


service = dbus.Interface(
    bus.get_object(DEST, '/org/freedesktop/secrets'),
    'org.freedesktop.Secret.Service')

# Sessions and prompts belong to this connection, so they are made and read here.
_output, session_path = service.OpenSession('plain', dbus.String('', variant_level=1))

login = '/org/freedesktop/secrets/collection/login'
service.Lock([login])
_unlocked, prompt_path = service.Unlock([login])

paths = [
    '/org/freedesktop/secrets',      # Secret.Service, InternalUnsupportedGuiltRiddenInterface
    login,                           # Secret.Collection
    login + '/1',                    # Secret.Item
    str(session_path),               # Secret.Session
    '/org/freedesktop/portal/desktop',  # impl.portal.Secret
]
if str(prompt_path) != '/':
    paths.append(str(prompt_path))   # Secret.Prompt

for path in paths:
    print('@@@PATH ' + path)
    print(xml_of(path))
PY
INNER

chmod +x /tmp/capture-inner.sh
dbus-run-session -- /tmp/capture-inner.sh
