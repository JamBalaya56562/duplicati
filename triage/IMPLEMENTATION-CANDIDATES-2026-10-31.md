# 実装候補 2026-10-31（Issue とフォーラムの再調査 4 回目）

サブエージェント 2 つで調べた（Issue は 10-20 以降と triage に出てこない open、フォーラムは 10-21 以降）。どちらも master `7f5d95a1`（ngclient は `3eca5686`）のコードを読んだだけで、ビルドも実行もしていない。1〜4 のコードの箇所は自分でも読んで確かめた。

| 順 | 出典 | 不具合 | master のコード | まだあるか | 規模 |
|---|---|---|---|---|---|
| 1 | [forum 20747](https://forum.duplicati.com/t/20747)（2.4.0.1、macOS 26、3 台） | メール報告が `SslHandshakeException`（失効確認が終わらない）で失敗し続ける。kenkendk は 2.3.1.0 の OS の検証器と `--ignore-revocation-failure` で直したと言うが、効いていない | `Modules/Builtin/SendMail.cs:294` は `new SmtpClient(...)` から `Connect` するだけで、`ServerCertificateValidationCallback`・`CheckCertificateRevocation`・証明書のオプションがない。`92d6d666e`・`2ca0d1317` は HTTP 系だけで SendMail を触っていない | はい（コードで確認） | 小〜中。HTTP 系と同じオプションを足す。smtp4dev などの自己署名の SMTP で再現 |
| 2 | [forum 22855](https://forum.duplicati.com/t/22855)（2.4.1.0、Win11、チェコの地域設定） | サーバー側の文言がチェコ語で出る | ngclient `core/interceptors/http.interceptor.ts:40-42` は `locale !== 'en-US'` のときだけ `X-Ui-Language` を送る。サーバー `LanguageFilter.cs:30-34` はヘッダーがなければプロセスのカルチャ | はい（コードで確認） | 小。ngclient の PR |
| 3 | [forum 22685](https://forum.duplicati.com/t/22685) #1・#3（Windows） | UI を開くと期限切れのリフレッシュトークンが Duplicati のログにエラー、Windows のイベントログに ASP.NET の Event 1000。kenkendk「害はないがうるさい、直すか黙らせるべき」 | `WebserverCore/Endpoints/V1/Auth.cs:54-58` はどの失敗も `WriteErrorMessage("RefreshTokenError")` してから `UnauthorizedException` | はい（コードで確認）。イベントログの経路は推測 | 小 |
| 4 | [forum 22834](https://forum.duplicati.com/t/22834)（2.4.0.105） | 夏時間の終わった 10-25 から全ジョブが 1 時間早く動く。kenkendk は再現できず | `server-timezone` が未設定だと `ServerSettings.Timezone` は UTC（`:886-890`）、スケジューラはそれを使う。旧 UI は未設定のとき OS のタイムゾーンを表示だけする | 仕組みはある（コードで確認）。利用者が未設定かは推測 | 小〜中。直し方（未設定なら Local を保存する等）は既存のスケジュールへの影響を要確認 |
| 5 | [#7476](https://github.com/duplicati/duplicati/issues/7476)（2.3.0.4→2.4.0.1 の更新が失敗） | インストーラーが走らせる `Duplicati.WindowsService.exe` が `PreloadSettingsLoader.VerifyPreloadFileSecurity` の `UserInformationException`（サービス用ユーザー `C:\Users\Duplicati\...` のフォルダーに予期しない SID の権限）で落ちる。10-24 に報告者がイベントログを追加、メンテナーの返信はまだ | `AutoUpdater/PreloadSettingsLoader.cs` の `VerifyPreloadFileSecurity` は「今のユーザー・SYSTEM・Administrators だけ」でなければ例外。7 月から変わっていない | はい（コードで確認）。なぜ別のアカウントでサービス用ユーザーのフォルダーを読むのかは推測 | 中。誰の権限を許すかはメンテナーの判断 |
| 6 | [forum 22649](https://forum.duplicati.com/t/22649)（2.3.0.4〜） | Jottacloud が 429 を返して落ちる（相手側のリクエスト数の制限） | `Jottacloud.cs:584-660` は 429・`Retry-After` を特別に扱わない | 相手側の方針（推測） | 中。アカウントが要る、価値は低め |
| 7 | [#7265](https://github.com/duplicati/duplicati/issues/7265)（macOS Photos、PhotosAndLibrary） | メモリと swap が 47GB まで増える | 修正 #6996 は報告者の 2.3.0.4 に入っている。列挙ループ（`DuplicatiPhotos.m:173-206`）にアセットごとの autoreleasepool がない | 不明 | 中〜大。大きな Photos ライブラリの Mac が要る |

- 対象外: forum 22839（#7593・#7643 で修正）、22760（kenkendk が直した）、22616・22816・22830・22798・22791（修正済み）、22826・22808・22825（要望）、22827・22845・22835・22685 #11・22781・22840・4988・17080・22853。Issue の #7576（#7595）、#7537（#7565）、#7629〜#7631（重複）、#7627・#7270・#7264・#7024（要望）、#7475・#7455・#7021・#2974（対応済み）
- #6621（UTF-8 でないファイル名）は kenkendk が 10-27 に「.NET のパス関数を避けて OS を直接呼ぶのが本当の直し方」と確認。大きな設計の変更

## 「bug」ラベルの open 60 件（10-31、サブエージェント 3 つ、master `7f5d95a1` のコードを読んだだけ。PRESENT の 4 件は自分でもコードの箇所を確かめた）

前回の「triage に番号があれば扱い済み」という判定は甘かった（`ISSUE-TRIAGE-REPORT.md` で深掘りしたのは 48 件だけで、残りは自動分類）。open は 554 件: enhancement 214・ラベルなし 209・bug 60。

- **閉じられたもの（10-31 夕方）**: #6214（EXTERNAL/NOT-A-BUG としたもの、kenkendk が「解決したと思う」で閉じた）、#7629〜#7631（「重複」としたもの、10-29 に報告者が DUPLICATE で閉じた）。詳細は `CLOSED-ISSUES-2026-10-31.md`

| 判定 | Issue |
|---|---|
| **PRESENT（直す候補）** | #5573（`--restore-with-local-blocks` で元のファイルが別プロセスにロックされていると、`FileProcessor.cs:1342` の `FileOpenRead` に try がなく、警告でなくエラーで止まりうる。Windows で `FileShare.None` で掴めば再現できる、小）・#5570（VSS の「shadow copy is already in progress」に再試行がない、`SnapshotManager.cs:197-205`、小、再現は VSS を 2 つ同時に・管理者権限）・#2680（ngax `addoredit.html:76` の `'Strength: '` が翻訳されない、1 行、ngax の出力の確認が要る）・#5720（rpm の `%post` に SELinux の `semanage`/`restorecon` がない、小、確認に SELinux の VM が要る） |
| PRESENT だが設計・要望寄り | #2720（MSSQL が snapshot-policy を required にし、VSS に対応しないボリュームが混ざるとジョブ全体が失敗）・#3040（バックアップ中にログを見られない。エラー文は改善済み） |
| NEEDS-REPRO（手元で可能） | #3644（中断後の Unexpected difference、前回 SIGKILL/SIGINT 各 25 回で 0 件、SFTP で Stop now を試す）・#3536（/ の見積もりが TB、疎ファイルで）・#5465（ngax の extract.sh、価値低め）・#2556（Yandex WebDAV、添付の propfind をスタブで、添付のダウンロードは要承認）・#2594（`#` のある SMB フォルダー）・#6110（DB の作り直し、#7053 と同じ原因かを確かめる）・#6073（3 万ファイルのバックアップ中の編集画面）・#5830（大きなファイルを HDD へ、ディスク次第） |
| FIXED（根拠つきで閉じる候補、投稿は承認後） | #3375（`d22ce5370`）・#3979（`0b79785f0`、#6694）・#5546（SSH.NET 2024.1.0 以降）・#2825（list-timeout、推測）・#3445（Thread.Abort なし、テストを 1 本足すと確実）・#5508（drift 許容）・#6461（6 本マージ済み、Stop now を 1 回通してから）・#1226（#7085、一部未検証）・#2263・#2265・#2359・#2480・#2498（duplicates の方）・#2602・#2631・#2663（未再現、前回は見送り） |
| 返事待ち（こちらのコメント済み） | #2298・#2604・#3020・#4714 |
| EXTERNAL / NOT-A-BUG / NO-INFO | #2859・#2862・#5559・#2690・#2744・#5793（uplink の segfault、別プロセス化は大）・#5908（FluentFTP/SslStream）・#5621（pCloud 専用バックエンドを案内）・#5605・#6214・#5868・#5677・#6076（イベントログの行はクラッシュでない）・#6032・#6051・#5999・#6101・#5670・#5944・#5593・#1442・#2049・#2351・#2392・#2501（ついで: missing のメッセージが purge-broken-files を案内しない、`FilelistProcessor.cs:202`）・#2641 |

- 以前の判定を変えるもの: #6076（FIXED ではなく NO-INFO）、#6051（#6529 で FIXED の根拠なし）、#6110（FIXED ではなく要再現）
