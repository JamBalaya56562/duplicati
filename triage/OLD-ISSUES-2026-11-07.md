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
| [#4635](https://github.com/duplicati/duplicati/issues/4635) | 復元先のフォルダーを Explorer などで開いていると、フォルダーの時刻が付けられず警告（`Restore/FileProcessor.cs:1173`）。再試行するか、情報に下げる | サブエージェント。警告を下げるかは判断が要る | 小 |
| [#2504](https://github.com/duplicati/duplicati/issues/2504) | S3 の AssumeRole（STS）。MinIO の STS で試せる | サブエージェント | 中（要望） |
| [#4786](https://github.com/duplicati/duplicati/issues/4786)・[#4808](https://github.com/duplicati/duplicati/issues/4808) | スタートアップのショートカットを全ユーザーでなくユーザーごとに、file:// の同時アップロードの既定値を 1 に | 既定値を変えるので判断が要る | 小〜中 |

## 直っていそうなもの（手元で確かめたら、根拠つきのコメントの候補）

| Issue | 直したもの | 手元での確かめ方 |
|---|---|---|
| [#3375](https://github.com/duplicati/duplicati/issues/3375) repair が終わらない | `d22ce5370`（repair の書き直し） | dblock を 1 つ消して repair が終わること |
| [#5546](https://github.com/duplicati/duplicati/issues/5546) SFTP で IPv6 が使われる | SSH.NET 2026.0.0（推測: `DnsEndPoint` で全アドレスを試す） | Docker の sshd を `127.0.0.1:2222` だけで公開し `ssh://localhost:2222` |
| [#4407](https://github.com/duplicati/duplicati/issues/4407) ロケールなしで UI が動かない | Kestrel への置き換え、`LanguageService` がカルチャのエラーを捕まえる | WSL で `env -i` のサーバーに API を呼ぶ |
| [#3979](https://github.com/duplicati/duplicati/issues/3979) S3 のリージョン | `0b79785f0`（`--s3-authentication-region`） | MinIO（chainguard）をリージョン `fr-par` にして |
| [#2631](https://github.com/duplicati/duplicati/issues/2631) 設定の読み込みで止まる | 読み込みが Kestrel の JSON 本文に（`Backups.cs:38`） | WSL で `/tmp/HttpServer` を root の持ち物にして読み込み |
| [#2931](https://github.com/duplicati/duplicati/issues/2931) UsageReport が遅い | #7340（canary のみ） | 合成の DB で master と `v2.4.0.101` を比べる |
| [#2602](https://github.com/duplicati/duplicati/issues/2602) database or disk is full | `58a95e03e`（VACUUM が既定で無効） | 既定のオプションで VACUUM が走らないことをログで |
| [#4645](https://github.com/duplicati/duplicati/issues/4645)・[#3194](https://github.com/duplicati/duplicati/issues/3194) 整合性の確認の問い合わせが遅い | 索引（#4706）、`9b9cfb623`、`432c0423c` | 合成の大きい DB で本番の pragma で測る |
| [#6198](https://github.com/duplicati/duplicati/issues/6198)・[#5868](https://github.com/duplicati/duplicati/issues/5868) | 質問で回答済み | 試さずに「回答済み」で閉じる依頼ができる |

## ほか

- 返事待ち（以前にコメント済み）: #3190・#4045・#4103・#4636・#2298・#2604・#3020
- 要望で大きいもの（実装候補にしない）: #4710（Google Drive API v3）・#5086（Proton Drive）・#3362（Prometheus）・#4783（IDrive）・#6182（Linux のリポジトリ）
- 外部の要因・古い: #1884・#2149（Google のスコープ）、#5559（HDD の故障）、#5908（.NET の TLS の再開、FluentFTP#951）、#3197・#4481・#4056 など Mono 時代のもの
