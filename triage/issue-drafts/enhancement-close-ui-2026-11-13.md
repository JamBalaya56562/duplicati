# 新しい Web UI で確かめた、実装済みの enhancement を閉じる依頼の下書き（2026-11-13、207、11 本とも 11-13 に投稿済み）

**11-13 の確認（225）**: 閉じられた #2185・#2811・#1174・#4681・#2590、open のまま #4830・#2018・#2211・#4996・#1308・#3376（`CLOSED-ISSUES-2026-11-13.md`）

確かめたこと（master `6cae627a` のサーバー＋同梱の ngclient 0.0.248＝npm の最新、使い捨てのデータフォルダー、localhost、内蔵ブラウザー）:
- 2.4.1.0 stable は ngclient 0.0.244 を同梱（タグの package-lock）、Cookie が無ければ ngclient が既定（タグの index.html）。下の UI の機能のコミット（status ページ 585ce578、import-destination 278e754c、ログの要約と文字での編集 6292e777、Add remote path b6e56029、broken-files f2c20d49）はどれも 0.0.244 の祖先。サーバー側（restore-options、BackendSourceProvider、broken/purge の API、restore-task-config）も 2.4.1.0 stable の中身にある。
- #4830: ジョブのログの各行が `Backup (took 0s, uploaded 5.3 KB, backup size 13.05 KB)`。
- #2018: ログ・エクスポート・データベース・コマンドラインに「Back」、削除・版の削除・版のラベル・壊れたファイルに「キャンセル」、復元・purge に「Exit」。ブラウザーの戻るでジョブのページに戻る（ホームではない）。
- #2185・#2211: ジョブの復元と、ファイルからの直接の復元の両方のオプションの画面に「Add advanced option」（検索できる一覧、説明付き、選んだ `skip-restore-verification` はトグルで入る）と ⋮ の「Edit contents as text」「New custom option」「Toggle option names」。
- #2811: 同じ一覧が検索・グループ分け・型付きの入力。Issue は具体的な仕様のない forum の議論なので「閉じてよいか」と聞く形。
- #1174: 実行中の状態バーに `Slow big backup - Waiting for transfers at 337.92 KB/s`、処理中のファイルと `File processed: 491.52 KB/4.2 MB - 11.7%`。状態ページに CURRENT ACTION。
- #4681: 状態ページに THROUGHPUT と ETA（41 ファイル・125.83 MB のバックアップで `6:52`＝終わる見込みの時刻）。ファイルが 1 つだけのときは処理済みが 0 のままで「–」。
- #4996: dblock を 1 つ外すと壊れたファイルのページに版 0 の `note1.txt`・`added.txt`、「Purge broken files」→確認→実行で `RemovedFileCount 2`・`RewrittenFileLists 1`、その後ページは「破損したファイルは見つかりませんでした」。
- #1308: 2 回目で変えていない `photos` の 3 ファイルが、ジョブの復元でも直接の復元（Issue の「Restore from target」）でも最新の版に出る。
- #2590: バックアップ元の「Add remote path」に Google Drive・Dropbox・Amazon S3・Box・OneDrive・SFTP など「as a remote source」。CLI で `@C:\duplicati-virtual-2590\docs|file://...` のソースから 4 ファイルをバックアップ。
- #3376: `encryption-module=aes` のジョブ（UI で作るジョブと同じ）を 1 回実行すると dlist に `task-setup.json`、「backup/import-destination」で URL とパスフレーズを入れると「Photos with stored config」が出て、取り込むと名前・aes・バックアップ先の入った下書きになる（パスワードは空、既定では秘密を除くため）。
- **外したもの**: #4497（SFTP のサーバーが要る、未確認）。
- **見つけたこと（別件、未修正）**: (1) API でパスフレーズだけ設定した（`encryption-module` を明示しない）ジョブは暗号化されるが、Auto の判定（`Runner.cs:278` の `IsBackupEncryptionEnabled`）が暗号化なしとみなし、設定が保存されない。(2) 復元のファイルの木でフォルダーを 2 つ素早く開くと「バックアップデータベースは別の処理で使用中」のエラー。

