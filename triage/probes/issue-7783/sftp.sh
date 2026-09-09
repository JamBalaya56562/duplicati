#!/bin/bash
# SFTP fixture for #7783: user "fixture", files with a nested folder, an accented name and an empty file.
set -e
apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server >/dev/null
useradd -m fixture
echo 'fixture:fixture-7783-only' | chpasswd
mkdir -p /home/fixture/data/album/disc1
printf 'SFTP root file\n' > /home/fixture/data/track.txt
printf 'SFTP nested file\n' > /home/fixture/data/album/disc1/été.txt
: > /home/fixture/data/empty.txt
chown -R fixture:fixture /home/fixture
mkdir -p /run/sshd
echo ready
exec /usr/sbin/sshd -D -e -o PasswordAuthentication=yes
