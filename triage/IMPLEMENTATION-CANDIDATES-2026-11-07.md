# 実装候補 2026-11-07（Issue とフォーラムの再調査 5 回目）

利用者の指示: PR はまだ出さず、準備のブランチを増やす。Issue（10-31 以降に作られたもの、triage の残り）とフォーラム（10-30 以降の 11 件）を見た。master は `6dee7d94`。根拠の種類は「コード根拠」「検証済み」「推測」で書く。

## 実装候補（優先順）

| # | 出どころ | 内容 | 根拠 | 規模 |
|---|---|---|---|---|
| 1 | 今日の #7735 の続き | `ListFolderAsync`（`LocalListDatabase.cs:1098`）と `ListFileVersionsAsync`（`:1482`）も、LIMIT のあとの `results.Count <= limit` で総件数を決め、ページ数は `(total + limit - 1) / limit`（`:1515`）。満杯の最初のページで総件数が過少、limit なしで桁あふれ、後続ページの Pages がページサイズ次第になるはず。復元の画面の一覧のページ送りに効く | コード根拠（未検証）。#7735 と同じ形の赤のテストで確かめる | 小 |
| 2 | [#7665](https://github.com/duplicati/duplicati/issues/7665)（pCloud） | 最後の一覧の検証（`FilelistProcessor.VerifyRemoteListAsync`）は 1 回だけで再試行なし。この回で上げたファイルだけが欠けているときに、短い間隔で数回一覧し直す（設定で切れるようにするか、決める） | コード根拠、報告者のログ（4 秒後の一覧には出る） | 中 |
| 3 | [#4507](https://github.com/duplicati/duplicati/issues/4507)（#4586 も同じ） | recreate のあと、存在しない dblock を指す dindex が残り、recreate のたびに警告。repair は消すが compact・purge-broken-files は消さない | 10-30 の probe で仕組みを確認（検証済み、`ProbeOrphanDindex.cs`）、直し方は未定 | 小〜中 |
| 4 | #7733 の続き | Drime でアカウントの直下（ルート）にバックアップすると、一覧は `ListEntriesUsingFilterAsync` を通る。こちらも厳密な検査なので、並列のアップロード中の名前の確認で同じ競合が起きうる | コード根拠（推測） | 小 |
| 5 | [#7123](https://github.com/duplicati/duplicati/issues/7123) | CLI で知らないオプションがあっても続行する。CLI で打ったものだけ止める、またはオプトインの厳格モード | コード根拠（`Controller.cs:1495-1500`）。返信済み。どちらにするかは利用者の判断 | 小 |
| 6 | [#7024](https://github.com/duplicati/duplicati/issues/7024) | メールの本文を HTML で送るオプション（`SendMail.cs:293` は常に text/plain） | コード根拠。返信済み | 小 |
| 7 | [#6863](https://github.com/duplicati/duplicati/issues/6863) | ファイルだけを選ぶと親フォルダーのメタデータが記録されず、復元で作ったフォルダーの所有者が戻らない。親フォルダーのメタデータも記録する | 検証済み（一覧に親が無い）。返信済み。保存形式に触れるので判断が要る | 中〜大 |
| 8 | [#1520](https://github.com/duplicati/duplicati/issues/1520) | `--alternate-destination-marker` が `--alternate-target-paths` なしだと無視される（`FileBackend.cs:130-170`） | コード根拠（enhancement の仕分け） | 小 |
| 9 | [#1940](https://github.com/duplicati/duplicati/issues/1940) | GPG の実行ファイルと引数（パスフレーズを除く）をログに出す（今は DEBUG ビルドだけ、`GPGEncryption.cs:211-215`） | コード根拠（同上） | 小 |
| 10 | [#1443](https://github.com/duplicati/duplicati/issues/1443) | `--log-file` など Duplicati が書いているファイルをバックアップから外す（DB の -journal などは除外済み、`BackupHandler.cs:177-185`） | コード根拠（同上） | 小 |
| 11 | [#7702](https://github.com/duplicati/duplicati/issues/7702)（kenkendk 返信済み） | sync で WebDAV（Nextcloud など）に元の更新時刻を `X-OC-Mtime` で送る | 要望。`IBackend.PutAsync` は時刻を受け取らないので、インターフェースの設計が要る | 中 |
| 12 | [#1925](https://github.com/duplicati/duplicati/issues/1925)・[#1530](https://github.com/duplicati/duplicati/issues/1530) | 更新日時で絞るフィルター、`--one-file-system` | コード根拠（同上） | 中 |

## 準備済みのブランチで残っているもの（続き）

- `fix/smb-timeout-aborts`: 下書きは `fix/smb-list-large-folder`（捨てた）との衝突を前提にしている。master の #7593 と合わせて書き直しと再確認が要る
- `fix/synthetic-filelist-after-interrupted-time`・`fix/synthetic-filelist-keeps-interrupted-files`: 扱いが利用者の判断待ち
- `fix/quiet-expected-auth-and-api-errors`・`fix/destination-test-ignores-test-files`: `ServerApiIntegrationTests.cs` の同じ位置に追記するので、#7727 のマージ後に積み直す
- `fix/sharepoint-slice-upload-timeout`: #7728 の上。`chore/remove-unused-dlist-upload-flag`: #7722 の上
- ngax の 5 本の積み重ね、`ci/check-ngax-css-build`・`docs/server-readme-style-build`、`chore/update-dev-style-tools`、`fix/rename-isblockdevice-to-isspecialfile`

## 候補にしなかったもの

- forum 22871（マルチ宛先で毎回削除と再アップロード）: kenkendk が原因（WebDAV などの時刻のタイムゾーン）を特定し、master の `ee81840e7`「Anchor timestamps for backends」（11-04）で修正
- forum 22865（OneDrive の `#`）: canary 2.4.1.100 で修正済み（kenkendk）
- forum 22873（TrayIcon のクラッシュ）: SQLite 3.54.0 のバグ、#7711 で 3.54.1 に更新済み
- forum 22867（SMB ソースのエラーに原因が出ない）: メッセージに状態コード（`with status ...`）は含まれている（`SMBShareConnection.cs:290`）。UI の表示が途中で切れていた。権限の対応づけは kenkendk がエラーコードを待っている
- forum 22861（B2 への sync で Bucket Name Already in Use）: sync の自動作成（`LightWeightBackendManager.cs:476`）が `b2_create_bucket` を呼んだと考えられるが、接続テストは通っていて、なぜ「フォルダーなし」になったかはエラーの詳細がないと分からない（情報不足）
- forum 22862（B2 の SSL）・22897（接続拒否）・22898（一時停止）: 一時的なもの、または使い方
- [#7664](https://github.com/duplicati/duplicati/issues/7664): kenkendk が「サービスにしたことでデータフォルダーが変わった」可能性を返信済み
- [#7670](https://github.com/duplicati/duplicati/issues/7670): 同梱の .NET ランタイムの更新。リリース作業
