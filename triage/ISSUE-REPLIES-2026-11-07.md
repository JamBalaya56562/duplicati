# 返信のない Issue への回答案（2026-11-07）

利用者の方針（2026-11-07）: PR を出すだけでなく、Issue に回答して関わる。まだ誰も返信していない Issue を新しい順に見る。
メンテナーが返信済みのものは後回し。**投稿は利用者の承認後**。投稿したら下の「投稿済み」に URL を書く。

対象: open で comments が 0 の Issue 107 件のうち、2026 年に外部の人（author_association が NONE）が出した 14 件。
master は `ee97a94a7e72`、stable は `v2.4.1.0_stable_2026-10-29`（`release/stable-2.4.1.0`、master から 2026-07-20 に分岐）、
canary は `v2.4.1.100_canary_2026-10-31`。

## 判定

| Issue | 判定 | 根拠 | 案 |
|---|---|---|---|
| #7674 SMB の UNC パスの復元先が不正 | **master と canary で解決済み、stable は未修正** | 検証済み: Windows で `\\127.0.0.1\c$\...` をバックアップし、`--dont-compress-restore-paths` で別フォルダーへ復元。master は `<復元先>\127.0.0.1\c$\...` に復元。`LocalRestoreDatabase.cs` の UNC の `SUBSTR("Path", 3)` を stable の `2` に戻すと `Failed to create folder: <復元先>\\127.0.0.1\...`（報告と同じ二重の `\`）。修正は `bb4ebca54`（#7274）、canary の祖先で stable の祖先ではない | 投稿可 |
| #7666 #7273 が stable に入っていない | **報告どおり（確認）** | 検証済み: `c2717e73d`（#7273）は stable の祖先でない・canary の祖先、`Issue7271Tests.cs` は stable のタグにない。#7674 の修正も同じく stable にない | 投稿可（cherry-pick の PR を出すかは利用者の判断） |
| #7470 ずっと検証を繰り返す | 情報不足 | 検証済み: 貼られたログの `Server has started and is listening` は Duplicati の Server・WebserverCore・Executables のソースに無い（コンテナのスクリプトの出力と推測）。ジョブのログが無い | 投稿可（情報を頼む） |
| #6863 親フォルダーの所有者が戻らない | 現状の仕様（親のメタデータを持っていない） | 検証済み（Windows）: ファイル 1 つだけをソースにしたバックアップの `find` は、そのファイルしか出ない（親フォルダーの項目なし）。所有者の復元そのものは試していない（Linux が要る） | 投稿可 |
| #7024 メールを HTML で送る | 未対応（確認） | コード根拠: `SendMail.cs:293` は常に `new TextPart("plain")` | 投稿可（実装するかは利用者の判断） |
| #7105 停止・中断が効かない | 情報不足、関連の修正は stable に未収録 | 検証済み: #7325 のマージ（`fa55d270c`）は canary の祖先で stable の祖先でない。まとめ役の #6461 は OPEN | 投稿可（canary で試してほしい、情報を頼む） |
| #7665 pCloud の最終の一覧に dlist が無い | 報告どおり（確認）、改善の候補 | コード根拠: 最終の検証（`FilelistProcessor.VerifyRemoteListAsync`）は 1 回だけ一覧して、欠けていれば `MissingRemoteFiles` を投げる。再試行なし | 投稿は実装方針を決めてから（再試行を実装するなら PR で話す） |
| #7123 知らない引数でも CLI が動き続ける | 今は意図した動作 | コード根拠: `Controller.cs:1495-1500` で `UnsupportedOption` の警告を出して続ける | 投稿可（厳格モードを実装するかは利用者の判断） |
| #7270 ベアメタル復元用のブートメディア | 無い | コード根拠: ブートメディアを作る機能はない。`proprietary/DiskImage`（`diskimage://`、Duplicati Inc. のプロプライエタリなライセンス）があり、#7710（ディスクをイメージに復元、OPEN）が進行中。提供の仕方はメンテナーの領分 | 要相談（製品の話に触れるため） |
| #7672 Synology で authenticate.cgi が duplicati ユーザーで失敗 | 報告の分析はコードと一致 | コード根拠: `conf/privilege` は `run-as: package`（ユーザー `duplicati`）、`SynologyAuthMiddleware` は `authenticate.cgi` を子プロセスで呼び、終了コードが 0 以外なら 401。DSM が無いので試せない | 保留（直し方が DSM 依存） |
| #7517 Jottacloud: Session doesn't have required client | 情報不足 | フォーラム 18228（2024-06、rclone 経由で同じエラー）は、古い設定ファイルを新しいトークンで作り直して解決。報告者は接続テストは通り、restore で失敗 | 保留（何を聞くか要検討） |
| #7474 Drime: unique active IDs | 未解決（master も同じコード） | 検証済み: 報告者の 2.4.0.104 には #7318 などの Drime の修正が全部入っている。添付のログは下の「#7474 の添付ログ」。原因はアップロード中の一覧と並列アップロードの競合と推定（コード根拠） | 回答案あり（下） |
| #7265 macOS Photos で OOM | 未検証 | コード根拠（triage の 10-31 の候補 7）: `DuplicatiPhotos.m` の列挙ループにアセットごとの `@autoreleasepool` がない。Mac が無いので試せない | 保留（実装候補） |
| #7264 1 回のアップロード量の上限 | 要望、その種のオプションは無い | コード根拠: `Options.cs` に該当のオプションなし | 保留（機能の話） |

