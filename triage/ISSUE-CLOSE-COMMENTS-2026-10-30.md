# 解決済みの Issue へのコメント（2026-10-30、1 回目の区切り）

- 対象: `IMPLEMENTATION-CANDIDATES-2026-10-10.md` の「閉じてよさそうなもの」の 19 件（どれもまだ自分のコメントなし、10-30 に open を確認）から、1 回目は Kestrel への移行で直っていそうな 4 件（#4627・#4833・#4711・#3611）を選んだ
- 基準にした master: [`31bf7aa0225f095de70020700224d3f229dcfe65`](https://github.com/duplicati/duplicati/commit/31bf7aa0225f095de70020700224d3f229dcfe65)
- **GitHub にはまだ何も投稿していない**（利用者の承認待ち）

## 確かめたこと（検証済み）

`../duplicati-buildcheck`（master `31bf7aa0`）で `Executables/Duplicati.Server` をビルドし、空のデータフォルダーで `dotnet Duplicati.Server.dll --webservice-port=8457 --webservice-interface=loopback` として起動した。`Cookie: big=<a の繰り返し>` を付けて curl で送った結果:

| Cookie の長さ | `/` | `/ngax/index.html` | `/api/v1/serverstate`（トークンなし） |
|---|---|---|---|
| 0 | 200 | 200 | 401 |
| 4600 | 200 | 200 | 401 |
| 8000 | 200 | 200 | 401 |
| 16000 | 200 | 200 | 401 |
| 30000 | 200 | 200 | 401 |

401 は Cookie なしと同じ（ログインしていないため）。`/api/v1/auth/login` で取ったトークンを付けると、8000 バイトの Cookie でも `/api/v1/serverstate` は 200。サーバーのログに error・exception はなし。40000 バイトは Git Bash の引数の上限で curl を起動できず、確かめていない。Duplicati は Kestrel のヘッダーの上限を変えていない（`Duplicati/WebserverCore` に `Limits.` の設定なし）。

## 下書き

### #4627 error 400 on large header requests（2021-10-20、最終更新 2024-02-05）
- 直したもの: [#5112](https://github.com/duplicati/duplicati/pull/5112)「Feature/kestrel avalonia upgrade」（マージ [`75efe35e3da6b4960fac2c8f7350b8900a41af8e`](https://github.com/duplicati/duplicati/commit/75efe35e3da6b4960fac2c8f7350b8900a41af8e)、2024-04-21）。上限は古い自前の HTTP サーバー（`duplicati/httpserver` の `HttpRequestParser`）にあった
- コメント案:
  > I checked this on current master (31bf7aa0225f095de70020700224d3f229dcfe65): the server now runs on Kestrel (#5112), which replaced the old HTTP server that had the small header limit. Requests with a `Cookie` header of 4,600, 8,000, 16,000 and 30,000 bytes all got `200` for `/` and `/ngax/index.html`, and an authenticated API call with an 8,000-byte cookie also got `200`.
  > Would it be OK to close this?

### #4833 Web UI is not shown after the installation (400 error)（2022-10-19、最終更新 2024-10-01）
- 報告者が原因を突き止めている: localhost の別のアプリの 4.5K の Cookie（#4627 と同じ上限）
- コメント案:
  > The 400 here came from a 4.5K cookie set by another app on localhost, the same header limit as #4627. On current master (31bf7aa0225f095de70020700224d3f229dcfe65) the server runs on Kestrel (#5112), and `/ngax/index.html` answers `200` with a `Cookie` header of up to 30,000 bytes.
  > Would it be OK to close this?

### #3611 Solution: The connection to the server is lost -> Request Queue is full（2019-01-17、最終更新 2025-09-03）
- **下書きのまま（投稿しない）**: 「request queue is full」は古い自前の HTTP サーバーのメッセージで、今のソースにない（`grep -ri 'queue is full'` を Duplicati と ngclient で 0 件）。ただし報告の状況（nginx の裏で長いポーリングがタイムアウトする）は手元で再現していない。2025-09 のコメントは「nginx proxy manager で websocket を有効にしたら直った」で、今の UI では原因が違う
- 投稿するなら（利用者の判断）:
  > The "request queue is full" response came from the old built-in HTTP server, which was replaced by Kestrel in #5112; that message no longer exists in the code. With the current UI, the reverse proxy needs WebSocket support, as noted in the last comment.
  > Is it OK to close this?

### #4711 は対象から外した（直っていない見込み）
- Issue の中身は「S3（Storj）でフォルダーのパスを `/hdd0` と `/` で始めると、一覧のファイル名の先頭が 1 文字欠けて Found remote files that are not recorded になる」
- 今の master でも一覧の名前は `Key.Substring(prefix.Length)`（`S3AwsClient.cs:511,526`・`S3MinioClient.cs:145`）。サーバーがキーの先頭の `/` を落として返すと今も 1 文字欠ける見込み（推測、Storj では未確認）。直す候補として残す。**2026-10-30 に直そうとして取り下げ**: 返ったキーの `/` なしを受け付ける修正（`1eb5ae47`）は擬似 S3 では赤→緑だったが、今の MinIO（Chainguard 版 RELEASE.2026-10-23）はプレフィックス `/hdd0/` の一覧に 0 件を返すので効かない。既定の AWS クライアントでは `//hdd0` へのアップロードが `SignatureDoesNotMatch`、MinIO クライアントでは「missing from the remote storage」（master・修正版とも、検証済み）。今の壊れ方はこの 2 つで、直すなら一覧とアップロードの両方の設計が要る

## 投稿の記録（2026-10-30、利用者がこのセッションで承認）
投稿の直前に、2 件ともコメントの数と最終更新日が変わっていないこと（#4627: 2 件・2024-02-05、#4833: 8 件・2024-10-01）を確かめた。本文は上の下書きと同じ。
- #4627 https://github.com/duplicati/duplicati/issues/4627#issuecomment-6506061707
- #4833 https://github.com/duplicati/duplicati/issues/4833#issuecomment-6506062588

次の区切りの候補（10-10 の「閉じてよさそう」の残り 15 件）: #3985・#5186・#2925・#1226・#5114・#5136・#4045・#3286・#3085・#2298・#2744・#3753・#5102・#6214・#3020。どれも見立てだけなので、直したもの（コミット・PR）と今の master での観測をそろえてから下書きにする

---

# 2 回目の区切り（2026-10-30）

- 基準の master は同じ `31bf7aa0`。CLI は `../duplicati-buildcheck` で `Executables/Duplicati.CommandLine` をビルドしたもの
- **GitHub にはまだ投稿していない**（利用者の承認待ち）。投稿の前に 2 件ともコメント数と最終更新日を確かめる（10-30 時点: #4045 は 2 件・2024-02-06、#2298 は 8 件・2025-05-21）

## #4045 Denied access to System Volume Information gives a Warning（2020-01-08）
- 直したもの: [#7258](https://github.com/duplicati/duplicati/pull/7258)「Exclude system volume information」（kenkendk、マージ [`152ae92ede1a037faf559b7aee5b98a49adb7843`](https://github.com/duplicati/duplicati/commit/152ae92ede1a037faf559b7aee5b98a49adb7843)、2026-09-02）。`FileEnumerationProcess.PreFilterSourceEntry` で Windows のボリュームのルートの System Volume Information を除外する
- 確かめたこと（検証済み、Windows 11、管理者でないユーザー）: このユーザーでは `Get-ChildItem -Force 'C:\System Volume Information'` が `UnauthorizedAccessException`（報告と同じ条件）。master の CLI で `backup ... C:\ --log-file-log-level=Verbose` を走らせると、ログに `[Verbose-...FileEnumerationProcess-ExcludingSystemVolumeInformationFolder]: Excluding System Volume Information folder: C:\System Volume Information\` が 1 行、System Volume Information についての Warning・Error は 0 件（Warning は別の `C:\Windows\WUModels\` の 2 件だけ）
- 注意: このとき渡した除外の正規表現が効かず、C:\ 全体を読み始めたので数分で止めた（宛先 690 MB）。宛先・DB・ログは削除済み。抜き出したログは scratchpad の `svi-log-excerpt.txt`
- コメント案:
  > On current master (31bf7aa0225f095de70020700224d3f229dcfe65), Windows 11, as a non-admin user that gets `UnauthorizedAccessException` when listing `C:\System Volume Information`: a backup of `C:\` logs `Excluding System Volume Information folder: C:\System Volume Information\` at the Verbose level and gives no warning for it. The folder has been excluded automatically since #7258.
  > Would it be OK to close this?

## #2298 "Create Bugreport" never ends, consuming 100% CPU-load（2017-02-01）
- 報告で止まっていたクエリ `UPDATE "File" SET "Path" = (SELECT "Obfuscated" FROM "PathMap-..." WHERE "Path" = "RealPath")` は [`a8a32ea115b8165a6ea2f06f492b2d789f49e331`](https://github.com/duplicati/duplicati/commit/a8a32ea115b8165a6ea2f06f492b2d789f49e331)（2018-04-23、#1283 のパスの格納の変更）でなくなった。いったん revert され [`cbc18970d5292122a5ced6517526567e8a4672d5`](https://github.com/duplicati/duplicati/commit/cbc18970d5292122a5ced6517526567e8a4672d5)（2018-06-14）で入れ直された（`git log -S`）。今は `LocalBugReportDatabase.ObfuscateAsync` が結合で `FixedFile` を作る
- 確かめたこと（検証済み、Windows、ビルドサーバーを止めて並行負荷なし）: 500 件ずつのフォルダーに小さなファイルを置いてバックアップし、master の CLI で `create-report` を 2 回ずつ:
  - 10,000 ファイル: 2,053 ms・1,920 ms（レポート 4.7 MB）
  - 40,000 ファイル: 4,959 ms・5,471 ms（レポート 19 MB）
  - 4 倍のファイルで約 2.6 倍。報告のような止まり方はしない。報告者の規模（1 TB）や Linux（当時は Mono）では試していない
- コメント案:
  > The query this got stuck in (`UPDATE "File" SET "Path" = (SELECT "Obfuscated" ...)`) was replaced in 2018 (a8a32ea115b8165a6ea2f06f492b2d789f49e331, re-applied in cbc18970d5292122a5ced6517526567e8a4672d5) by building the obfuscated file table with a join. On current master (31bf7aa0225f095de70020700224d3f229dcfe65), Windows, `create-report` finished in about 2 s for a backup of 10,000 files and about 5 s for 40,000 files (two runs each).
  > Would it be OK to close this?

## 投稿の記録 その2（2026-10-30、利用者がこのセッションで承認）
投稿の直前に、2 件ともコメントの数と最終更新日が変わっていないこと（#4045: 2 件・2024-02-06、#2298: 8 件・2025-05-21）を確かめた。本文は上の下書きと同じ。
- #4045 https://github.com/duplicati/duplicati/issues/4045#issuecomment-6506581258
- #2298 https://github.com/duplicati/duplicati/issues/2298#issuecomment-6506581860

1 回目の #4833 は投稿の直後（2026-10-29 19:16 UTC）に kenkendk が閉じた。#4627 は open のまま。全体の状態は `CLOSED-ISSUES-2026-10-30.md`

---

# 3 回目の区切り（2026-10-30）

- 基準の master は同じ `31bf7aa0`。Windows は `../duplicati-buildcheck` の CLI、Linux は WSL（Ubuntu-Preview、ext4、非 root）に `git archive 31bf7aa0` を展開してビルドした CLI
- **GitHub にはまだ投稿していない**（利用者の承認待ち）

## 共通の手順（#3286・#3085、検証済み、Windows）
10 個のファイルをバックアップしたあと、Python の sqlite3 で `f3.bin` の Blockset の Length を 2900 → 0 にして、もう一度バックアップした（ファイルは 1 つ変えた）。
- backup: exit 100。CLI に `Found inconsistency in the following files while validating database: ...\f3.bin, dbsize 0, actual size 2900, blocksetid: 14. Run repair to fix it. If repair cannot fix it, use list-broken-files and purge-broken-files to remove the affected files.`（`ErrorID: DatabaseInconsistency`）。出力に「One or more errors」は 0 件
- DB の `LogData` の Result（UI のジョブのログ）: `ParsedResult=Fatal`、Errors に `The operation Backup has failed\r\nDatabaseInconsistencyException: Found inconsistency ...`
- repair: **exit 100、同じ不整合で失敗**（Length は 0 のまま）。その後の backup・test も同じエラー
- list-broken-files: `f3.bin` を 1 件出す。purge-broken-files: exit 0（dlist を上げ直す）。その後の backup: `Backup completed successfully!`
- 別の DB パスで recreate（DB なしの repair）: exit 0、その後の backup も成功（宛先のデータは壊れていないので f3.bin も残る）

## #3286 "One or more errors occurred" with no further information（2018-06-21）
- 直したもの: [#4976](https://github.com/duplicati/duplicati/pull/4976)「Include exception type and message in job log」（Jojo-1000、マージ [`91eace3ab2a735b29b5094608924380db38fbe58`](https://github.com/duplicati/duplicati/commit/91eace3ab2a735b29b5094608924380db38fbe58)、2023-09-21、2.0.7.100 canary）。ts678 の 2024-02 のコメントが指していたもの
- コメント案:
  > I checked this on current master (31bf7aa0225f095de70020700224d3f229dcfe65) with the same kind of failure (a database inconsistency, made by setting one blockset's length to 0). The backup fails with the full message, `Found inconsistency in the following files while validating database: <path>, dbsize 0, actual size 2900, blocksetid: 14. Run repair to fix it. If repair cannot fix it, use list-broken-files and purge-broken-files ...`, and the job log stores it with the exception type (`DatabaseInconsistencyException`); "One or more errors occurred" does not appear. The job log has included the exception type and message since #4976.
  > Would it be OK to close this?

## #3085 Found inconsistency in the following files while validating database（2018-03-06）
- **まだ半分起きる**: repair はこの不整合を直さない（上の手順で exit 100）。ただし、Issue が求めた「消す」道は今はあり、エラーの文面がそれを案内する: list-broken-files・purge-broken-files で該当ファイルを外すとバックアップが通る（[`baf52549`](https://github.com/duplicati/duplicati/commit/baf52549)・[`d18ba56f`](https://github.com/duplicati/duplicati/commit/d18ba56f) は 10-10 の見立てで、今回は中身を確かめ直していない）。recreate でも直る
- 閉じてよいとは言い切れないので、**下書きのまま**。投稿するなら「今の状態の報告」として（利用者の判断）:
  > On current master (31bf7aa0225f095de70020700224d3f229dcfe65), with one blockset's length set to 0 in the local database: `repair` still stops with the same inconsistency, but the error now says what to do, and that works. `list-broken-files` lists the file, `purge-broken-files` removes it from the versions, and the next backup completes. Recreating the database also clears it.
  > Is that enough to close this, or should `repair` handle it?
- 直す候補にもなりうる（repair が不整合の検査で止まって、自分で直せる不整合を直さない）。**推測**: repair の最初の `VerifyConsistency` で止まっている

## #3753 UNIQUE constraint failed: FilesetEntry.FilesetID, FilesetEntry.FileID（2019-04-27）
- 確かめたこと（検証済み、WSL）: Firefox のプロファイルと同じ `lock -> 127.0.1.1:+12345` と、リンク先がない `dangling` を 20 個のファイルと一緒に置き、3 回バックアップ（2 回目はファイルを 1 つ変え、3 回目は lock を別のターゲットで作り直した）。3 回とも `Backup completed successfully!` で exit 0、`list "*lock*" --all-versions` で lock は 3 つの版すべてにある
- **直したものを 1 つに絞れていない**: ts678 は #4256（Support problematic Windows paths、2.0.5.109）を挙げているが、それで直ったとは確かめていない。2019〜2020 のリンクまわりの修正（#4386 など）もある
- 方針（メモリの規則: 直したものと観測の両方）に従い、**下書きのまま**。投稿するなら:
  > I could not reproduce this on current master (31bf7aa0225f095de70020700224d3f229dcfe65), Linux/.NET 10: a folder with a Firefox-style `lock -> 127.0.1.1:+12345` symlink and a dangling symlink, backed up three times (with a changed file, then with `lock` recreated pointing elsewhere), completed each time, and `lock` is in all three versions.
  > Would it be OK to close this?

## 投稿の記録 その3（2026-10-30、利用者がこのセッションで承認）
投稿の直前に、2 件ともコメントの数と最終更新日が変わっていないこと（#3286: 3 件・2024-02-17、#3753: 4 件・2025-05-11）を確かめた。本文は上の下書きと同じ。
- #3286 https://github.com/duplicati/duplicati/issues/3286#issuecomment-6506830961
- #3753 https://github.com/duplicati/duplicati/issues/3753#issuecomment-6506831625（**利用者の判断で、直したものを特定しないまま「再現しない」という観測だけで投稿**）
- #3085 は下書きのまま（repair はまだ直さない）

残りの「閉じてよさそう」: #3985・#5186・#2925・#1226・#5114・#5136・#2744・#5102・#6214・#3020（10 件）

---

# 4 回目の区切り（2026-10-30）

- 残り 10 件を読み直した。手元で確かめられたのは #3020 だけ。ほかは Storj のアカウント（#5102）、利用者の Docker と DNS（#5114・#6214）、古い UI やトレイのスリープ復帰（#1226・#5186・#2925・#2744・#5136）、仕様の話（#3985: 操作は 1 つずつ順番待ちで、ボタンの名前の話）で、見立てのまま
- #3020 だけ投稿した（下の「投稿の記録 その4」）。残り 9 件は見立てのままで、「閉じてよさそう」の一覧からのコメントはここで一区切り

## #3020 Usage statistics causes Duplicati2 to crash when behind a proxy using authentication（2018-02-08）
- 直したもの: [`5e1a260483a8e6cc97f8996340bce9df7463320f`](https://github.com/duplicati/duplicati/commit/5e1a260483a8e6cc97f8996340bce9df7463320f)（kenkendk、2018-02-11、Issue の中で本人が紹介）「Added limits to the number of backlog items the usage reporter will handle」。今の `EventProcessor` は送り残しを新しい順に `MAX_BACKLOG`=6 件だけ送り、残りと 30 日より古いものは消す。`ReportSetUploader` は送信の例外を捕まえて `UsageReporter failed` を Error で記録する
- サーバーも CLI と同じライブラリを使う: サーバーは `StartOrStopUsageReporter` → `Reporter.SetReportLevel` → `Initialize()`（`Duplicati/Server/Program.cs:1300`）、CLI は `Program.cs:51` で `Initialize()`。**途中で「サーバーは送信を始めていない」と書いたのは誤り**（`Initialize` を直接 grep しただけだった）
- 確かめたこと（検証済み、Windows、master の CLI）:
  - 127.0.0.1:18407 に、どの要求にも `407 Proxy Authentication Required`（`Proxy-Authenticate: NTLM` と `Basic`、約 12 KB の HTML 本文）を返す Python のプロキシを置いた
  - 一時フォルダー（`TMP`・`TEMP`）に、別のプロセスの名前の送り残し `dupl-usagereport-<id>-<今の時刻>.json` を 64 個置いた
  - `USAGEREPORTER_Duplicati_LEVEL=Information`（Debug ビルドは既定で送らない、`Reporter.cs:254-258`）と `HTTPS_PROXY`・`HTTP_PROXY` を付けて、`--run-script-before` で 35 秒待つバックアップを走らせた（送信は起動の 20 秒後から）
  - 結果: exit 0・`Backup completed successfully!`（38 秒）。プロキシに来たのは `CONNECT usage-reporter.duplicati.com:443` の 6 回だけで、送り残しは 64 → 7 個（58 個は送らずに消された）。プロセスは落ちていない
  - 1 回目（送信を有効にしない）はプロキシへの接続 0 回で、Debug ビルドの既定で止まっていることを確かめるための対照になった
  - 認証付きのプロキシを通す（資格情報を送る）ことは今もしない（Issue の後半の要望）
- コメント案:
  > I checked this on current master (31bf7aa0225f095de70020700224d3f229dcfe65), Windows, with a local proxy that answers every request with `407 Proxy Authentication Required` and 64 old usage reports left in the temp folder. A backup with usage reporting enabled ran to the end (exit 0); the reporter made only 6 `CONNECT usage-reporter.duplicati.com:443` attempts and deleted the other 58 reports, as limited in 5e1a260483a8e6cc97f8996340bce9df7463320f. The server uses the same reporter code.
  > Sending the reports through an authenticating proxy is still not supported, but that would be a separate feature request. Would it be OK to close this?

## 投稿の記録 その4（2026-10-30、利用者がこのセッションで承認）
投稿の直前に、コメントの数と最終更新日が変わっていないこと（#3020: 最後のコメントは 2018-02-12、更新は 2025-03-24、open）を確かめた。本文は上の下書きと同じ。
- #3020 https://github.com/duplicati/duplicati/issues/3020#issuecomment-6511289935

残りの「閉じてよさそう」: #3985・#5186・#2925・#1226・#5114・#5136・#2744・#5102・#6214（9 件、どれも手元では確かめられない）
