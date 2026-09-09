# 実装済みの enhancement を閉じる依頼の下書き（2026-11-13、219、9 本、11-13 に全部投稿済み（220））

**11-13 の確認（225）**: 閉じられた #2496、open のまま #2493・#2571・#2630・#2709・#2848・#3264・#3751・#4497（`CLOSED-ISSUES-2026-11-13.md`）

10-31 の表で IMPLEMENTED のうち、まだコメントしていなかった 9 本。どれも手元で確かめた（master `6cae627a` の Debug、Windows。#2630 だけ Linux のコンテナ）。
架空の資格情報だけを使い、試験用のサーバーは localhost か Docker の閉じたネットワーク。

確かめたこと:
- #2493: CLI のバックアップの結果を `--send-http-result-output-format=Json` でローカルの受信サーバーへ。`application/json` で届き、JSON として読める（`Data`・`Extra`・`LogLines`・`Exception`）。既定の形式でもパスは `-redacted-` に置き換わり、今回の本文に `"` を含む行はなかった。オプションは b7bda1d1c（2.0.4.3 beta）。
- #2496: `--send-http-url=http://127.0.0.1:8765/1/messages.json --send-http-message-parameter-name=message --send-http-extra-parameters=token=…&user=…&title=Duplicati` で、POST・`application/x-www-form-urlencoded`・キーは `message, token, user, title`（受信側で確認）。Pushover の本物には送っていない。
- #2571: TLS 1.2 だけ（最小 1.2・最大 1.2）の HTTPS の WebDAV もどきに、接続テストの PROPFIND・PUT・GET・DELETE がすべて TLSv1.2 で届いた。最小 1.2 と TLS 1.3 だけのサーバーには TLSv1.3。設定なし（`allowed-ssl-versions` は今は無い）。テストの結果自体は、もどきが GET に 404 を返すので失敗。
- #2630: Docker のネットワーク内の Samba（alpine）に、Linux の CLI（同じ Debug のビルドを `docker cp`）から `smb://smbserver/backup/dup` でバックアップ・一覧・復元、復元したファイルは元と一致、コンテナに cifs のマウントなし。バックエンドは SMBLibrary の `SMB2Client` だけを使う（`SMBShareConnection.cs:176`）。**Windows で割り当てが残らないことは未検証**（445 番が Windows に使われていて、Docker・WSL（ミラー）からは出せず、共有を作るには管理者が要る）。
- #2709: vsftpd（alpine）で、存在しないフォルダーへの接続テストは `missing-folder`、`autocreate=true` で作られて成功、もう一度のテストも成功（Web UI が使う `/api/v1/remoteoperation/test` を直接呼んだ。UI の作成の確認は ngclient の `test-url.ts` の処理でコード根拠）。**pyftpdlib では検出されない**: 存在しないフォルダーの MLSD に `501 No such directory.` を返し、Duplicati は 550・450 だけを「フォルダーなし」と読むので、そのままエラーになる（`FTPBackend.cs:926`）。コメントには書かない。直すかは別に判断。
- #2848: 既定は `synchronous=NORMAL`（WAL）。`CUSTOMSQLITEOPTIONS_DUPLICATI=synchronous=OFF` で再作成すると Verbose に `Setting custom SQLite option 'synchronous=OFF'.`、再作成した DB で一覧も正しい。
- #3264: `\\?\Volume{5e9a162d-…}\Users\…\src\`（C: の GUID）をソースにしたバックアップが成功し、一覧のパスは `C:\Users\…\src\…`。存在しない GUID だけをソースにすると警告のあと `NoSources` で止まる。ドライブ文字が変わったときの動きは未検証（文字を変えるには管理者が要る）。
- #3751: 既存の `ArchiveAttributeTests.TestArchiveAttributesAsync`（一覧で一部・全部を「アーカイブ済み」にすると、それらを検証から外す）が合格（1/1、dup-buildws）。S3 の `s3-archive-classes` の既定は DeepArchive・Glacier・GlacierInstantRetrieval・Snow（`S3AwsClient.cs:111-112`）。71b3152f7（2.1.2.0 beta）。本物の S3 は未検証。
- #4497: 同梱の ngclient 0.0.248 で、SFTP（alpine の OpenSSH）の宛先の「Browse ...」から `home` → `tester` → `backups` → `laptop` を選ぶとパス欄に `home/tester/backups/laptop/`、その後の「Test now」は「Success! Test completed, destination is empty.」。**見つけた小さな問題**: 初めてのホストで先に「Browse ...」を開くと、ホストの鍵を信頼するかを聞かずに「--ssh-fingerprint=… を追加してください」とエラーを出す（「Test now」なら「Approve host key?」が出る）。コメントでは手順として「先に Test」と書く。直すかは別に判断（ngclient）。

