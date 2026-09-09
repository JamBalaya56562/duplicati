# 返事のない Issue への返信の下書き（2026-11-13、224、4 本、未投稿）

返事 0 件の開いた Issue を新しい順に見た（`gh issue list`、11-13）。

- **返信しない**:
  - #7804: 利用者の管理者での再現待ち。
  - #7740・#7665: リリース待ち。
  - #7672: DSM がなく確かめられない。
  - メンテナー自身の作業メモ（#6597・#6391・#6325・#6305・#6228・#6058）。#6325 は、複数のドライブを別のフォルダーへ復元すると `C\…`・`Q\…` に分かれることを subst で確かめた。ただし、この動きは 2013 年の 0caa03d27 からあり、Issue（2025-06）の言う問題が別にあるはずなので返信しない。
- **確かめたこと**: CLI は master `6cae627a`（dup-buildws の Debug、Windows）。架空のパスフレーズだけを使った。

## #7264 ([Feature Request] Add a per-run upload data limit (--max-upload-per-run))

根拠:
- PR #7800 の本文と head `4043d3b97bb567f02ed80f6dbae04b2d303ff9b8`。
- `MaxUploadPerRunTests` が 7/7 緑（WSL、11-13 に再実行）。
- PR の本文に `Fixes #7264` がある。

---

I have opened #7800, which adds `--max-upload-per-run` as described here. When the uploads of a backup reach the given size, the backup stops after the current file. The run is saved as a partial backup, and the next run backs up the files it did not reach. The volumes that are already being made or uploaded, and the file list, are still uploaded, so a run can go somewhat over the limit.

It is not merged yet, so it is not in a release.

## #7270 (Creation of boot media for bare metal restores?)

根拠:
- ドキュメント「Full-disk backup and restore」。
- 「Add local disk」は ngclient 47933415（2026-02-20）からある。2.4.1.0 が同梱する 0.0.244（4c2cb9a0）に含まれる。
- `proprietary/DiskImage` は 2.4.1.0 のタグにある。
- 実際のディスクでは試していない（管理者権限が要る）。**未検証**であることはコメントにも書く。

---

Duplicati cannot make boot media. It can make a full-disk backup: on the "Source Data" page, "Add local disk" backs up a whole disk, including the partition table. Restoring it to a blank disk that is at least as large gives a bootable disk. See [Full-disk backup and restore](https://docs.duplicati.com/automation-and-integration/full-disk-backup-and-restore).

You cannot restore over the disk the running system is on. For the C: drive, the documentation says to start the machine from recovery media, or to attach the new disk to another machine. Reading and writing raw disks needs administrator rights.

I have not tried this myself. The full-disk backup is in the `proprietary/` folder, which has [its own license](https://github.com/duplicati/duplicati/blob/master/proprietary/LICENSE).

## #6578 (System improvements: Architectural Refactoring Proposal …)

根拠:
- **WAL**:
  - [322e4f15e4b39128821279a662fc1ee0d3d59170](https://github.com/duplicati/duplicati/commit/322e4f15e4b39128821279a662fc1ee0d3d59170) で `SQLiteLoader` の既定に入った。
  - タグの中身を見ると、2.1.2.0〜2.1.2.3 beta には無く、2.2.1.0 beta・2.3.0.0 stable・2.4.1.0 stable には有る。
  - 今の build で作った DB は `PRAGMA journal_mode` が `wal`（検証済み）。
- **サービス**:
  - ドキュメント「Run Duplicati as a Windows Service」（2.4.0.0 から）。
  - `Duplicati.wxs` の `--no-hosted-server` は 2.4.0.0・2.4.1.0 のタグにあり、2.3.0.4 には無い。
- **--auto-cleanup**:
  - 宛先に余分なファイルを置くと、オプションなしでは「Found 1 remote files that are not recorded」で失敗した。`--auto-cleanup=true` では「attempting automatic cleanup」のあと成功し、新しいファイルも版に入った（検証済み）。
  - 壊れたローカル DB を自動で直す処理はコードに無い（grep で確認）。

---

Two parts of this have been done since the issue was opened:

- WAL: from 2.2.1.0 beta and 2.3.0.0 stable, the local databases are opened with `journal_mode=WAL` and `synchronous=NORMAL` (https://github.com/duplicati/duplicati/commit/322e4f15e4b39128821279a662fc1ee0d3d59170). A database made by the current master reports `wal`.
- Service: from 2.4.0.0, the Windows installer can install Duplicati as a Windows service. The tray icon then connects to the service instead of running its own server. See [Run Duplicati as a Windows Service](https://docs.duplicati.com/platform-specific-guides/using-duplicati-with-windows/run-duplicati-as-a-windows-service).

For 1.2, the closest option is `--auto-cleanup=true`. When the check before a backup finds remote files that do not match the local database, the backup runs a repair by itself and goes on. I checked this with an extra file on the destination. It does not cover a damaged local database (`database disk image is malformed`), which still needs a manual repair or recreate.

## #6112 (Customize the file name extensions stored on the backup destination.)

根拠:
- 既定の AES では `.dlist.zip.aes`・`.dblock.zip.aes`・`.dindex.zip.aes` の 3 種類だけで、`.sqlite` は無かった（検証済み）。
- `--encryption-module=gpg`（Git for Windows の gpg 2.4.9、`--gpg-program-path` で指定）では `.zip.gpg` の 3 種類になり、復元して中身が一致した（検証済み）。
- `--no-encryption` では `.dlist.zip`・`.dblock.zip`・`.dindex.zip`（#6325 の確認のバックアップ、検証済み）。
- `--upload-verification-file`（既定 false）を使うと `-verification.json` も上がる（`FilelistProcessor.cs:253`、コード根拠）ので「By default」と書く。
- 拡張子を変えるオプションは `Options.cs` に無い（コード根拠）。
- 2.4.1.0 の圧縮モジュールは zip だけ（tgz・tzstd はコメントアウト）。

---

There is no option to set the extensions, but they follow the encryption module. Set it when you create the backup:

- With `--encryption-module=gpg`, the files end in `.zip.gpg` instead of `.zip.aes`. GPG must be installed; set `--gpg-program-path` if Duplicati does not find it.
- With `--no-encryption`, they end in `.zip`.

The local database (`.sqlite`) is not uploaded. By default, only `.dlist`, `.dblock` and `.dindex` files are.

I checked with the current master. A backup with `--encryption-module=gpg` made `.dlist.zip.gpg`, `.dblock.zip.gpg` and `.dindex.zip.gpg` files, and a restore from them worked.
