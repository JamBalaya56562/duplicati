# 閉じてよさそうな Issue へのコメント（2026-10-04、利用者の承認を得て同日投稿）

11 件とも投稿し、投稿された本文が案と一致することを確認した（末尾の改行を除いて比較）。

`IMPLEMENTATION-CANDIDATES-2026-10-04.md` の「閉じてよさそうなもの」を 1 件ずつ確かめ直した。**できるものは今の master（`9a3d38ca`、2.4.0.103 canary 相当）の CLI・サーバーで実際に動かした**（手順と結果は各項の「確認」）。どのリリースに入っているかは `git tag --contains` に加え、**タグのコードを読んで**確かめた（2.4.0.0 stable は別ブランチから cherry-pick されていて、`--contains` に出ない修正も入っているため。例: #4103）。

外したもの: #4599（修正 `11a250d9` は 2.3.0.109 canary〜で、**2.4.0.0 stable のコードにはない**。後半の「メタデータに remote の取得が要る」も未対応）、#2798（`fix/restore-missing-folder-not-a-warning` の PR で `Fixes #2798`）。

サブエージェントの見立てと違った点: `71eb0313`・`842fd965` が「2.0.x の beta から」というのは `--contains` では確かめられない（2.1.0.2 beta が最初に出る）ので、コメントでは使わない。

## #5007 Database recreate does not catch missing encryption configuration（[投稿](https://github.com/duplicati/duplicati/issues/5007#issuecomment-5974792575)）