別件: #3376 は投稿者が 11-13 に「This covers my request. You may close it now.」と返信（メンテナーが閉じるのを待つ）。

---

## #2493 (Update all possible %result% text messages/errors/warning with quotation marks)

The result can now be sent as JSON: `--send-mail-result-output-format=Json` (and `--send-http-result-output-format=Json` for HTTP reports). Quotes inside messages are then escaped, so the result can be read with a JSON parser instead of splitting the text.

I checked it with the current master: an HTTP report with `Json` came as `application/json` and parsed as JSON (`Data`, `Extra`, `LogLines`, `Exception`). Paths in log messages are also redacted by default now.

I think this can be closed.

## #2496 ([Suggestion] [Feaure request] Pushover as alternative to XMPP or email reporting)

The HTTP report can send to Pushover's API without a script:

```
--send-http-url=https://api.pushover.net/1/messages.json
--send-http-message-parameter-name=message
--send-http-extra-parameters=token=<app token>&user=<user key>
```

I checked the request with a local server instead of Pushover: it is a form POST (`application/x-www-form-urlencoded`) with `message`, `token` and `user`, which is what Pushover's API takes.

I think this can be closed.

## #2571 (Default TLS version for WebDAV)

Duplicati now runs on .NET 10 and uses the operating system's TLS defaults, so TLS 1.2 and 1.3 work without any option.

I checked it with the current master against a WebDAV test server that only accepts TLS 1.2: all requests of the connection test came over TLS 1.2. Against a server that also allows TLS 1.3, they came over TLS 1.3.

I think this can be closed.

## #2630 (Duplicati stores NAS credentials)

Duplicati now has its own SMB client: a `smb://server/share/folder` destination ("SMB" in the destination list) connects to the share directly instead of going through Windows, so the share is not mapped in Windows. This is the local SMB client kenkendk mentioned above.

I checked a backup, a listing and a restore to a Samba share with the current master. I could not check the Windows side here (no free SMB port without admin rights), so that part is from the code: the backend only uses its own SMB2 client.

Should this be closed?

## #2709 (FTP : Create folder if not exist on "test connection")

"Test connection" now changes into the folder to find out whether it exists. When the server answers 550 or 450, the folder is reported as missing and the web UI asks whether to create it.

I checked it with the current master and vsftpd: the test reported the missing folder, creating it worked, and the next test passed.

I think this can be closed.

## #2848 (SQLite performance problem)

Duplicati now opens every database with `journal_mode=WAL` and `synchronous=NORMAL`, so most writes no longer wait for a sync. If you want `synchronous=OFF`, set the environment variable `CUSTOMSQLITEOPTIONS_DUPLICATI=synchronous=OFF`.

I checked it with the current master: with that variable, the verbose log of a database recreate shows `Setting custom SQLite option 'synchronous=OFF'.` and the recreated database is correct.

I think this can be closed.

## #3264 (add filter for drive labels)

The alternative solution in the request works now: a source can be given as `\\?\Volume{GUID}\path\`. Duplicati finds the drive the volume is mounted on at the start of each backup. If the volume is not mounted, it does not back up another drive.

I checked it with the current master on Windows: a source with the volume GUID of C: was backed up as `C:\...`, and a source with an unknown volume GUID stopped the backup with an error.

I think this can be closed.

## #3751 (Error when backup to S3 DEEP_ARCHIVE storage class)

Files in an archive storage class are now skipped when Duplicati verifies the backend files, so Deep Archive no longer causes errors after a backup. The S3 option `--s3-archive-classes` lists the storage classes to treat this way. It includes `DEEP_ARCHIVE` and `GLACIER` by default.

I checked it with the current master: the unit test for archived files passes. It marks some files as archived in the listing, and Duplicati leaves them out of the verification. I did not test it with S3 itself.

I think this can be closed.

## #4497 ([Feature proposal] SFTP browsing)

The new web UI can browse an SFTP server: the destination has a "Browse ..." button next to the folder path.

I checked it with the current master and an OpenSSH server: after "Test now" (to accept the host key), "Browse ..." listed the server's folders, and the folder I picked filled in the path.

I think this can be closed.
