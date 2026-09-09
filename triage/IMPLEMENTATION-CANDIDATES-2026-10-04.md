# 実装候補 2026-10-04（Issue の再調査 2 回目）

open Issue 604 件（10-04 取得）から、triage のどのファイルでも深掘りしていないもの 512 件、うち機能要望のラベルがないもの 300 件を出した。タイトルでバグの報告らしく手元で確かめられそうな 29 件を選び、4 つのサブエージェントで Issue・コメント・master `9a3d38ca` のコードを読んだ。**サブエージェントの見立ては、直したものはすべて自分で赤→緑まで確かめた**。閉じてよさそうなものは見立てのまま（未検証、コメント案を作るときに確かめ直す）。

## 直して push したもの（PENDING の 10-04。10-10 時点の PR とマージは各行）

| Issue | ブランチ | 一文 | 確かめたこと |
|---|---|---|---|
| [#7412](https://github.com/duplicati/duplicati/issues/7412) | `fix/hcv-secret-json-values`（[#7426](https://github.com/duplicati/duplicati/pull/7426)、10-10 マージ、Issue CLOSED） | VaultSharp 1.17.5.1（[`819af9e6`](https://github.com/duplicati/duplicati/commit/819af9e66f8fd3534d863a3cde05531777f09edd)、2.2.1.0 beta・2.3.0.0 stable〜）で値が `JsonElement` になり、`is string` で全部落ちて KeyNotFound | 新規テスト 3 本（ローカルの HttpListener で KV v2 を返す）赤→緑。本物の Vault（Docker `hashicorp/vault:1.17` dev）に `SecretTool test` で 前: KeyNotFound、後: Found! |
| [#7413](https://github.com/duplicati/duplicati/issues/7413) | `fix/jottacloud-parallel-get-collects-all-chunks`（[#7427](https://github.com/duplicati/duplicati/pull/7427)、10-10 マージ、Issue CLOSED） | `ParallelGetAsync` のループ条件 `tasks.Any(t => !t.IsCompleted)` で、書いている間に終わったタスクを回収せずに抜け "Stream position mismatch" | internal ctor で HttpClient を差し込み、最初のチャンクの書き込み中に残りを終わらせるテスト。前 3/3 赤（報告と同じ例外）、後 3/3 緑 |
| [#4818](https://github.com/duplicati/duplicati/issues/4818) | `fix/restore-path-without-value` | `--restore-path D:\x`（`=` なし）は値なしになり、元の場所へ復元して成功扱い | CLI の `RunCommandLine` で: 前 exit 0「Restored 1 … to original location」、後 エラーで止まり何も復元しない。`=` ありは従来どおり |
| [#6748](https://github.com/duplicati/duplicati/issues/6748) | `fix/webdav-path-href-on-linux` | Linux/macOS では `/dav/...` が `Uri.TryCreate(Absolute)` で暗黙のファイル URI になり `AbsolutePath` が `%` を二重にエスケープ → フォルダ名の `#`・空白で名前にフォルダが残る。#6591（2.2.0.1 stable）から | WSL で `Uri` の値を実測。PROPFIND のテスト 5 件: Linux 前 2 赤（報告と同じ `dav/Duplicati/%23Photo/duplicati-…`）→ 後 緑、Windows は前後とも緑。#6683（2.2.0.1 の Linux で一覧が壊れた）も同じ原因かもしれないがフォルダ名不明 |
| [#6706](https://github.com/duplicati/duplicati/issues/6706) | `fix/storj-upload-without-expiry`（[#7428](https://github.com/duplicati/duplicati/pull/7428)、10-10 マージ、Issue CLOSED） | `new UploadOptions()` を uplink.NET が有効期限 9999-12-31 で送り、default retention のバケットは拒否 | uplink.NET の `ToSWIG` を実行して 前 253402300799、後 0。uplink-c `upload.go`（`expires > 0`）と satellite `validateObjectRetentionWithTTL` はソースで確認。本物のバケットでは未確認 |

## 保留（設計の判断が要る）

- **（10-04, 2 に B 案で直して `fix/azure-upload-in-blocks` を push した。[#7429](https://github.com/duplicati/duplicati/pull/7429) として 10-10 にマージ、Issue CLOSED）** [#6629](https://github.com/duplicati/duplicati/issues/6629) Azure の 100 秒: `BlobClientOptions.Retry.NetworkTimeout` が既定の 100 秒で、1 リクエストの PUT 全体を打ち切る（#6632 は `HttpClient.Timeout` とリトライだけ）。ただし無限にすると止まった通信を打ち切るものがなくなる: ダウンロードは `ObserveWriteTimeout` の stream を作っているのに `DownloadToAsync(target)` に渡しておらず（`AzureBlobWrapper.cs:160-161`）、`TimeoutObservingStream` は読み書きの合間のタイマーなので、ネットワークへの書き込みが止まったアップロードは打ち切れない。案: (a) 無限＋ダウンロードに timeoutStream を渡す、(b) `TransferOptions` で 1 リクエストを数 MB に分けて 100 秒の保護を残す。どちらにするかは利用者・メンテナの判断
- [#3605](https://github.com/duplicati/duplicati/issues/3605) run-script-before が失敗するとメールが送られない: `Controller.cs:969-989` で RunScript（Priority 100）の OnStart が投げると、後ろの SendMail などの Configure が呼ばれない。kenkendk の #5245（全部 Configure してから OnStart）は「スクリプトが出したオプションを後続の Configure に反映させたい」で close。方向性を Issue で確認してから
- [#5045](https://github.com/duplicati/duplicati/issues/5045) 一時停止中にキューに積まれたスケジュールのジョブは、スケジュールを消しても再開時に動く: 中規模（キューからの除去 API）で挙動が変わる
- [#3848](https://github.com/duplicati/duplicati/issues/3848) シンボリックリンクが root:root で復元: `--restore-symlink-metadata` なしでは意図どおり。付けたときの chmod がリンク先をたどる疑い。`FileRestoreDestinationProvider.cs` は #7397 と同じファイル
- [#4082](https://github.com/duplicati/duplicati/issues/4082) GUI の Commandline の `test` で FormatException: 主因は UI が引数欄にソースを入れたままにすること。CLI 側（`Commands.cs:927` の `Convert.ToInt64`）を分かりやすいエラーにするのは小さいが効果は限定的
- [#3018](https://github.com/duplicati/duplicati/issues/3018) 古い UI の編集画面を開いたまま保存すると Metadata が古い値に戻る: ngax の 1 行（`delete Backup.Metadata`）。新しい UI は送らないので起きない

## 閉じてよさそうなもの（10-04 に 1 件ずつ動かして確かめ、11 件のコメントを `ISSUE-CLOSE-COMMENTS-2026-10-04.md` に書き、同日に投稿した）

確かめ直して変わった点: **#4599 は外した**（`11a250d9` は 2.4.0.0 stable のコードにない、後半も未対応）。**#4103 は 2.4.0.0 stable に入っている**（`--contains` には出ないが stable のコードに同じ 2 か所）。#2798 は PR で閉じる。**新しく見つけた小さな件**: 読めないフォルダ 1 つで `PermissionDenied` の警告が 2 回出る（#3530 の確認で見つけた）→ **10-04, 4 に原因（進捗用の数え上げの isolating scope が detach されている、警告に限らず列挙のメッセージが全部 2 回）を突き止めて直し、`fix/count-files-log-isolation` を push した**（サブエージェントの「列挙と属性で 2 回」という見込みは外れ）


- [#4792](https://github.com/duplicati/duplicati/issues/4792): #2843 の重複、[`aabfbb8d`](https://github.com/duplicati/duplicati/commit/aabfbb8df656cfaf7533c1f50a2049d49f258091)（2.1.2.0 beta）で大きなレポートを分割エスケープ
- [#3530](https://github.com/duplicati/duplicati/issues/3530): [`1d4642ac`](https://github.com/duplicati/duplicati/commit/1d4642acdf70290c552381782bdfaeb32f20a446)（#6426、2.3.1.0 beta）で列挙の警告が 1 行に
- [#5007](https://github.com/duplicati/duplicati/issues/5007): [`73a2f32b`](https://github.com/duplicati/duplicati/commit/73a2f32b05a77afa56691aaf85a21c0b2ad56369)（2.1.2.0 beta）でパスフレーズなしの recreate を最初に止める
- [#4220](https://github.com/duplicati/duplicati/issues/4220): [`2a79e3e4`](https://github.com/duplicati/duplicati/commit/2a79e3e4c393907ccfb6887672813e608d97b83d)（2.1.0.2 beta）で level が String 型に
- [#2949](https://github.com/duplicati/duplicati/issues/2949): 古い HttpServer.dll を [`9f790257`](https://github.com/duplicati/duplicati/commit/9f7902574473639689fa7cea899b70f97b6b613e)（2.1.0.2 beta）で削除、Kestrel へ
- [#2650](https://github.com/duplicati/duplicati/issues/2650): 仕様どおり（`--dbpath` なしの CLI は `dbconfig.json`）、ドキュメントに記載
- [#4846](https://github.com/duplicati/duplicati/issues/4846): oauth-handler 側（revoke が memcache を消さない）
- [#4468](https://github.com/duplicati/duplicati/issues/4468): 65534（overflowgid）が記録されただけ（165536 + 65533 = 231069）
- [#4103](https://github.com/duplicati/duplicati/issues/4103): [`e8925f78`](https://github.com/duplicati/duplicati/commit/e8925f78a50a950161738babeb3a9aa2a36be97a)（#7157、2.3.0.109 canary〜、beta 未収録）
- [#4599](https://github.com/duplicati/duplicati/issues/4599): [`11a250d9`](https://github.com/duplicati/duplicati/commit/11a250d909d86910b147b4447a5307b9171821bc)（2.3.0.109 canary〜）。次の beta/stable の後
- [#2798](https://github.com/duplicati/duplicati/issues/2798): `fix/restore-missing-folder-not-a-warning`（#5853）で同じ文言の警告が直る。PR に `Fixes #2798` を足す
- [#3038](https://github.com/duplicati/duplicati/issues/3038): 報告の場面は今は記録される。モジュールの OnStart より前の例外はログファイルに残らない穴は #3605 と同じ箇所
- [#2004](https://github.com/duplicati/duplicati/issues/2004): 元のエラーは今の UI では起きない。絵文字のファイル名の件は再報告を依頼

## 判断できないもの・情報待ち

- [#7370](https://github.com/duplicati/duplicati/issues/7370) Drime の重複: #7285（PR #7318、2.4.0.102 canary〜）の重複の見込み。報告者のバージョン待ち
- [#6767](https://github.com/duplicati/duplicati/issues/6767) SMB の書き込みバイト数: #7371（2.4.0.103 canary）で本当のステータスが出るように。再実行のログ待ち
- [#6831](https://github.com/duplicati/duplicati/issues/6831) リモート操作の claim: `IsRegistering` が残る件は ae32ea12（2.3.1.0 beta）で直った。残りはサーバー側
- [#3548](https://github.com/duplicati/duplicati/issues/3548): オプションの経路にデコードはない。原因は S3 の URL の形（バケット名がホスト）
- [#4175](https://github.com/duplicati/duplicati/issues/4175) `usn-policy=required` でも soft failure は全走査で続行: 2018 年からの設計。ヘルプ文との食い違い