## 回答案（英語）

### #7674

```
I could reproduce this on Windows. It is fixed on master and in the canary builds, but not in a stable release yet.

When the restored files have no common folder, as with a UNC source and `--dont-compress-restore-paths`, the restore maps `\\server\share\...` to `<restore folder>\server\share\...`. The stable release removes only one of the two leading backslashes, so the target becomes `C:\Restore\\data1\...` as in your log. [`bb4ebca54421`](https://github.com/duplicati/duplicati/commit/bb4ebca544213c1d9fd750a1a68a5971aa25d9f5) (#7274) changed it to remove both.

I backed up `\\127.0.0.1\c$\...` and restored it to another folder:

- master [`ee97a94a7e72`](https://github.com/duplicati/duplicati/commit/ee97a94a7e721a988729fcfad1cae67204c0454a): restored to `<restore folder>\127.0.0.1\c$\...`
- the same build with the old line put back: `Failed to create folder: <restore folder>\\127.0.0.1\c$\...`

The fix is in `v2.4.1.100_canary_2026-10-31`, but not in `v2.4.1.0_stable_2026-10-29`. I did not run the canary build itself.
```

### #7666

```
I checked the tags, and I see the same:

- [`c2717e73dc98`](https://github.com/duplicati/duplicati/commit/c2717e73dc98e079242abe259864a379c888a9b2) (the merge of #7273) is in `v2.4.1.100_canary_2026-10-31`, but not in `v2.4.1.0_stable_2026-10-29`.
- `Duplicati/UnitTest/Issue7271Tests.cs` is not in the stable tag.
- `release/stable-2.4.1.0` was branched from master on 2026-07-20.

The UNC restore fix #7274 (#7674) is also missing from the stable branch for the same reason.
```

### #7470

```
The log you posted does not show what Duplicati is doing. As far as I can see, "Server has started and is listening on *, port 8200" is not printed by Duplicati itself. It probably comes from the container's startup script, and the repeated lines suggest that the container is restarting.

Could you add:

- the log of one run of the job (the job's "Show log" page, or About > Show log > Live at Verbose while it runs),
- whether the container restarts (`docker ps` shows how long it has been up), and
- the size of the source and of the local database.
```

### #6863

```
This matches what the backup records. When only `~/path/file` is selected, the backup contains the file but no entry for `~/path`. On a test backup of a single file, `find` lists only the file. So there is no owner or permission for the folder to restore, and the folder is created like any new folder.

Selecting the folder itself (`~/path/`), with a filter if you want only some of its files, should put the folder into the backup. I tested the listing on Windows only, and did not test the owner on Linux.
```

### #7024

```
Not at the moment. The mail report is always sent as plain text: `SendMail.cs` creates the body as `text/plain`, so HTML in `--send-mail-body` is shown as code.

Supporting it would need an option, for example to send the body as HTML. That is not decided yet.
```

### #7105

```
Several fixes for jobs that do not stop are newer than 2.3.0.4. For example, #7325 stops waiting for a backend call that ignores the abort. It is in `v2.4.1.100_canary_2026-10-31`, but not in the `v2.4.1.0` stable release. The general issue is tracked in #6461.

If you can, please try the latest canary. If it still happens, it would help to know what the job shows when it is stuck (the phase in the status bar), and to see About > Show log > Live at Verbose at that time.
```

### #7123

```
This is intended at the moment. An option that Duplicati does not know gives the warning, and the operation goes on (`Controller.cs`). That way, saved jobs and options of modules that are not loaded do not stop working.

A stricter mode would have to be opt-in for the same reason.
```

## 投稿済み

- 2026-11-07 #7674（master と canary で解決済み、stable は未修正）: https://github.com/duplicati/duplicati/issues/7674#issuecomment-6704824900
- 2026-11-07 #7666（報告どおりと確認）: https://github.com/duplicati/duplicati/issues/7666#issuecomment-6704826104
- 2026-11-07 #7470（情報を頼んだ）: https://github.com/duplicati/duplicati/issues/7470#issuecomment-6704826913

1 回目の 3 件は投稿後に API で読み戻し、下書きと同じ本文であることを確認した（違いは末尾の空行だけ）。

