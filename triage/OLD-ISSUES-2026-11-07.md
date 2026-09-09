# 古い Issue の調査 2026-11-07

利用者の指示「まだ詳しく調査していない古い Issue の調査」。open の Issue 534 件のうち、これまでの 3 回の仕分け（bug・ラベルなし・enhancement）の表に入っていない 116 件から、メンテナー自身のものを除いた 102 件を、サブエージェント 3 つでコードと履歴を読んで仕分けた（master `6dee7d94`）。**サブエージェントの判定はコードを読んだだけ**で、私が確かめたものだけ「検証済み」「コード根拠（確認）」と書く。102 件のうち約半分は以前の記録で既に触れていた。取得した Issue の本文は scratchpad の `oldsweep/p01`・`p02`・`p00issues`。

## 実装候補

| Issue | 内容 | 根拠 | 規模 |
|---|---|---|---|
| [#3351](https://github.com/duplicati/duplicati/issues/3351) | ngclient のフィルターで、フォルダーの末尾に `/` があると `//` になる | **コード根拠（確認）**: ngclient `backup/source-data/filter/filter.component.ts` の `#mapToPath` の Folder 分岐で、先頭だけにあるときに先頭へ、末尾だけにあるときに末尾へ区切りを足している（逆）。ngclient の単体テストで赤→緑にできる | 小（ngclient） |
| [#4082](https://github.com/duplicati/duplicati/issues/4082) | GUI の Commandline で test などを実行すると `FormatException` | **コード根拠（確認）**: CLI `Commands.cs:937` の `Convert.ToInt64(args[1])` に検査がない。ngclient の `commandline.component.ts:189` がどのコマンドでも引数に元フォルダーを入れる（サブエージェント、未確認） | 小（本体と ngclient で 2 本） |
| [#2889](https://github.com/duplicati/duplicati/issues/2889) | recreate が遅い。`LocalRecreateDatabase.cs:574-587` の `(BlocksetID ‖ ':' ‖ Index) NOT IN (...)` は索引を使えず、変化のあった block volume ごとに走る | サブエージェント（コードを読んだだけ、効果は測るまで推測）。本番の pragma で測る | 小〜中 |
| [#2193](https://github.com/duplicati/duplicati/issues/2193) | S3 の server-side encryption のヘッダーを付けるオプション（`S3AwsClient.cs:295-305`） | サブエージェント。スタブの HttpMessageHandler で送るヘッダーを確かめられる | 小（要望） |
| [#2265](https://github.com/duplicati/duplicati/issues/2265) の残り | repair が DB を開けないとき、ロック中などの読み取りエラーでも DB の名前を変えて作り直す（`RepairHandler.cs:89-92`）。無いか空のときだけにする | サブエージェント | 小 |
| [#6546](https://github.com/duplicati/duplicati/issues/6546) | File バックエンドの get は常にコピー（`FileBackend.cs:469`）。その場で読む、またはハードリンク | サブエージェント | 中 |
| [#4635](https://github.com/duplicati/duplicati/issues/4635) | 復元先のフォルダーを Explorer などで開いていると、フォルダーの時刻が付けられず警告（`Restore/FileProcessor.cs:1173`）。再試行するか、情報に下げる | サブエージェント。警告を下げるかは判断が要る | 小 **11-09 閉じられた（kenkendk）** |
| [#2504](https://github.com/duplicati/duplicati/issues/2504) | S3 の AssumeRole（STS）。MinIO の STS で試せる | サブエージェント | 中（要望） |
| [#4786](https://github.com/duplicati/duplicati/issues/4786)・[#4808](https://github.com/duplicati/duplicati/issues/4808) | スタートアップのショートカットを全ユーザーでなくユーザーごとに、file:// の同時アップロードの既定値を 1 に | 既定値を変えるので判断が要る | 小〜中 |

## 直っていそうなもの（手元で確かめたら、根拠つきのコメントの候補）

| Issue | 直したもの | 手元での確かめ方 |
|---|---|---|
| [#3375](https://github.com/duplicati/duplicati/issues/3375) repair が終わらない | `d22ce5370`（repair の書き直し） | dblock を 1 つ消して repair が終わること |
| [#5546](https://github.com/duplicati/duplicati/issues/5546) SFTP で IPv6 が使われる | SSH.NET 2026.0.0（推測: `DnsEndPoint` で全アドレスを試す） | Docker の sshd を `127.0.0.1:2222` だけで公開し `ssh://localhost:2222` |
| [#4407](https://github.com/duplicati/duplicati/issues/4407) ロケールなしで UI が動かない | Kestrel への置き換え、`LanguageService` がカルチャのエラーを捕まえる | WSL で `env -i` のサーバーに API を呼ぶ **11-09 閉じられた（kenkendk）** |
| [#3979](https://github.com/duplicati/duplicati/issues/3979) S3 のリージョン | `0b79785f0`（`--s3-authentication-region`） | MinIO（chainguard）をリージョン `fr-par` にして |
| [#2631](https://github.com/duplicati/duplicati/issues/2631) 設定の読み込みで止まる | 読み込みが Kestrel の JSON 本文に（`Backups.cs:38`） | WSL で `/tmp/HttpServer` を root の持ち物にして読み込み |
| [#2931](https://github.com/duplicati/duplicati/issues/2931) UsageReport が遅い | #7340（canary のみ） | 合成の DB で master と `v2.4.0.101` を比べる |
| [#2602](https://github.com/duplicati/duplicati/issues/2602) database or disk is full | `58a95e03e`（VACUUM が既定で無効） | 既定のオプションで VACUUM が走らないことをログで |
| [#4645](https://github.com/duplicati/duplicati/issues/4645)・[#3194](https://github.com/duplicati/duplicati/issues/3194) 整合性の確認の問い合わせが遅い | 索引（#4706）、`9b9cfb623`、`432c0423c` | 合成の大きい DB で本番の pragma で測る **11-09 #4645・#3194 とも閉じられた（kenkendk）** |
| [#6198](https://github.com/duplicati/duplicati/issues/6198)・[#5868](https://github.com/duplicati/duplicati/issues/5868) | 質問で回答済み | 試さずに「回答済み」で閉じる依頼ができる |

## ほか

- 返事待ち（以前にコメント済み）: #3190・#4045・#4103・#4636・#2298・#2604・#3020
- 要望で大きいもの（実装候補にしない）: #4710（Google Drive API v3）・#5086（Proton Drive）・#3362（Prometheus）・#4783（IDrive）・#6182（Linux のリポジトリ）
- 外部の要因・古い: #1884・#2149（Google のスコープ）、#5559（HDD の故障）、#5908（.NET の TLS の再開、FluentFTP#951）、#3197・#4481・#4056 など Mono 時代のもの

## 投稿したコメント（2026-11-08、利用者の承認「3件とも投稿」、読み戻して本文の一致を確認）

- [#3375](https://github.com/duplicati/duplicati/issues/3375#issuecomment-6719580411): #6237（`d22ce5370ec95d11c86454c702efb4aa772faf96`、2.1.0.118 canary から）で repair を書き直し、`bs.Done` の列挙はなくなった（`LocalRepairDatabase.cs:590-628` は 1 回読むだけ）。master `e0718870` で `RepairWithMissingRemoteFiles` 29 件緑（`rebuild_missing_dblock_files`、dblock・dindex を消して repair）。報告の 500GB 規模は試していないと明記
- [#6198](https://github.com/duplicati/duplicati/issues/6198#issuecomment-6719580647): 質問、kenkendk が説明し報告者が納得（2025-04-27）。回答済みとして閉じる依頼
- [#5868](https://github.com/duplicati/duplicati/issues/5868#issuecomment-6719580885): 質問、kenkendk が `duplicati-cli` の場所と `cli.pkg` を回答、2025-01 以降なし。回答済みとして閉じる依頼
- 外したもの: #2602（ディスクや一時フォルダーの空き不足でも起きる、直った根拠なし）。残りの #5546・#4407・#3979・#2631・#4645・#3194 は Docker・WSL・大きな DB で確かめる必要があり未着手
- [#4635](https://github.com/duplicati/duplicati/issues/4635#issuecomment-6720752822)（2026-11-08、利用者の選択「#4635 を再試行で」で調べたら再現せず、実装はやめた。利用者の承認「投稿する」、読み戻して末尾の改行以外一致）: 別プロセスが作業フォルダーにしているフォルダーの時刻の設定は、Windows PowerShell 5.1（.NET Framework 4.0.30319）で「being used by another process」、pwsh 7.6.9（.NET 10.0.14）で成功。.NET 10 では FileSystemWatcher・共有 RWD/RW/R/なしで開いたハンドルでも成功（scratchpad `dirlock/probe.cs`）。master `e0718870` の CLI で、復元先とサブフォルダーを cmd 2 つと FileSystemWatcher で開いたまま `restore --overwrite=true` → 警告なし、exit 0、両フォルダーの時刻が戻った（`dirlock/e2e.ps1`）。原因は旧ランタイム、閉じる依頼。ts678 の「復元先そのものに時刻を付けるのは変」は別の論点で触れていない
- 2026-11-08 の判断（利用者が選択肢と長所短所を見て決めた）: #6546 ハードリンク・#1530 Windows も・#7702 時刻つきの書き込み・#4786 選択肢を足す（実装は `PENDING-BRANCHES.md` の 123〜126）。[#6863](https://github.com/duplicati/duplicati/issues/6863) は「何もしない」（返信済みの「フォルダーごと選ぶ」で回避、親フォルダーも記録すると復元の一覧・件数・フィルターが変わり範囲が広い）
- 2026-11-08 の確かめ（利用者の指示「次の作業」、以前の許可「Docker・WSL で確かめてもよい」）。**利用者の承認「2 件とも投稿」で投稿済み**（[#5546](https://github.com/duplicati/duplicati/issues/5546#issuecomment-6722295399)・[#4407](https://github.com/duplicati/duplicati/issues/4407#issuecomment-6722295944)、読み戻して末尾の改行以外一致、本文は `probes/close-check-2026-11-08/comment-*.md`）:
  - [#5546](https://github.com/duplicati/duplicati/issues/5546) SFTP で IPv6 が使われる: **再現と修正の版まで検証済み**。Docker の `lscr.io/linuxserver/openssh-server` を `127.0.0.1:22225` だけに公開、Windows の `localhost` は `::1`→`127.0.0.1` の順、`::1` への TCP は拒否。`probes/close-check-2026-11-08/ssh5546-probe.cs` を SSH.NET 版ごとに: 2023.0.1（2.0.8.1〜2.1.0.2 の版）は `localhost` で「拒否」、`127.0.0.1` なら成功。2024.2.0・2025.1.0・2026.0.0 は `localhost` で成功。master の `Duplicati.CommandLine.BackendTool.exe list ssh://localhost:22225/...` も一覧できた。各タグの csproj/packages.config で SSH.NET が 2024.2.0 になったのは 2.1.0.3 beta・2.1.0.4 stable から
  - [#4407](https://github.com/duplicati/duplicati/issues/4407) ロケールなしで REST API が空: **今の版で再現しないのは検証済み、古い版でも再現できず（原因の版は不明）**。公式イメージ `duplicati/duplicati:latest`（2.4.1.0、`LANG`・`LC_ALL` 空、`LC_CTYPE="POSIX"`）で `Accept-Language` en-GB・en-US・fr-FR・ja-JP・de-CH のどれでも serverstate・backups・systeminfo・serversettings・notifications が 200 の正しい JSON、バックアップを足しても en-GB で一覧に出る、UI も 200。`2.0.5.1_beta_2020-01-18` のイメージでも、ブラウザ風の `en-GB,en-US;q=0.9,en;q=0.8` でも空にならず、報告の Raspberry Pi の環境は再現できていない。下書きにはそのことを書いた
  - Docker のイメージ（`duplicati/duplicati:latest`・`:2.0.5.1_beta_2020-01-18`・`linuxserver/openssh-server`）は残してある。コンテナは消した
- 2026-11-08 の確かめの続き（利用者の指示「残りの作業」）。**利用者の承認「2 件とも投稿」で投稿済み**（[#3979](https://github.com/duplicati/duplicati/issues/3979#issuecomment-6722450618)・[#2631](https://github.com/duplicati/duplicati/issues/2631#issuecomment-6722451205)、読み戻して末尾の改行以外一致、`probes/close-check-2026-11-08/comment-3979.md`・`comment-2631.md`）:
  - [#3979](https://github.com/duplicati/duplicati/issues/3979) S3 の独自リージョンが無視される: **再現と直った版まで検証済み**。`cgr.dev/chainguard/minio`（`MINIO_REGION=fr-par`）に BackendTool の LIST、AWS クライアントで `s3-location-constraint=fr-par`: 2.0.5.1 と 2.2.0.3 stable は "the region is wrong; expecting 'fr-par'"、2.3.0.0 stable・2.4.1.0・master は一覧できる（公式イメージの `duplicati-backend-tool`）。リージョンなしは今も同じエラー（サーバーが fr-par を要求するので正しい）。直したのは `0b79785f0703f1194308e6cef08bbd3e40ff032c`（kenkendk、2026-01-06、`S3AwsClient.cs:121-125` で location-constraint を署名のリージョンに）、タグの中身で 2.2.1.0 beta・2.3.0.0 stable から
  - [#2631](https://github.com/duplicati/duplicati/issues/2631) 設定のインポートが止まる: **今の版で止まらないのは検証済み、古い版の再現は失敗**。ts678 の見つけた原因（旧 HttpServer が `/tmp/HttpServer` に書く、root の持ち物 755 だと失敗）の条件で、2.4.1.0 の公式イメージを `setpriv --reuid=1000` で起動: 暗号化なし・ありの export を、直接と編集用でそれぞれ import して 4 件とも 1 秒以内に 200、直接の 2 件は一覧に増えた。今の import は JSON の base64 を `TempFile` に書く（`Backups.cs:38-43`）。2.0.5.1 は `chroot --userspec=1000:1000` で起動したが、私の multipart は書き込めるフォルダーでも "No file uploaded" で、旧 UI の送り方と合っていなかった（赤は見ていない）。下書きにもそう書いた
  - [#3194](https://github.com/duplicati/duplicati/issues/3194)・[#4645](https://github.com/duplicati/duplicati/issues/4645) 遅い問い合わせ: #3194 の BlocklistHash の結合は今も `LocalDatabase.GetBlocklistsAsync`（`LocalDatabase.cs:3153`、index ファイルの作成で backup・compact・repair から）として同じ形で残っているので「無くなった」とは言えない。速くなったと言うには大きな合成 DB での計測（本番の pragma、[[sqlite-measure-with-production-pragmas]]）が要る。未着手
- 2026-11-08〜09 の計測（利用者の指示「計測に進む」）。**2026-11-09 に利用者の承認（「2 件とも投稿」）で投稿済み**: [#4645](https://github.com/duplicati/duplicati/issues/4645#issuecomment-6727824020)・[#3194](https://github.com/duplicati/duplicati/issues/3194#issuecomment-6727824318)。読み戻して下書きと一致を確認（`probes/close-check-2026-11-08/comment-3194.md`・`comment-4645.md`、手順は `probes/close-check-2026-11-08/q4645/`）:
  - [#3194](https://github.com/duplicati/duplicati/issues/3194)（2.0.3.6 で backup が遅い）: **コードと履歴で検証、計測は不要と判断**。kenkendk の `30814472719c9e19c4552466f3b7a93664cef82a`（2018-04-30「on-the-fly index builder to avoid querying the database for each volume」）で、backup は index をメモリ上で組む（今の `DataBlockProcessor.cs:127,143` の `indexvolume.AddBlock`／`CreateVolumeAsync`）。タグの中身で 2.0.3.6 は無し、2.0.3.7 canary（2018-06-17）から有り。master の CLI で 18MB・`--dblock-size=2mb` の backup は dblock 19・dindex 19。DB の問い合わせ（今の `GetBlocklistsAsync`）は compact・repair・index の作り直しだけ。**ログで「問い合わせが走らない」は示せなかった**: reader の問い合わせは profiling ログに SQL が出ない（repair の陽性対照でも 0 件）ので、その根拠は使っていない
  - [#4645](https://github.com/duplicati/duplicati/issues/4645)（2.0.6.1 で整合性の確認が終わらない）: **古い版で止まる状態を再現、今の版は終わるのを検証**。公式イメージで 100,000 個の 100 バイトのファイル、backup 3 回。普通の統計では 2.0.6.1 も確認は 0.5 秒未満（2.4.1.0 は 1.6 秒、DB 2.0.6.1 88MB／2.4.1.0 61MB）で、合成データでは報告の遅さは出ない。2 回目の後に `sqlite_stat1` の数を全部 1 にする（#7127 の原因と同じ形、`q4645/stalestats.cs`）と、2.0.6.1 の 3 回目は 15 分の上限で終わらず（2 回再現、最後に始まった問い合わせは確認の最初の `SELECT "CalcLen", "Length", "A"."BlocksetID", "File"."Path" ...`、報告のログにも出ている）、2.4.1.0 は同じ条件で 57.6 秒、確認 1.24 秒。2.4.0.0 から backup の開始時に統計を作り直す（`9b9cfb623`、タグの中身で 2.4.0.0 から）。2.4.1.0 が速いのがこの作り直しのおかげか、問い合わせの書き換えのおかげかは切り分けていない。報告の DB が古い統計だったかは不明（推測）で、下書きにもそう書いた
  - 注意: PowerShell のパイプで sh にスクリプトを流すと 1 回目は構文エラーで準備が走らず無効だった。`docker cp` で入れて `sh /tmp/x.sh` にした

## 2026-11-09 の調査（利用者の指示「追加の PR はマージ後に。先に古い Issue・forum の調査と潜在バグ、直っているのに返信していないものは投稿」）

返信の候補を洗い出した方法: マージ済みの自分の PR 362 本の本文から、Fixes・Refs・Related・Part of などで触れた番号を集め（111 個）、GraphQL で開いている Issue に絞った。残ったのは #6461（SQLite の層が残る、返信は早い）と #3733 の 2 件だけ。これに 11-07 の候補で残っていた #2931 と、triage の報告で「維持」のまま深掘りしていなかった #2074 を足した。**2026-11-09 に利用者の承認（「3 件とも投稿」）で投稿済み**: [#3733](https://github.com/duplicati/duplicati/issues/3733#issuecomment-6730038923)・[#2931](https://github.com/duplicati/duplicati/issues/2931#issuecomment-6730039233)・[#2074](https://github.com/duplicati/duplicati/issues/2074#issuecomment-6730039504)。読み戻して下書きと一致を確認（`probes/close-check-2026-11-09/comment-*.md`）。

- [#3733](https://github.com/duplicati/duplicati/issues/3733)（大きなファイルの restore で断片化と余計な IO）: **古い版の飛び飛びの書き込みと、今の版の順の書き込みを検証済み**。restore の書き直し（`76240550`、#5728、2.1.0.3 beta から既定）で `FileProcessor.cs:533-580` がブロックをファイルの順に追記する。公式イメージで 300MB の乱数ファイル、100KB ブロック、5MB の dblock（61 個）、元を消して restore（`probes/close-check-2026-11-09/q3733/order.sh`）。2.0.6.1 は書き込み位置が 93.8→275.2→59.6MB と行き来し最大 14.1MB の穴、2.2.0.3・2.4.1.0 は大きさが 340 回以上に分けて増え穴は 0。3 版とも復元のハッシュは一致。.NET は pwrite なので fd の位置は動かず、大きさと割り当て（`stat %s %b`）で見た。NTFS の断片化と書き込み量は測っていない。`--restore-preallocate-size` が効くのは 2.4.0.0 stable から（#7064、タグの中身で確認）
- [#2931](https://github.com/duplicati/duplicati/issues/2931)（UsageReport が何時間も）: **#7340 の前後で compact の時間を計測**。kenkendk の #7340（`76f63480`）は 2.4.1.0 stable に入っている（タグの中身で `BlocksetTime-` を確認）。公式イメージで 20,000 個の 20KB のファイル、1KB ブロック、40 版（DB 196MB、`q2931/usage.sh`）: compact 1 回目（小さい dblock の統合を含む）2.3.0.0 が 145.2 秒・2.4.1.0 が 71.6 秒、2 回目（ほぼ集計だけ）21.9 秒・5.6 秒。集計の問い合わせだけの時間はログの取り出しが複数行の SQL で失敗して取れていない（下書きにそう書いた）
- [#2074](https://github.com/duplicati/duplicati/issues/2074)（restore で not associated blocks、後半は一時ファイルの除外で PDF が入らない）: 元のエラーは ts678 が 2.0.1.23 の `490776ed` と見立て（未検証）。後半は **属性による除外で設計どおりと検証済み**: ngax の「一時ファイルを除外」は `--exclude-files-attributes=temporary`（`EditBackupController.js:228-244`）。master の CLI（Windows 11）で `!Houses` に普通の PDF と Temporary 属性の PDF、`attrib`・`dir /a` には属性が出ない。除外ありは普通の方だけ、なしは両方がバックアップに入る

ほかに確かめたこと（投稿なし）:
- フォーラムは 22902（11-07 のリリースのお知らせ）まで全部 triage で扱い済み。22855（UI に現地の言語が混ざる）は ngclient の手元のチェックアウトで `X-Ui-Language` を常に送るように直っている（en-US のテストあり）
- forum 22861（B2 の sync で Bucket Name Already in Use）: `B2.cs:257-280` は `b2_list_buckets` に accountId だけを渡す。v2 以降はバケット限定キーでこれが拒否されるが、Duplicati は v1 で、v1 は限定キーのバケットだけを返す（ドキュメント根拠、Backblaze の b2_list_buckets）。今は不具合ではない。v2 に移るときに要注意。22861 自体は情報不足のまま
- canary のスレッド 22860・22834（DST でスケジュールが 1 時間ずれる）: kenkendk が #7681（timezone 未設定のとき UTC になっていた）と #7688（除外した曜日の飛ばしが DST を見ない）で修正、2.4.1.101 に入っている。時間単位の間隔（`2h` など）は `Timeparser.cs:209-217` で UTC の経過時間として足すので、DST をまたぐと現地時刻の時が 1 つずれる（amloessb の「奇数時が偶数時に」）。不具合というより設計の選択なので実装候補にしない
- 開いている Issue 535 件のうち triage に一度も出てこないのは #72（要望）だけ

## 2026-11-09 の調査の続き（利用者の指示「ほかに Issue や forum で検証や調査を進められるものを」）

- forum の新しい話題は 22902 以降なし。11-07 以降に書き込みのあった古い話題: 21698（7z、上の 138 で文言を直した、フォーラムへの返信はリリース後）、21847（2.2.0.3 で設定が消えた、新しい書き込みは SQLite 編集ツールの宣伝のような投稿、本人は作り直しで終了）、22704（利用者が 2.4.1.0 で解決と確認）、22845（同じ人の一般的な助言）
- 返事 0 件の Issue: [#7672](https://github.com/duplicati/duplicati/issues/7672)（Synology DSM 7.3.2 で `authenticate.cgi` が duplicati ユーザーだと終了コード 5、root なら成功）は DSM がないと確かめられない。#7740 は 137、#7665・#7264 は実装済みのブランチ、#7517 は OAuth のサーバー側、#7270 は要望
- 開いている Issue をもう一度 triage と突き合わせたら、載っていないのは #72（要望）だけ。11-07 の実装候補・直っていそうなものは全部済み（ブランチ、投稿、外したもの）。10-31 の enhancement の仕分けで GENERAL・PARTIAL の小さいものから、不具合に近い #3711 を 139 で直した。残りの小さい要望（#4025 の send-http のヘッダー、#4317 の smart retention の部分バックアップ、#4950 の自動の DB コピーの削除、#3114 の recreate 後の版の数など）は未着手

## 閉じられたもの（2026-11-09 に確認、利用者の指示「コメントした Issue の一部が close、triage の更新」）

GraphQL の ClosedEvent で確認。どれも kenkendk が 2026-11-09 に COMPLETED で閉じた:

| Issue | こちらのコメント | 閉じたときの kenkendk の一言 |
|---|---|---|
| [#4635](https://github.com/duplicati/duplicati/issues/4635) 復元先のフォルダーの時刻の警告 | 11-08（.NET 10 では再現しない） | 長く報告がないので直ったとみなす |
| [#4407](https://github.com/duplicati/duplicati/issues/4407) ロケールなしで UI が動かない | 11-08（2.4.1.0 で再現しない） | 旧 HTTP サーバーの不安定さが原因で、Kestrel になったので直った |
| [#4645](https://github.com/duplicati/duplicati/issues/4645) 問い合わせで止まる | 11-08（索引・統計で速くなった） | 統計の更新で直ったはず |
| [#3194](https://github.com/duplicati/duplicati/issues/3194) 遅い問い合わせ | 11-08（同上） | 2023 年から報告がないので閉じる |

PR のマージで閉じたもの: [#7737](https://github.com/duplicati/duplicati/issues/7737)（[#7738](https://github.com/duplicati/duplicati/pull/7738)）、[#7474](https://github.com/duplicati/duplicati/issues/7474)（[#7733](https://github.com/duplicati/duplicati/pull/7733)）。

コメントしてまだ開いているもの: #3733・#2931・#2074（11-09 に投稿）、#5546・#3979・#2631（11-08）、#3375（11-07）。