確認（検証済み）: 暗号化したバックアップを作り、`repair --no-encryption=true --dbpath=<新しい DB>` → ファイルを処理する前に `The remote files are encrypted, but no passphrase was provided`（`ErrorID: MissingPassphrase`）で止まる。パスフレーズなしでも `EmptyPassphrase` で止まる。修正 [`73a2f32b`](https://github.com/duplicati/duplicati/commit/73a2f32b05a77afa56691aaf85a21c0b2ad56369) は 2.1.2.0 beta・2.2.0.0 stable のタグのコードにある。

> Checked on the current code: after an encrypted backup, a repair with `--no-encryption=true` and a new local database now stops before processing any file, with "The remote files are encrypted, but no passphrase was provided" (`MissingPassphrase`). The check was added in [73a2f32b](https://github.com/duplicati/duplicati/commit/73a2f32b05a77afa56691aaf85a21c0b2ad56369) (2.1.2.0 beta, 2.2.0.0 stable). I think this can be closed.

## #4220 send-http-level with multiple enum values invalid（[投稿](https://github.com/duplicati/duplicati/issues/4220#issuecomment-5974793294)）

確認（検証済み）: `--send-http-url=http://127.0.0.1:<port>/ --send-http-level=Success,Warning` でバックアップ → オプションの警告なし、成功のレポートが届く。`--send-http-level=Warning,Error` では成功のレポートは届かない（絞り込みが効く）。修正 [`2a79e3e4`](https://github.com/duplicati/duplicati/commit/2a79e3e4c393907ccfb6887672813e608d97b83d)（level を String 型に）は 2.1.0.2 beta・2.1.0.4 stable〜。

> The report level options are plain string options since [2a79e3e4](https://github.com/duplicati/duplicati/commit/2a79e3e4c393907ccfb6887672813e608d97b83d) (2.1.0.2 beta, 2.1.0.4 stable), so a list of levels is no longer checked against the single values. On the current code, a backup with `--send-http-level=Success,Warning` gives no warning about the option and sends the report for a successful backup, and with `Warning,Error` it does not send one. I think this can be closed.

## #4792 HTTP Report URL not working if there are lots of warnings in the backup（[投稿](https://github.com/duplicati/duplicati/issues/4792#issuecomment-5974794035)）

確認（検証済み）: 400 ファイルのバックアップを `--send-http-log-level=Verbose --send-http-max-log-lines=1000` でローカルの listener に送る → 本文 約 176,000 文字・1,062 行（URL エンコード後 222,651 バイト）が届き、デコードして中身を確認。2.0.6.3 は `Uri.EscapeDataString(body)` を 1 回で呼んでいた（タグで確認）。[`aabfbb8d`](https://github.com/duplicati/duplicati/commit/aabfbb8df656cfaf7533c1f50a2049d49f258091)（2048 文字ずつ）は 2.1.2.0 beta・2.2.0.0 stable〜、#2843 は 2025-03-25 に COMPLETED で閉じている。なお .NET 10 の `EscapeDataString` は 40,000 文字でも例外にならない（実測）。

> As ts678 said, this is the same as #2843, which was closed after [aabfbb8d](https://github.com/duplicati/duplicati/commit/aabfbb8df656cfaf7533c1f50a2049d49f258091) (2.1.2.0 beta, 2.2.0.0 stable) changed the report to be escaped in pieces of 2048 characters, so the length limit of `Uri.EscapeDataString` no longer applies. On the current code, a report of about 176,000 characters (1,062 log lines) was posted to a local listener in full. I think this can be closed as a duplicate of #2843.

## #2949 HTTP frontend fails if "upgrade" connection header is specified（[投稿](https://github.com/duplicati/duplicati/issues/2949#issuecomment-5974794392)）

確認（検証済み）: 今のサーバーに `curl -H "Connection: upgrade"`、`-H "Connection: upgrade" -H "Upgrade:"`（nginx の `$http_upgrade` が空のとき）→ どちらも `200 OK`。古い HttpServer.dll は [`9f790257`](https://github.com/duplicati/duplicati/commit/9f7902574473639689fa7cea899b70f97b6b613e) で削除（2.1.0.2 beta・2.1.0.4 stable〜）。本物の nginx では試していない。

> The web server that rejected this header was replaced with ASP.NET Core (Kestrel) in [9f790257](https://github.com/duplicati/duplicati/commit/9f7902574473639689fa7cea899b70f97b6b613e) (2.1.0.2 beta, 2.1.0.4 stable). On the current version, a request with `Connection: upgrade`, also with an empty `Upgrade:` header as nginx sends it when the client did not ask for an upgrade, gets the normal `200 OK` page. I think this can be closed.

## #2650 CLI : purge-broken-files ignores the configured database path.（[投稿](https://github.com/duplicati/duplicati/issues/2650#issuecomment-5974794669)）

確認（検証済み）: `--dbpath` なしの CLI は、設定フォルダの `dbconfig.json` に宛先 URL をキーとした新しい項目を作り、その DB を使う（サーバーの DB は見ない）。ドキュメントの [Command Line Interface](https://docs.duplicati.com/duplicati-programs/command-line-interface-cli)（"Each command also requires the option `--dbpath`... a shared JSON file in the settings folder"）と各 OS のガイド（`dbconfig.json`）に記載がある（ページを取得して確認）。新しい UI の Commandline 画面はジョブの `--dbpath` を付ける（ngclient `commandline.component.ts:119,154`）。

> As kenkendk and ts678 explained, the command line keeps its own map from the destination URL to a local database in `dbconfig.json` and does not read the server's job settings, so after the database path is changed in the UI, the command line needs `--dbpath`. This is now described in the documentation, in [Command Line Interface](https://docs.duplicati.com/duplicati-programs/command-line-interface-cli) and in the platform guides such as [Using Duplicati with Linux](https://docs.duplicati.com/detailed-descriptions/platform-specific-guides/using-duplicati-with-linux). The Commandline page in the UI passes the job's `--dbpath`. I think this can be closed.

## #4846 Revoked AuthID keeps working（[投稿](https://github.com/duplicati/duplicati/issues/4846#issuecomment-5974794873)）

確認（コード、検証済み）: duplicati/oauth-handler の最新 `a0fb3023` の `main.py`。`/refresh` は AuthID ごとに memcache の access token を、期限の 30 秒前まで返す（L610-L622、保存は L706）。`/revoked` は datastore の項目を消すだけで memcache は消さない（L887）。Duplicati 側は実行ごとに `/refresh` を呼ぶ（`OAuthHelperHttpClient` のキャッシュはインスタンス単位）。実際に revoke して試してはいない。

> This happens in the OAuth server ([duplicati/oauth-handler](https://github.com/duplicati/oauth-handler)), not in this repository. `/refresh` keeps the access token for an AuthID in memcache and keeps serving it until 30 seconds before it expires ([main.py#L610-L622](https://github.com/duplicati/oauth-handler/blob/a0fb302312c1ca2e3696183b1b6c7c541497b899/main.py#L610-L622)), and the revoke deletes the stored token but not that cache entry ([main.py#L887](https://github.com/duplicati/oauth-handler/blob/a0fb302312c1ca2e3696183b1b6c7c541497b899/main.py#L887)). So backups can still get an access token until the cached one expires, after which the refresh fails, close to what @gpatel-fr described. Clearing the cache entry on revoke would be a change in oauth-handler, so I think this can be closed here.

## #4468 Restore impossible permissions in Rootless Docker don't result in warning or error（[投稿](https://github.com/duplicati/duplicati/issues/4468#issuecomment-5974795149)）

確認: user namespace で対応づけられていない ID が 65534（overflowuid/overflowgid）に見えることを WSL の `unshare --user --map-root-user` で実測（検証済み）。165536 + 65534 − 1 = 231069（計算）。Duplicati はバックアップ時に stat の uid/gid と名前（`nogroup`）を記録し、復元時は名前を引き直して書き戻す（`SystemIOLinux.cs:248-249,297-316`、コード根拠）。rootless Docker そのものでは試していない。

> Inside a rootless container, a file whose owner or group is not mapped into the container's user namespace shows up as 65534 (the kernel's overflowuid/overflowgid, usually `nobody`/`nogroup`), and that is what Duplicati sees and records during the backup. The GID 231069 after the restore is that same 65534 mapped back to the host: 165536 + 65534 − 1. So the restore wrote back the owner it recorded; at that point it cannot tell an unmapped owner from a real 65534. I think this can be closed; a warning at backup time for files owned by 65534 would be a feature request.

## #4103 Misleading summary of last successful backup and size after force stop/cancel（[投稿](https://github.com/duplicati/duplicati/issues/4103#issuecomment-5974795677)）

確認（検証済み）: 今のサーバーの API で、1 MB のジョブを完了 → 30 MB を足して throttle 512 KB/s で実行し 8 秒で stop → `LastBackupFinished`・`LastBackupStarted`・`SourceFilesSize`・`SourceFilesCount`・`BackupListCount`・`TargetFilesSize` は 1 回目の値のまま、ジョブのログは `Interrupted: true`。[`e8925f78`](https://github.com/duplicati/duplicati/commit/e8925f78a50a950161738babeb3a9aa2a36be97a) は `--contains` では 2.3.0.109 canary〜だが、**2.4.0.0 stable のタグのコードに同じ 2 か所**（`Controller.cs:616` の `Interrupted = StopToken...`、`Runner.cs:1249` の `if (!result.Interrupted)`）と同じテストがある。

> Since [e8925f78](https://github.com/duplicati/duplicati/commit/e8925f78a50a950161738babeb3a9aa2a36be97a), a backup that is stopped is marked as interrupted, and the server does not update the last run time, the source size and the other figures of the job from an interrupted run. This is in 2.4.0.0 stable. Checked on the current version: after a backup that completed and a second one that was stopped partway, the job still shows the time and the size of the completed run, and the log of the stopped run says it was interrupted. I think this can be closed.

## #3530 Report shows a lot of debug info and questionable info ("Could not find file")（[投稿](https://github.com/duplicati/duplicati/issues/3530#issuecomment-5974796059)）

確認（検証済み）: 読めないフォルダ（ACL で一覧を拒否）を含むバックアップ → ログファイル・コンソールとも `[Warning-...FileEnumerationProcess-PermissionDenied]: Excluding path due to permission denied: <path>` の 1 行で、スタックトレースなし。報告の例（消えたファイル、`FileNotFoundException`）は `Excluding path due to path not found` になる（`LogExceptionHelper.cs:53-54`、コード根拠）。[`1d4642ac`](https://github.com/duplicati/duplicati/commit/1d4642acdf70290c552381782bdfaeb32f20a446)（#6426）は 2.3.1.0 beta・2.4.0.0 stable〜。`--suppress-warnings`（警告 ID を Information にする）は今の Options にある。**別件: 同じフォルダに同じ警告が 2 回出た**（候補に記録）。

> Since [1d4642ac](https://github.com/duplicati/duplicati/commit/1d4642acdf70290c552381782bdfaeb32f20a446) (#6426, in 2.3.1.0 beta and 2.4.0.0 stable), a path that is gone, cannot be read or is locked is reported in one line, such as "Excluding path due to path not found: ..." or "Excluding path due to permission denied: ...", without the exception and stack trace. Checked on the current version with a folder the user cannot read. Warnings that are expected can also be turned into information messages with `--suppress-warnings` and their IDs (`PathNotFound`, `PermissionDenied`, ...). I think this can be closed.

## #3038 Log-file defined with "--log-file" is not logging errors（[投稿](https://github.com/duplicati/duplicati/issues/3038#issuecomment-5974796272)）

確認（検証済み）: ソースの 1 つがないバックアップ、`--log-file`・`--log-file-log-level=Information`。既定では警告 `SourceIsMissing` がログファイルに出る。`--abort-if-source-missing=true` では `[Error-...-FailedOperation]` と "Backup aborted since the source path ... does not exist" がログファイルに出る。CLI と、UI のジョブ（サーバーの API で作成・実行、オプションに `--log-file`）の両方で確認。

> Checked on the current version: with a missing source and `--log-file`, the missing source is written to the log file as a warning by default, and with `--abort-if-source-missing=true` the failed backup is written to the log file as an error ("Backup aborted since the source path ... does not exist"), both from the command line and from a job in the UI. @Aetherinox, if `--log-file` still writes nothing for you on a current version, please open a new issue with the version, the OS and the command or job options. I think this one can be closed.

## #2004 Can't restore files/folders with special characters in name（[投稿](https://github.com/duplicati/duplicati/issues/2004#issuecomment-5974796787)）

確認（検証済み）: **Linux（WSL）と Windows の両方**で、今のサーバーに `Notes 📝/file1.txt`・`file2.txt` と、Linux では報告と同じ名前 `sftp:host=http,user=root/file3.txt`（Windows は `:` が使えないので `sftp=host,user=root`）をバックアップし、
- 新しい UI の一覧（`POST /api/v2/backup/list-folder`）と古い UI の一覧（`GET /api/v1/backup/{id}/files?filter=@<path>&folder-contents=true`）→ どちらもフォルダとファイルが出る（エラーなし）
- 復元を UI が送る形で: 新しい UI（ファイル＝パス、フォルダ＝`<path>*`）、古い UI（ファイル＝`@<path>`、フォルダ＝`[<正規表現>.*]`）→ 4 通りとも全ファイルが中身ごと戻る
報告のエラー "Filter for list-folder-contents must be a path prefix with no wildcards" は今の UI の一覧の経路では出ない。

> Checked on the current version, on Linux with a folder named `sftp:host=http,user=root` as in the report and on Windows, both with a folder named `Notes 📝`: the folders and files are listed without errors in the new and the old UI, and restoring them, both selected as files and as whole folders, in the forms both UIs send, brings back all the files with their contents. The error in the report did not come up. I think this can be closed; if a name still fails for someone on a current version, a new issue with the name would help.
