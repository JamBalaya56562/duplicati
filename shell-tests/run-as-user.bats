#!/usr/bin/env bats
#
# Tests for the entrypoint of the Docker images, ReleaseBuilder/Resources/Docker/run-as-user.sh.
# The commands that need root (groupadd, useradd, chown, su) and the command the container
# runs are replaced by stand-ins on the path, which record how they were called.

SCRIPT="$BATS_TEST_DIRNAME/../ReleaseBuilder/Resources/Docker/run-as-user.sh"

setup() {
    STUBS="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls"
    mkdir -p "$STUBS"
    : > "$CALLS"

    # Records the call, and exits with the code in STUB_<NAME>_EXIT (0 if not set)
    for name in groupadd useradd chown; do
        stub "$name" "echo \"$name \$*\" >> \"$CALLS\"; exit \${STUB_${name^^}_EXIT:-0}"
    done

    # getent group <gid> and id -u <uid> succeed only if the group or user exists
    stub getent "echo \"getent \$*\" >> \"$CALLS\"; [ \"\${STUB_GROUP_EXISTS:-no}\" = yes ]"
    stub id "echo \"id \$*\" >> \"$CALLS\"; [ \"\${STUB_USER_EXISTS:-no}\" = yes ]"

    # su <user> -c <command>: records the user and runs the command as the shell would
    stub su "echo \"su \$1 \$2\" >> \"$CALLS\"; exec bash -c \"\$3\""

    # The command the container runs: records each argument in brackets
    stub server "for a in \"\$@\"; do echo \"arg [\$a]\" >> \"$CALLS\"; done"
}

stub() {
    printf '#!/bin/bash\n%s\n' "$2" > "$STUBS/$1"
    chmod +x "$STUBS/$1"
}

# Runs the entrypoint with only the given variables and the stand-ins first on the path
run_entrypoint() {
    run env -i PATH="$STUBS:/usr/bin:/bin" "$@"
}

@test "without a command it stops with an error" {
    run_entrypoint bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"No command specified"* ]]
}

@test "without UID and GID it runs the command as it is" {
    run_entrypoint bash "$SCRIPT" server --webservice-interface=any "two words"

    [ "$status" -eq 0 ]
    run cat "$CALLS"
    [ "$output" = "arg [--webservice-interface=any]
arg [two words]" ]
}

@test "with a new UID and GID it creates the group and user and runs the command as that user" {
    run_entrypoint UID=1500 GID=1600 bash "$SCRIPT" server --port=8200

    [ "$status" -eq 0 ]
    run cat "$CALLS"
    [ "$output" = "getent group 1600
groupadd -g 1600 duplicati
id -u 1500
useradd -u 1500 -g 1600 -m -s /bin/bash duplicati
chown -R 1500:1600 /opt/duplicati /data
su duplicati -c
arg [--port=8200]" ]
}

@test "an existing group and user are used as they are" {
    run_entrypoint UID=1500 GID=1600 STUB_GROUP_EXISTS=yes STUB_USER_EXISTS=yes bash "$SCRIPT" server

    [ "$status" -eq 0 ]
    run cat "$CALLS"
    [[ "$output" != *groupadd* ]]
    [[ "$output" != *useradd* ]]
    [[ "$output" == *"chown -R 1500:1600 /opt/duplicati /data"* ]]
    [[ "$output" == *"su duplicati -c"* ]]
}

@test "arguments keep spaces, quotes and dollar signs when the command runs as the user" {
    run_entrypoint UID=1500 GID=1600 bash "$SCRIPT" server "a b" "it's" '$HOME' 'x"y'

    [ "$status" -eq 0 ]
    run grep '^arg ' "$CALLS"
    [ "$output" = 'arg [a b]
arg [it'"'"'s]
arg [$HOME]
arg [x"y]' ]
}

@test "a failed chown does not stop the container" {
    run_entrypoint UID=1500 GID=1600 STUB_CHOWN_EXIT=1 bash "$SCRIPT" server ok

    [ "$status" -eq 0 ]
    run grep '^arg ' "$CALLS"
    [ "$output" = "arg [ok]" ]
}

@test "a failed useradd stops the container" {
    run_entrypoint UID=1500 GID=1600 STUB_USERADD_EXIT=9 bash "$SCRIPT" server

    [ "$status" -eq 9 ]
    run grep '^arg ' "$CALLS"
    [ -z "$output" ]
}