---

## #4830 ([feature request] Add top-level stats to the log entry titles)

This is in the new web UI, which is the default in 2.4.1.0. Each entry on the log page of a job now has the summary in its title, for example:

```
2026/11/13 6:41:43  Backup (took 0s, uploaded 5.3 KB, backup size 13.05 KB)
```

I checked it with the current master and the web UI it ships. I think this can be closed.

## #2018 (Missing "back" button on some pages)

The new web UI, which is the default in 2.4.1.0, has a way back on these pages. The log, export, database and command line pages have a "Back" button. Delete, delete versions, version labels and broken files have "Cancel", and restore has "Exit". The browser's back button also returns to the job page now, not to the home page.

I checked each of these pages with the current master. I think this can be closed.

## #2185 (Advanced options cannot be set when restoring files)

The new web UI, which is the default in 2.4.1.0, has an "Add advanced option" button in the last step of a restore. It opens a searchable list of the options with their descriptions.

I checked it with the current master, both when restoring from a job and when restoring directly from backup files. I think this can be closed.

## #2211 (When restoring files, Advanced options cannot be selected from list)

In the new web UI, which is the default in 2.4.1.0, the advanced options of a restore are a list: "Add advanced option" picks an option from a searchable list. The menu next to it switches to "Edit contents as text" and back.

I checked both the restore from a job and the direct restore from backup files with the current master. I think this can be closed.

## #2811 (Improved advanced options editor)

The new web UI, which is the default in 2.4.1.0, has a new editor for the advanced options. "Add advanced option" opens a searchable list, grouped, with the description of each option. An option is added with an input for its type, such as a switch for a boolean. The menu next to it can edit the options as text, add a custom option, or show the option names.

The issue links to a forum discussion without a concrete list of changes, so I am not sure what is left. Does this cover it, so it can be closed?

## #1174 (Display current task in status)

The new web UI, which is the default in 2.4.1.0, shows what a running backup is doing. The status bar shows the phase, for example "Waiting for transfers" or "Completing upload", with the speed, the file being processed and how far it is. The status page also has a "Current action" field.

I checked it with the current master during a slow backup. I think this can be closed.

## #4681 (Feature Request: Option for In-Progress Backup Display)

The status page of the new web UI, which is the default in 2.4.1.0, shows an ETA for a running backup, next to the throughput. I checked it with the current master: during a backup of 41 files (126 MB), the ETA showed the time it expected to finish.

The ETA is based on the files and bytes that are done, so with a single large file it stays empty until that file is done. I think this can be closed.

## #4996 (UI guided / wizard support for "list-broken-files" and "purge-broken-files")

The new web UI, which is the default in 2.4.1.0, has a "Purge broken files" page for a job. It lists the broken files of each version, and purges them after a confirmation.

I checked it with the current master. After removing a block volume from the destination, the page listed the two affected files. Purging them removed them from the backup, and the page then found no broken files. I think this can be closed.

## #1308 (Allow to restore all files for a certain timestamp (from the GUI))

When a version is picked for a restore, the file list shows all the files in that version, also the ones that did not change since the previous backup. This is so both when restoring from a job and when restoring directly from the backup files.

I checked it with the current master: after a second backup that changed only some files, the latest version listed the unchanged files too. I think this can be closed.

## #2590 ([Feature Request] Cloud providers as source data)

This is possible now: a remote location can be a backup source. In the new web UI, which is the default in 2.4.1.0, "Add remote path" on the source page lists the storage types that can be a source, such as Google Drive, Dropbox, Amazon S3, Box, OneDrive and SFTP.

I checked it with the current master, with a folder on another location given as a remote source: the backup added its files under the mount point chosen for it. I think this can be closed.

## #3376 (Using existing backups)

Since 2.4.0.0, the configuration of a job is stored in an encrypted backup by default (`--store-task-config`, without the passwords), and the new web UI can import it from the destination.

I checked it with the current master: after one run of an encrypted job, "Import from destination" with the URL and the passphrase found the job, and importing it opened the job with its name, encryption and destination filled in. The passwords have to be entered again.

I think this covers the request. Should it be closed?
