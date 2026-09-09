# 古い open Issue のうち master で直っているもの（下書き、2026-10-24）

- 対象: upstream の open Issue のうち 2025 年より前に作られ、triage（`ISSUE-TRIAGE-REPORT.md`・`PENDING-BRANCHES.md`・`IMPLEMENTATION-CANDIDATES-2026-10-10.md`）と共有ノートにまだ番号が出ていないもの（205 件）から、機能の要望を除いて 21 件を選んだ
- 基準にした master: [`5ef1a23758f36ab7c123d1c7b30cb39d047bcb9c`](https://github.com/duplicati/duplicati/commit/5ef1a23758f36ab7c123d1c7b30cb39d047bcb9c)（`jj git fetch --all-remotes` の後も最新はこれ）
- **GitHub には何も投稿していない。** 下のコメント案は利用者が見て決めるためのもの
- 再現は scratchpad 内の別の jj workspace（`stale-issues`）で `dotnet build Duplicati.slnx` してから行った。補足: このビルドは MSB3030（`WindowsModules` のネイティブ DLL `microsoft.management.infrastructure.native.unmanaged.dll` のコピー）で exit 1 になった。`Duplicati.CommandLine.exe` と `Duplicati.UnitTest.dll` はできており、どちらも同じツリーから作られたもの
- 判定: **(A)** 直っている（直したコミットや PR と観測の両方がある）/ **(B)** 直っているらしい（コードだけが根拠）/ **(C)** まだ起きる / **(D)** 判断できない

## 件数

| 判定 | 件数 | Issue |
|---|---|---|
| (A) | 11 | #4536, #5210, #3738, #4532, #4535, #4534, #4546, #4545, #4554, #4636, #4318 |
| (B) | 3 | #3190, #3570, #3548 |
| (C) | 4 | #3605, #3948, #4992, #4523 |
| (D) | 3 | #4044, #3497, #4192 |

---

## (A) 直っている

### #4536 Remove AlphaFS if possible（2021-05-27）
- 根拠: [#5211](https://github.com/duplicati/duplicati/pull/5211)「Removing unsupported AlphaFS.」で直った（マージ [`f70748359a3e7859b1c3bc2d9ddc74eba19e28c8`](https://github.com/duplicati/duplicati/commit/f70748359a3e7859b1c3bc2d9ddc74eba19e28c8)、2024-06-11）
- 観測: `git grep -l -i AlphaFS 5ef1a237 -- ':!changelog.txt'` → **0 件**
- コメント案:
  > AlphaFS was removed in #5211 (merged June 2024), and current master has no remaining references to it (`git grep AlphaFS` returns nothing).
  > Would it be OK to close this as completed?

### #5210 Incompatible NuGet packages for .NET 8（2024-05-30）
- 根拠: 報告にある 3 つの依存のうち、AlphaFS は [#5211](https://github.com/duplicati/duplicati/pull/5211) で消えた。Sharp.Xmpp と ARSoft.Tools は [#5213](https://github.com/duplicati/duplicati/pull/5213)「Change XMPP library to Artalk.Xmpp」で置き換わった（マージ [`245d2f5e95dd5f56f49769fa31360ae45087cf37`](https://github.com/duplicati/duplicati/commit/245d2f5e95dd5f56f49769fa31360ae45087cf37)）
- 観測: `*.csproj` を `Sharp.Xmpp|ARSoft` で `git grep` すると **0 件**。ヒットしたのは `Artalk.Xmpp` 1.0.5（`Duplicati.Library.Modules.Builtin.csproj:14`）だけ。このツリーは net10.0 でビルドできる（上の注記）
- コメント案:
  > All three packages listed here are gone from current master: AlphaFS was removed in #5211, and Sharp.Xmpp/ARSoft.Tools were replaced by Artalk.Xmpp in #5213.
  > The solution now builds on .NET 10. Is it OK to close this one?

### #3738 Remove the Utility.AsyncHttpRequest class（2019-04-17）
- 根拠: [#6291](https://github.com/duplicati/duplicati/pull/6291)「Remove OAuthHelper」の中のコミット [`0eef7ec49b56e37a1107422701a3e1a549eacef2`](https://github.com/duplicati/duplicati/commit/0eef7ec49b56e37a1107422701a3e1a549eacef2)「Final removal of AsyncHttpRequest.」（マージ [`e99bcd84f393c9fe33b06559235ec42f65f149a8`](https://github.com/duplicati/duplicati/commit/e99bcd84f393c9fe33b06559235ec42f65f149a8)、2025-05-26）
- 観測: `git grep -l AsyncHttpRequest 5ef1a237` → **0 件**
- コメント案:
  > `AsyncHttpRequest` was removed in #6291 ("Final removal of AsyncHttpRequest", May 2025), and master no longer contains it.
  > Could this be closed as completed?

### #4532 Replace usages of WebClient, WebRequest and HttpWebRequest（2021-05-27）
- 根拠: 最後の `WebRequest.Create` も、上と同じ [`0eef7ec49b56e37a1107422701a3e1a549eacef2`](https://github.com/duplicati/duplicati/commit/0eef7ec49b56e37a1107422701a3e1a549eacef2)（[#6291](https://github.com/duplicati/duplicati/pull/6291)）で消えた（`git log -S'WebRequest.Create'` で確認）
- 観測: ソースで `new WebClient` も `WebRequest.Create` も **0 件**。`HttpWebRequest` が残るのは同梱のバイナリ `thirdparty/SharePointPnP-Sites-Core/SharePointPnP.Client.dll` だけ
- コメント案:
  > Current master has no `WebClient`/`WebRequest.Create`/`HttpWebRequest` usages left in Duplicati's own source; the last ones went away with #6291.
  > The only remaining match is inside the bundled third-party SharePointPnP client binary. Would it be OK to close this?

### #4535 Replace custom web server with Kestrel implementation（2021-05-27）
- 根拠: [#5112](https://github.com/duplicati/duplicati/pull/5112)「Feature/kestrel avalonia upgrade」（マージ [`75efe35e3da6b4960fac2c8f7350b8900a41af8e`](https://github.com/duplicati/duplicati/commit/75efe35e3da6b4960fac2c8f7350b8900a41af8e)、2024-04-21）
- 観測: 今のサーバーは `Duplicati/WebserverCore/DuplicatiWebserver.cs` の Kestrel だけで、古い自前の HTTP サーバー（`Duplicati/Server/WebServer/`）は master にない
- コメント案:
  > The web server was moved to ASP.NET Core/Kestrel in #5112 (April 2024); the old custom server code is no longer in master.
  > Is it OK to close this as completed?

### #4534 Make all backends async（2021-05-27）
- 根拠: [#5978](https://github.com/duplicati/duplicati/pull/5978)「Final conversion to async backends」（マージ [`4822bc45505384053c73dfa22703846e5a4e3a5d`](https://github.com/duplicati/duplicati/commit/4822bc45505384053c73dfa22703846e5a4e3a5d)、2025-02-26）。その前に [#5574](https://github.com/duplicati/duplicati/pull/5574) もある
- 観測: `Duplicati/Library/Interface/IBackend.cs` は `Task PutAsync(..., CancellationToken)`・`Task GetAsync(...)`・`Task DeleteAsync(...)`（64・72・79 行目）で、同期版は残っていない
- コメント案:
  > All backends were converted to the async interface in #5978 (Feb 2025); `IBackend` now only exposes `PutAsync`/`GetAsync`/`DeleteAsync` with cancellation tokens.
  > Could this be closed?

### #4546 RSACryptoServiceProvider(CspParameters) isn't supported on Linux and macOS（2021-05-28）
- 根拠: `CspParameters` は [#4584](https://github.com/duplicati/duplicati/pull/4584)「Fix server certificate on Linux」（[`bfdeae06d8ebfc93417ea41ed32e824bff8e249c`](https://github.com/duplicati/duplicati/commit/bfdeae06d8ebfc93417ea41ed32e824bff8e249c)、マージ [`265d202a1f99f12f7c5bcf8b9e0deac50ac799c3`](https://github.com/duplicati/duplicati/commit/265d202a1f99f12f7c5bcf8b9e0deac50ac799c3)、2021-07-27）で消えた（`git log -S'CspParameters'`）
- 観測: `git grep 'CspParameters' 5ef1a237 -- '*.cs'` → **0 件**。残っているのは引数なしの `new RSACryptoServiceProvider()`（`AutoUpdateSettings.cs:318`）と `RSACryptoServiceProvider.Create()`（`KeyGenerator.cs:162`）で、どちらも全 OS で使える
- コメント案:
  > The `RSACryptoServiceProvider(CspParameters)` constructor that triggered this warning is no longer used; it went away in #4584, and master has no `CspParameters` references.
  > Is it OK to close this?

### #4545 X509Certificate2(byte[]) isn't supported on macOS（2021-05-28）
- 根拠: 証明書の読み込みは `X509CertificateLoader.LoadCertificate`/`LoadPkcs12` に移った（`CertificateGenerator.cs:109,230,268`、`CertificateStorageHelper.cs:58`）。移行は何回かに分かれていて、直近は [`2e4ba154156c90845e606cace8bdfed239a9fd34`](https://github.com/duplicati/duplicati/commit/2e4ba154156c90845e606cace8bdfed239a9fd34)（2026-07-09）。**1 つのコミットにはまとめられない**
- 観測: `git grep -E 'new X509Certificate2\(' 5ef1a237 -- '*.cs'` → 1 件だけ（`SslCertificateValidator.cs:60` の `new X509Certificate2(X509Certificate)`）。`byte[]` を取るコンストラクタはどこからも呼ばれていない。追記にある `PrivateKey.set` も 0 件
- コメント案:
  > Certificate loading now goes through `X509CertificateLoader`, and master no longer calls the `X509Certificate2(byte[])` constructor (or `PrivateKey.set`) anywhere.
  > Would it be OK to close this?

### #4554 Embedded resources are missing on experimental/net5-split branch（2021-06-11）
- 根拠: 報告の例は `newbackup.json` が読めず既定値が「暗号化なし」になる症状で、[#6249](https://github.com/duplicati/duplicati/pull/6249)「Fix loading default backup config」（[`5630c5e34ad27ecca671b77508c06f980b5a955a`](https://github.com/duplicati/duplicati/commit/5630c5e34ad27ecca671b77508c06f980b5a955a)、マージ [`eb631b117dd507e386ea5f0c44208a149ebfbb44`](https://github.com/duplicati/duplicati/commit/eb631b117dd507e386ea5f0c44208a149ebfbb44)、2025-05-12）で直った。今は型 `BackupDefaultsResourceMarker`（名前空間 `Duplicati.Library.RestAPI`）を基準に読む
- 観測: ビルドした `Duplicati.Library.RestAPI.dll` に埋め込まれたリソース名は `Duplicati.Library.RestAPI.newbackup.json`（`grep -a -o` で確認）。読み込み側（`WebserverCore/Endpoints/V1/BackupDefaults.cs:63`）の `GetManifestResourceStream(typeof(BackupDefaultsResourceMarker), "newbackup.json")` が探す名前と同じ。報告にあった branch（experimental/net5-split）はもう使われていない
- コメント案:
  > The branch this was reported on is no longer used, and the `newbackup.json` symptom was fixed on master by #6249; the embedded resource name now matches what the loader looks up.
  > Is it OK to close this one?

### #4636 Unit tests can fail trying to load Duplicati.Library.Backend.OneDrive.dll（2021-11-07）
- 根拠: 原因は .NET Framework の `app.config` にあった `System.Net.Http` の bindingRedirect。SDK 形式・.NET 8 への移行（[#5111](https://github.com/duplicati/duplicati/pull/5111)「Feature/upgrade to net8」、マージ [`a31a2888199b441eb1acc25bf2c272b5c51ce0cd`](https://github.com/duplicati/duplicati/commit/a31a2888199b441eb1acc25bf2c272b5c51ce0cd)、2024-04-21）でなくなった。リダイレクトのファイルは [`162c9291e72d7720b2cbadc9b3b23e9c4f152ef0`](https://github.com/duplicati/duplicati/commit/162c9291e72d7720b2cbadc9b3b23e9c4f152ef0)「Removed unused redirect file」で消えた
- 観測: `git grep -l bindingRedirect 5ef1a237` → 0 件。報告で落ちていたテストを今の名前で回した:
  `dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "FullyQualifiedName~Duplicati.UnitTest.RecoveryToolTests"` →
  `成功 RecoverAsync("false","true")`・`RecoverAsync("true","false")`・`RecoverAsync("false","false")` などを含め、RecoveryToolTests の 9 件すべてが成功（Windows）
- コメント案:
  > I ran `RecoveryToolTests` (now `RecoverAsync`) on current master on Windows and all cases pass; the `System.Net.Http` binding redirects that caused the load failure disappeared with the move to SDK-style/.NET 8 projects (#5111).
  > Would it be OK to close this?

### #4318 Backups flagged "Warning" because Duplicati thinks the backend storage is getting full（2020-09-17）
- 根拠: 報告は Mono の時代のもので、NFS をマウントした先ではなく親のディスクの容量を見ていた。今は .NET で、容量は `Utility.GetFreeSpaceForPath`（`Utility.cs:2403`。[`05ea1dfafeb307ab0b09514fd9df976fdcb1105b`](https://github.com/duplicati/duplicati/commit/05ea1dfafeb307ab0b09514fd9df976fdcb1105b)、2026-02-06）が Windows 以外で `new DriveInfo(path)` を使って調べる
- 観測（WSL Ubuntu-Preview、.NET 10.0.401、同じ `new DriveInfo(path)` を呼ぶ小さなプログラム）:
  ```
  /: TotalSize=1081101176832 AvailableFreeSpace=971417878528
  /mnt/c/Users/Jam/Documents: TotalSize=1021945311232 AvailableFreeSpace=255672496128
  df: /dev/sdd 1081101176832 ... /     C:\ 1021945311232 ... 255672496128 /mnt/c
  ```
  別のファイルシステムがマウントされたパスでは、そのマウント先の容量が返り、`df` と一致した。**NFS そのものは試していない**（drvfs で代わりに確かめた）。`GetFreeSpaceForPath` を直接呼んだのではなく、そこにある 1 行を同じように呼んだ
- コメント案:
  > Duplicati no longer runs on Mono; on .NET the local backend's quota comes from `DriveInfo(path)`, which on Linux reports the filesystem mounted at that path (checked on a WSL mount: values match `df`).
  > I couldn't test NFS itself — if you still see the wrong numbers on a recent version, please let us know; otherwise, is it OK to close this?

---

## (B) 直っているらしい（コードだけが根拠）

### #3190 All VolumeUploadRequests' CreateIndexVolume are true（2018-04-25）
- 根拠: 報告の 5 日後に入ったコミット [`30814472719c9e19c4552466f3b7a93664cef82a`](https://github.com/duplicati/duplicati/commit/30814472719c9e19c4552466f3b7a93664cef82a)「Added an on-the-fly index builder to avoid querying the database for each volume」（kenkendk、2018-04-30、最初に入ったリリースは v2.0.3.7 canary 2018-06-17）で、ボリュームごとに DB へ問い合わせる処理がなくなった。今の master では、`IndexVolumeWriter` を `BackendManager.PutAsync` に渡して作りながら進める形になっている。DB から index を作る `IndexVolumeCreator.CreateIndexVolumeAsync` を呼んでいるのは `RecreateMissingIndexFiles.cs:45` だけ
- 観測: なし（性能は測っていない）。**未検証**
- コメント案:
  > Shortly after this report, 30814472 ("Added an on-the-fly index builder to avoid querying the database for each volume", in 2.0.3.7) changed backups to build index volumes alongside the block volumes. In current master the database-driven `CreateIndexVolume` path is only used when recreating missing index files.
  > If you no longer see this slowdown, would it be OK to close this?

### #3570 Send-xmpp not working with non-standard C2S port（2018-12-29）
- 根拠: ポートは昔から jid に書けた（`user@server:port`。2014 年の [`d645be1e0a9e60da166b8ab9ce61fce96e2b0519`](https://github.com/duplicati/duplicati/commit/d645be1e0a9e60da166b8ab9ce61fce96e2b0519) から）。今の master では `SendJabberMessage.ParseXmppTarget` が `System.Uri` で解析する（[`dfaf60af9f245742c31b92bb4e25147fda454edb`](https://github.com/duplicati/duplicati/commit/dfaf60af9f245742c31b92bb4e25147fda454edb)、2026-08-10）。ライブラリも [#5213](https://github.com/duplicati/duplicati/pull/5213) で Artalk.Xmpp に替わった。**DNS の SRV レコードは引かない**（報告の後半の要望は満たしていない）
- 観測: `dotnet test ... --filter FullyQualifiedName~XmppTargetTests` → 9 件成功（`AnExplicitPortIsUsedAsGiven` は `user@server.example.com:5333` → port 5333）。本物の XMPP サーバーにはつないでいない（**接続は未検証**）
- コメント案:
  > A non-standard port can be given in the username as `user@server:port` (e.g. `user@example.org:5333`); current master parses it with `System.Uri` and uses the Artalk.Xmpp client (#5213). SRV lookup is still not done.
  > Could you check whether that works with your server on a recent version? If so, is it OK to close this?

### #3548 --auth-password doesn't work with special characters（2018-12-19）
- 根拠: 今の CLI は `--auth-password` の値をそのままバックエンドに渡し、URL のクエリにある場合だけ復号する
- 観測（WebDAV。127.0.0.1 の受け口で Basic 認証のヘッダーを受け取って復号した）:
  - `list webdav://127.0.0.1:18765/dav --auth-username=user --auth-password='pa+ss%2Bw&d'` → `decoded='user:pa+ss%2Bw&d'`（`+` も `%2B` もそのまま）
  - `--auth-password='SOMEPASSWORDWITHA+'` → `decoded='user:SOMEPASSWORDWITHA+'`
  - `webdav://...?auth-username=user&auth-password=pa%2Bss` → `decoded='user:pa+ss'`
  **S3 そのものは試していない**（推測: 報告のコマンド `s3://storage-fqdn:9000/bucketname` は、ホスト名の位置にバケット名を書く S3 の URL の形式と違っていて、それが「つながらない」の本当の理由だった可能性がある）
- コメント案:
  > On current master the CLI passes `--auth-password` through unchanged: capturing a WebDAV request showed `SOMEPASSWORDWITHA+` arrive intact (I haven't tested S3 itself).
  > Note that for S3 the URL form is `s3://bucketname/prefix --s3-server-name=host:9000`. If this works for you on a recent version, would it be OK to close this?

---

## (C) まだ起きる（後で直す候補）

### #3605 Mail not sent after run-script fails（2019-01-14）
- 観測（`Duplicati.CommandLine.exe backup`。`--send-http-url` を 127.0.0.1 の受け口に向け、`--send-http-level=all`。メールの代わりに HTTP の通知で確かめた）:
  | ケース | 終了コード | 届いた通知 |
  |---|---|---|
  | `--run-script-before` が `exit /B 5` | 3。出力は「Backup completed successfully!」 | **なし** |
  | `--run-script-before-required` が `exit /B 1` | 100（`RunScriptInvalidExitCode`） | **なし** |
  | `--run-script-before` が `exit /B 1`（仕様は「OK, don't run」） | 1 | なし |
  | 対照（スクリプトなし） | 0 | `POST /report`（JSON 4255 バイト） |
- 補足: 直そうとした PR [#5245](https://github.com/duplicati/duplicati/pull/5245)「Changed logic so all modules are loaded before any are started」は **マージされずに閉じられた**。中止した場合でも CLI が「Backup completed successfully!」と出すことは、スレッドの michaelheider の観測と一致する
- 後続の候補: `Controller.cs:1055-1063` でモジュールを 1 つずつ `Configure` → `OnStart` している。run-script が先に投げると、後ろの report 系のモジュールはまだ構成されていないので、`OnFinish`（989-994 行目）でも送られない（**コードからの推測**。#5245 と同じ見立て）。直し方は #5245 と同じく、全部を Configure してから OnStart する形が候補
- コメント案（まだ起きることを伝える形。閉じる提案はしない）:
  > I re-tested on current master: when `--run-script-before` exits with 5, or `--run-script-before-required` fails, no report is sent (tested with `--send-http-url` + `--send-http-level=all`), while a normal run does send one.
  > So this still reproduces; #5245 attempted a fix but was closed unmerged.

### #3948 No site ID was provided while using Sharepoint V2（2019-10-16）
- 観測: `Duplicati.CommandLine.exe list "sharepoint://contoso-my.sharepoint.com/personal/someone_contoso_com//Documents/Vhds" --authid=dummy` → `ErrorID: SharePointMissingSiteId`（「No site ID was provided」の訳）、exit 100
- 原因（コード）: `SharePointV2.cs:42-53` のコンストラクタが、`--site-id` がなければすぐ `UserInformationException` を投げる。一方、URL（`//` で区切る形）からサイト ID を自動で見つける `GetRootPathFromUrlAsync`（同ファイル 75 行目以降）とそのコメントはあるのに、コンストラクタのせいでそこまで進まない。site-id がない場合、自動で見つける処理は呼ばれずに終わる
- 後続の候補: site-id がないときは投げずに、`drivePath` を `GetRootPathFromUrlAsync` で見つけた `siteId` から遅れて決める。Graph API をスタブにした単体テストで確かめられる（[[duplicati-offline-backend-test-patterns]]）
- コメント案:
  > This still reproduces on current master: `sharepoint://tenant-my.sharepoint.com/personal/user//Documents/x` without `--site-id` fails immediately with "No site ID was provided", because the constructor throws before the URL-based site lookup runs.
  > Workaround: pass `--site-id` explicitly. Keeping this open for a fix.

### #4992 JQuery is significantly out of date（2023-07-14、security）
- 観測: `Duplicati/Server/webroot/login.html:9` が今も `login/jquery-2.0.3.min.js` を読み込んでいる。`StaticFilesMiddleware.cs:36` は `/login.html` を配信し、ngax（`app.js:14`・`AppController.js:25` など）はログインのたびにこのページへ移る
- 後続の候補: `login/login.js` から jQuery をなくす（小さいはず。**未確認**）か、jQuery 3.7 以降に上げる。ngax を保守する方針（[[maintain-old-ui-ngax]]）の範囲。ngclient には関係しない
- コメント案:
  > Still present on current master: `/login.html` (used by the legacy ngax UI) loads `login/jquery-2.0.3.min.js`.
  > Keeping this open; it should be a small change to drop or upgrade jQuery there.

### #4523 Create separate issues for TODO-DNC markers（2021-05-27）
- 観測: `git grep TODO-DNC 5ef1a237` → **残りは 1 件**（`OAuthHelper/OAuthHttpClient.cs:121`。ReadWriteTimeout の設定をコメントアウトしたもの。dotnet/corefx#26223）
- 後続の候補: この 1 件を別の Issue に分けるか、`HttpClient.Timeout` などの今の仕組みで足りているなら、コメントのブロックを消せば終わる
- コメント案:
  > Only one `TODO-DNC` marker remains on master (`OAuthHttpClient.cs`, the commented-out ReadWriteTimeout block); all others are gone.
  > Would it be OK to close this once that last one is resolved or split into its own issue?

---

## (D) 判断できない

### #4044 RecoveryTool restore: Too many open files（2020-01-07）
- コード: `CompressedFileMRUCache` は開くアーカイブを `MAX_OPEN_ARCHIVES`（既定 200）までに抑え、古いものから stream と reader を閉じる（`RecoveryTool/Restore.cs:566-618`）。上限 200 は 2015 年から、stream を自分で持つ形は 2017 年の [`62a7901aca6a7303a1492bdd3f9a7ba3b8998c77`](https://github.com/duplicati/duplicati/commit/62a7901aca6a7303a1492bdd3f9a7ba3b8998c77) からで、**報告の時点でも同じ仕組みだった**。2024 年の [`c50e027ecdcf70091050aada55d48983de6535b1`](https://github.com/duplicati/duplicati/commit/c50e027ecdcf70091050aada55d48983de6535b1) で `--max-open-archives` を指定できるようになった
- 直したコミットは見つからない。原因（どこで漏れていたか）も分からない。再現には Linux で `ulimit -n` を下げたうえで、大きな復元を回す必要がある（**未検証**）
- コメント案: なし（判断できないので投稿しない。必要なら「`--max-open-archives` で上限を下げられる」と案内するだけにする）

### #3497 / #4192 OneDrive for Business: "Cannot send a content-body with this verb-type"（2018-11-15 / 2020-05-07）
- コード: OD4B（`SharePoint/OneDriveForBusinessBackend.cs`）は今 `thirdparty/SharePointPnP-Sites-Core/SharePointPnP.Client.dll` を使っている。その置き換え（[`787bcb57aee56d9a7c3e7dfe7ad88d277dfda7f2`](https://github.com/duplicati/duplicati/commit/787bcb57aee56d9a7c3e7dfe7ad88d277dfda7f2)、2019-05）が master に入ったのは [#5112](https://github.com/duplicati/duplicati/pull/5112)（2024-04）で、同じころ Mono もなくなった。kenkendk は「Mono の HTTP の問題だろう」とコメントしている
- 直っている可能性はあるが、OD4B のアカウントがないと確かめられない（**未検証**）。PnP クライアントは中で `HttpWebRequest` を使っている
- コメント案（報告した人に確かめてもらう形）:
  > Since this was reported, Duplicati moved off Mono to .NET and the OneDrive for Business backend now uses an updated SharePoint client library (#5112). I can't test OD4B myself.
  > Could someone affected check whether this still happens on a recent version? (The `onedrivev2` Microsoft Graph backend is also an alternative.)

---

## 片付け
- scratchpad の jj workspace `stale-issues`（`…\scratchpad\ws`、ビルドの成果物あり）: **まだ消していない**。消すときは `jj workspace forget stale-issues` のあとフォルダーを削除する
- WSL の `~/p4318`: スクリプトの最後で削除済み
- 受け口（python）: スクリプトの最後で kill 済み

---

## 投稿の記録（2026-10-24、利用者がこのセッションで承認）
投稿の直前に、コメントの数が変わっていないこと（最近の動きがないこと）を確かめた。全文は上の「コメント案」ではなく、実際に投稿した版（master の完全な SHA を足したもの）。
- #4636 https://github.com/duplicati/duplicati/issues/4636#issuecomment-6378532691
- #4536 https://github.com/duplicati/duplicati/issues/4536#issuecomment-6378533060
- #5210 https://github.com/duplicati/duplicati/issues/5210#issuecomment-6378533299
- #3738 https://github.com/duplicati/duplicati/issues/3738#issuecomment-6378533638
次の区切りの候補（まだ投稿していない）: #4532, #4535, #4534, #4546, #4545。#4554 はサーバーで既定値を確かめてから、#4318 は NFS で確かめるまで (A) にしない。

---

## 追加の確認（2026-10-24、#4554 と #4318）
対象は upstream の最新 master [`71981c36c4774d36f527b500a1c940933b02608f`](https://github.com/duplicati/duplicati/commit/71981c36c4774d36f527b500a1c940933b02608f)。scratchpad の jj workspace でビルドした。

### #4554 → 直っている (A)（検証済み）
- 手順: `Duplicati.Server` をビルドし（0 警告・0 エラー）、mise の dotnet で起動した: `dotnet Duplicati.Server.dll --server-datafolder=<空のフォルダー> --webservice-port=8454 --webservice-password=<テスト用> --webservice-interface=loopback`。`POST /api/v1/auth/login` でトークンを取り、UI が新しいバックアップを作るときに読む `GET /api/v1/backupdefaults` を呼んだ
- 結果（抜粋）: `"Backup": { "Settings": [ { "Name": "encryption-module", "Value": "aes" }, { "Name": "keep-time", "Value": "" } ] }, "Schedule": { "Repeat": "1D", "Time": "13:00:00", ... }`。既定値は「暗号化なし」ではなく `aes` だった
- サーバーのログに `BackupDefaultsError`・`Failed to locate embeded backup defaults` は出なかった（`grep` で 0 件）。bin フォルダーに上書き用の `newbackup.json` はないので、この値は埋め込みリソースから来ている
- Issue に挙がっていた他の埋め込みリソースのうち、DB のスキーマは空のデータフォルダーに `Duplicati-server.sqlite` が作られたので読めている。それ以外は個別には確かめていない
- コメント案（未投稿。投稿するなら利用者の確認を取る）:
  > I started the server built from current master (71981c36c4774d36f527b500a1c940933b02608f) with an empty data folder and called `GET /api/v1/backupdefaults`: it returns `encryption-module: aes` (not "No encryption"), with no `BackupDefaultsError` in the log.
  > The `newbackup.json` resource is loaded correctly since #6249, and the `experimental/net5-split` branch is no longer used. Would it be OK to close this?

### #4318 → 直っている (A)（検証済み、NFS で）
- 環境: WSL Ubuntu-Preview（カーネル 6.18.54.1、ネットワークは mirrored）、.NET 10.0.401。利用者の許可を得て `nfs-kernel-server` を入れた（依存も含めて 7 パッケージ、約 650 KB）
- 構成: 4 MB の tmpfs を `/mnt/p4318` に置き、空きを 16 KB まで埋めた（Issue の「親のディスクがいっぱい」の状態）。256 MB の tmpfs `/srv/exp4318` を NFSv4.2 で公開し、`/mnt/p4318/nfs` にマウントした。mirrored モードでは 127.0.0.1:2049 につながらず、`10.255.255.254` 経由でマウントした
  ```
  tmpfs                         4194304 4177920     16384 100% /mnt/p4318
  10.255.255.254:/srv/exp4318 268435456       0 268435456   0% /mnt/p4318/nfs
  ```
- `Utility.GetFreeSpaceForPath` が Windows 以外で呼ぶのと同じ `new DriveInfo(path)`:
  ```
  /mnt/p4318: TotalSize=4194304 AvailableFreeSpace=16384
  /mnt/p4318/nfs/target: TotalSize=268435456 AvailableFreeSpace=268435456
  ```
  NFS 側のパスでは NFS の容量が返った。親の値ではない
- master の CLI（Windows でビルドした net10.0 の dll を WSL で `dotnet Duplicati.CommandLine.dll` として実行）で `backup file:///mnt/p4318/nfs/target <3 MB の乱数> --no-encryption`:
  - run 1（既定の `quota-warning-threshold`=10%）: exit 0、警告なし。`Total remote quota: 256.00 MiB` / `Available remote quota: 254.00 MiB`。もし親の値（空き 16 KB）を見ていたら、16 KB < 2.87 MiB の 10% なので警告が出るはず
  - run 2（対照、`--quota-warning-threshold=10000`）: exit 2、`Backend quota is close to being exceeded: Using 2.87 MiB of 256.00 MiB (254.00 MiB available)`。警告を出す仕組みは働いており、使っている値は NFS 側の 256 MiB
- 後片付け: アンマウント、exports の削除、nfs-server の停止、7 パッケージの `apt-get purge`、`~/x4318` の削除まで済んだ（`findmnt` に残りなし。`dpkg -l` に残っている `libkeyutils1` は前から入っていたもので、今回の 7 つには入っていない）。nfsd モジュールは WSL を再起動するまで読み込まれたまま
- コメント案（未投稿。投稿するなら利用者の確認を取る）:
  > Checked on current master (71981c36c4774d36f527b500a1c940933b02608f), Linux/.NET 10: a 256 MiB NFSv4.2 export mounted on a nearly full 4 MiB filesystem. A backup to `file:///<mount>/target` reported `Total remote quota: 256.00 MiB` / `Available: 254.00 MiB` and no quota warning.
  > Duplicati no longer runs on Mono; the local backend now takes the quota from `DriveInfo` of the target path, which reports the mounted NFS filesystem. Would it be OK to close this?

## 投稿の記録 その2（2026-10-24、利用者がこのセッションで承認）
投稿の直前に、2 件ともコメントの数と最終更新日が変わっていないことを確かめた。本文は上の「追加の確認」に書いたコメント案と同じ。
- #4554 https://github.com/duplicati/duplicati/issues/4554#issuecomment-6383094376
- #4318 https://github.com/duplicati/duplicati/issues/4318#issuecomment-6383094967
