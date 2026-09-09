# 実装済みの enhancement を閉じる依頼の下書き（2026-11-13、202、3 本とも 11-13 に投稿済み）

**11-13 の確認（225）**: 閉じられた #3292・#4098、open のまま #1270（`CLOSED-ISSUES-2026-11-13.md`）

確かめたこと（master `6cae627a` の Debug の CLI、Windows）:
- #1270: 2.4.1.0 stable のリリースの添付（`gh release view`）に MSI（win x64・x86・arm64）、deb・rpm・AppImage・spk（linux）、pkg・dmg（osx）、agent の各パッケージ。サービスの定義は `ReleaseBuilder/Resources/{debian,fedora}/systemd/*.service`、macOS の launchagent の plist、`Executables/Duplicati.WindowsService`。Issue の「#1739 を先に」は #1739 がまだ開いているが、インストーラーの話ではない（UI を出すユーザーの選択）。
- #3292: バックアップの Verbose のログに `Setting custom SQLite option 'journal_mode=WAL'`・`'mmap_size=67108864'`（ほか synchronous=NORMAL・temp_store=MEMORY・cache_size=-65536）。実行後のジョブの DB は `PRAGMA journal_mode` が `wal`。stable は中身で確認して 2.3.0.0 から（2.2.0.1 には無い）。
- #4098: 共有なしで開いたファイルがあるバックアップで `[Warning-...-FileLocked]: Excluding path due to file locked: ...`、終了コード 2。`--suppress-warnings=FileLocked` を付けると警告なしで終了コード 1（変更なし）。`suppress-warnings` は 2.2.0.0 stable にある。
- **#3491 は外した**: 10-31 の表では IMPLEMENTED だったが誤り。`create-report` の DB では `LogData` の本文に `/` か `:\` を含む行が丸ごと `ERASED!` になる（`LocalBugReportDatabase.cs:126-142`）。今回の報告でも 2 行とも `ERASED!`（実行で確認）。

---

## #1270 (Start-as-daemon/service and Create installers)

The installers are ready and come with every release. 2.4.1.0 stable has MSI packages for Windows (x64, x86 and arm64), deb, rpm and AppImage packages and Synology packages (`.spk`) for Linux, and pkg and dmg packages for macOS.

The agent packages run Duplicati as a service: a systemd unit in the deb and rpm packages, a launch agent on macOS, and a Windows service.

I think this can be closed.

## #3292 (SQLite WAL & Memory mapped files - performance)

Both are used now. Every database connection sets `journal_mode=WAL` and `mmap_size` to 64 MB, together with `synchronous=NORMAL`, `temp_store=MEMORY` and a 64 MB cache. The `CUSTOMSQLITEOPTIONS_DUPLICATI` environment variable can change them. This is in 2.3.0.0 and later.

I checked it with the current master: the verbose log of a backup shows `Setting custom SQLite option 'journal_mode=WAL'` and `'mmap_size=67108864'`, and the job database is in WAL mode afterwards.

Replacing SQLite would be a separate request, so I think this one can be closed.

## #4098 (Feature Request: Locked files exclusion)

Locked files are already left out: a file that cannot be read because it is locked is skipped with the warning `FileLocked`. To skip them without the warning, `--suppress-warnings=FileLocked` (2.2.0.0 and later) logs it as information instead. It can be set in the advanced options of the job.

I checked it with the current master on Windows. With a file that another program had open without sharing, the backup logged `Excluding path due to file locked` and finished with a warning. With `--suppress-warnings=FileLocked` it finished without a warning.

There is no checkbox for it, as the issue asked. If the option covers it, I think this can be closed.
