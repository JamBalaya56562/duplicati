#!/bin/bash
# Runs on Linux (WSL): builds the fix commit, runs the new test and the API probes with the fixed
# handler and with the master handler, for a Windows backup (cross-OS) and a Linux backup (same OS).
set -u
W=/mnt/c/Users/Jam/AppData/Local/Temp/claude/eb7164b3a8a8609a/2ade3d67-588b-4a0d-82ef-8acf31aad402/scratchpad/r449
R=$HOME/r449
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_ROOT="$HOME/.dotnet"
LOG=$W/wsl-run.log
: > $LOG
say() { echo "$*" | tee -a $LOG; }

rm -rf $R
mkdir -p $R/src || exit 1
tar -xf $W/src.tar -C $R/src || { say "extract failed"; exit 1; }
cp $W/probe.py $W/pw.txt $R/
cp -r $W/windows-remote $W/linux-remote $R/
cd $R/src || exit 1

build() {
  say "== build $1"
  dotnet build Executables/Duplicati.Server/Duplicati.Server.csproj -v q -nologo 2>&1 | tr -d '\000' | grep -a -E ': error ' | sort -u | head -5 | tee -a $LOG
  dotnet build Duplicati/UnitTest/Duplicati.UnitTest.csproj -v q -nologo 2>&1 | tr -d '\000' | grep -a -E ': error ' | sort -u | head -5 | tee -a $LOG
}

unit() {
  say "== unit test $1"
  dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "$2" 2>&1 \
    | tr -d '\000' | grep -a -E '^\s+(失敗|Failed) |Expected|But was|should list|成功!|失敗!|Passed!|Failed!' | head -20 | tee -a $LOG
}

probe() {
  local label=$1 remote=$2 list=$3 copy=$4 docs=$5 restore=$6
  rm -rf $R/data-$label $R/out-$label
  mkdir -p $R/data-$label
  [ -n "$restore" ] && mkdir -p $R/out-$label
  say "== probe $label"
  python3 $R/probe.py $R/src/Executables/Duplicati.Server/bin/Debug/net10.0/Duplicati.Server.dll $R/data-$label $R/$remote "$restore" $label $list $copy "$docs" 2>&1 | tee -a $LOG
}

WD='C:\Users\Jam\Documents\ngclient\tmp\restore449\fixture-final\windows-source\Documents\*'
LD='/fixture/linux-source/Documents/*'

# The master handler first
cp $W/ListFolderHandler.master.cs Duplicati/Library/Main/Operation/ListFolderHandler.cs
cp $W/LocalDatabase.master.cs Duplicati/Library/Main/Database/Local/LocalDatabase.cs
build master
unit master "FullyQualifiedName~DirectListHandlerTests|FullyQualifiedName~SplitIntoPrefixAndNameTests"
probe w2l-before windows-remote true 0 "" ""
probe l2l-before linux-remote true 0 "" ""

# Then the fix
cp $W/ListFolderHandler.fix.cs Duplicati/Library/Main/Operation/ListFolderHandler.cs
cp $W/LocalDatabase.fix.cs Duplicati/Library/Main/Database/Local/LocalDatabase.cs
build fix
unit fix "FullyQualifiedName~SplitIntoPrefixAndNameTests|FullyQualifiedName~DirectListHandlerTests|FullyQualifiedName~ListPrefixMultipleRootsTests|FullyQualifiedName~RestoreLargestPrefixTests|FullyQualifiedName~Recreate"
probe w2l-after windows-remote true 0 "" ""
probe l2l-after linux-remote true 0 "" ""
probe w2l-same-job windows-remote true 0 "$WD" $R/out-w2l-same-job
probe w2l-copy windows-remote true 1 "$WD" $R/out-w2l-copy
probe w2l-nolist windows-remote false 0 "$WD" $R/out-w2l-nolist
probe l2l-same-job linux-remote true 0 "$LD" $R/out-l2l-same-job
probe l2l-copy linux-remote true 1 "$LD" $R/out-l2l-copy
cp $R/server-*.log $W/ 2>/dev/null
say "== done"