- 2026-11-07 #6863（今の仕様、フォルダーごと選ぶよう案内）: https://github.com/duplicati/duplicati/issues/6863#issuecomment-6705484210
- 2026-11-07 #7024（未対応）: https://github.com/duplicati/duplicati/issues/7024#issuecomment-6705484508
- 2026-11-07 #7105（canary で試してほしい、情報を頼んだ）: https://github.com/duplicati/duplicati/issues/7105#issuecomment-6705484805
- 2026-11-07 #7123（今は意図した動作）: https://github.com/duplicati/duplicati/issues/7123#issuecomment-6705485098

2 回目の 4 件も投稿後に API で読み戻し、下書きと同じ本文であることを確認した（空行を除いて一致）。返信案のある 7 件はすべて投稿済み。残りは保留の 7 件（#7474・#7665・#7270・#7672・#7517・#7265・#7264）。

## #7474 の添付ログ（2026-11-07、利用者の許可で取得）

`full_log.json`（7,610 バイト）。2.4.0.104 で、バックアップは 13:00:50Z に始まり、約 2 時間後（16:59:08 +02）に失敗。それまでに 9,286 ファイル・約 240 GB を上げ、`RetryAttempts` は 8。エラーは開始時の一覧ではなく、アップロードの途中に出た（`BackendManagerHandlerFailure` → `Terminating 3 active uploads`）。ログの先頭でも、4 本の Put が始まるとそれぞれがフォルダー 967028978 の一覧を取っている。

コードから考えた仕組み（コード根拠、Drime では未検証）:
- `DrimeBackend.PutAsync`（353-356 行）は、上書きの確認のために `GetFileCacheAsync` を呼ぶ。キャッシュがないインスタンスでは、アップロード先フォルダーの全件の一覧（`ListAsync` → `ListFolderWindowsAsync`）になる。
- アップロードは既定で 4 本並列（`DEFAULT_ASYNCHRONOUS_UPLOAD_LIMIT = 4`）、それぞれ別のバックエンドのインスタンスを使う。失敗した操作のインスタンスは使い回さず捨てる（`BackendManager.Handler.cs:640-645`）ので、再試行のあとは新しいインスタンスが最初の Put でまた全件を一覧する。
- `ListFolderWindowsAsync` はまず件数（`folders/{id}/count`）を取り、ページを読む。読んでいる間にほかの 3 本のアップロードが同じフォルダーにファイルを足すと、見えた件数が最初の件数を超えて `The listing contains more unique active IDs than the separate folder count.`（779 行）で止まる。フォルダーが大きいほど一覧が長くかかるので、バックアップが進むほど起きやすい。
- master の `DrimeBackend.cs` は 2.4.0.104 と同じ（#7318 などの修正は 2.4.0.104 に入っている）。

### 回答案（英語）

```
Thanks for the log. It shows that the backup failed after about two hours and 9,286 uploads, while uploading, not in the listing at the start.

From reading the code, I think this is what happens (master is the same as 2.4.0.104 here):

- Before an upload, the Drime backend lists the whole target folder once per backend instance, to check whether the file already exists (`PutAsync` calls `GetFileCacheAsync`).
- Up to 4 uploads run at once, each with its own backend instance. An instance is dropped after a failed attempt (your log shows 8 retries), and the new one lists the folder again.
- The listing first asks Drime for the number of entries in the folder and then reads the pages. When the other uploads add files to the same folder in the meantime, the listing sees more files than that number and stops with this error. The more files the folder has, the longer the listing takes, so it becomes more likely as the backup grows.

I could not test this against Drime, so it is based on the code only. If it is right, `--asynchronous-upload-limit=1` should avoid it, at the cost of slower uploads. Could you try that and tell us if the backup completes?
```

実装の候補: Put の上書きの確認に、フォルダー全件の厳密な一覧を使わない（その名前だけを探す、または自分のアップロード中は件数の増加を許す）。

### #7474 の修正と投稿（2026-11-07）

**2026-11-09: #7733 のマージで kenkendk が閉じた（COMPLETED）。**

利用者の指示「修正も実装、PR を出してからコメント」で `fix/drime-upload-during-listing`（`505ad7bf`、master `6dee7d94` の直上）を [#7733](https://github.com/duplicati/duplicati/pull/7733)（Fixes #7474）として出した。Put と Delete の名前の確認に使うキャッシュの一覧だけ、読んでいる間にフォルダーが増えるのを許す（`created_at` の昇順なので、件数を読んだ時点のファイルが先に来る）。減った場合と `ListAsync` は今までどおり厳密。新しい `DrimeUploadDuringListingTests`（件数 3 → 一覧 5 件）は master で Put の 2 件が報告と同じ例外で赤、修正で緑。Drime のテスト 16 件が緑（Windows）。Drime の実物では試していない。

返信は上の回答案に #7733 への一文と「修正が入るまでは」を足して投稿: https://github.com/duplicati/duplicati/issues/7474#issuecomment-6706034013（読み戻して一致を確認）
