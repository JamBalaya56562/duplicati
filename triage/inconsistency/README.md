# #3085 の「Found inconsistency」が自然に起きる道の調査（2026-10-30）

利用者の指示「1 でお願い致します。出来る限り先ずは色んなパターンを試して調査しましょう」で、今の master（`31bf7aa0`、WSL の `~/dup-master` の CLI、Linux）で、`Blockset.Length` とブロックの合計が食い違う状態に自然に行き着く手順を探した。

- 仕掛けは `harness.py` に置いた。11 種類の壊し方を、それぞれ 20〜25 回流す。
- 1 回ごとに、`LocalDatabase.VerifyConsistencyInnerAsync` と同じ SQL（長さ・BlocklistHash の重複・BlocklistHash の欠け）で DB を確かめた。
- 陽性対照あり: `Length=0` に書き換えた DB を検出し、正常な DB では 0 件だった。

## 結果（検証済み）

| 壊し方 | 回数 | 結果 |
|---|---|---|
| backup を SIGKILL（0.2〜4 秒）→ 次の backup | 25 | 不整合なし |
| backup を SIGINT → 次の backup | 25 | 不整合なし |
| backup 中にファイルを切り詰め・追記・上書き・置き換え | 25 | 不整合なし |
| compact を SIGKILL → compact → backup | 25 | 不整合なし。1 回だけ、次の compact が `UnexpectedUploadingFile`（その次の backup は成功） |
| delete を SIGKILL → backup | 25 | 不整合なし |
| purge を SIGKILL → backup | 25 | 不整合なし |
| 疎ファイル（1〜1000 ブロック、320/321/641 の境界）・同じ中身・空ファイル。その上で、落とした backup・compact・purge のあとに recreate → backup → test all | 21 | 不整合なし（すべて成功） |
| recreate（DB なしの repair）を SIGKILL → repair → backup | 25 | 8 回、DB に「作り直しの途中」の印が残った。repair は `DatabaseIsInRepairState`、backup は「DB を消して repair し直して」と止まる。設計どおり。ただし repair は止まる前に、メタデータのブロックセット（dbsize 196、actual 0）について「purge-broken-files を使え」という警告を数百件出し、案内として誤り |
| 宛先の dblock・dindex・dlist の削除、dblock の切り詰め・破損 → repair → purge-broken-files → repair → test → backup | 25 | **it11 から不整合**（下の本命） |
| 宛先の dblock か dindex を消す → repair を SIGKILL → repair → purge-broken-files → backup | 25 | **it3 から不整合**（下の本命） |
| 宛先を読み取り専用にする・消す（backup の途中） | — | 仕掛けの不具合（OSError 39）で走らず、**未確認** |

## 本命: purge-broken-files がタイムスタンプの衝突で途中失敗し、DB を壊す

最小の手順は `repro.py`（決定的、今の master で毎回再現、検証済み）。

```
backup（版 A, 11:21:12）→ すぐに backup（版 B, 11:21:14）
purge --version=1 */dummy0.bin → 版 A が 11:21:13 にずれる（成功）
purge --version=1 */dummy1.bin → rc=100「Unable to create a new fileset ... resulting timestamp 11:21:15 is larger than the next timestamp 11:21:14」（DB は無傷）
宛先の dblock を 1 つ消す
purge-broken-files → rc=100 同じタイムスタンプのエラー
backup             → rc=100 Found inconsistency in the following files while validating database
repair             → rc=100 Found inconsistency（直らない）
purge-broken-files → rc=100 同じエラー（抜け道なし）
```

### 仕組み（コードを読んだ範囲、推測を含む）

1. `ListBrokenFilesHandler.GetBrokenFilesetsFromRemoteAsync`（`ListBrokenFilesHandler.cs:91-100`）が、消えた dblock を `Deleting` にする。続いて `RemoveMissingBlocksAsync` でそのブロックを DB から消す。
2. `PurgeBrokenFilesHandler`（`:175`）は、各版を書き直す前に `db.Transaction.CommitAsync` で 1 を確定する。
3. 各版の書き直し（`PurgeFilesHandler.cs:134-140`）は、新しい dlist の時刻を `ProbeUnusedFilenameNameAsync` で元の時刻より後ろに探す。それが次の版の時刻以上なら `Exception` を投げる。
4. 3 で止まると、まだ書き直していない版の壊れたファイルが、ブロックを失ったまま残る。これが `Length` > ブロックの合計になり、どの操作も `VerifyConsistency` で止まる。purge-broken-files を何度流しても同じ版で 3 に当たるので、抜け出せない。

時刻が前に詰まる理由（検証済み、`kill-repair` の DB）:
- purge のたびに、版が 1 秒後ろへずれる。
- 置き換えた dlist の名前は `Deleted` として `Remotevolume` に残り、二度と使われない。
- 時刻を 1 秒ずらす仕組みは、ほかにもある: dlist のアップロードの再試行（`BackendManager.PutOperation.cs:423`）、合成ファイル一覧（`UploadSyntheticFilelist.cs:92`）、repair（`RepairHandler.cs:440`）。

### 実際の報告との一致（ドキュメント根拠）

フォーラム 21865（2026-02、2.2.0.3_stable、WebDAV）の流れが同じだった。
- 壊れた dblock を 2 つ外し、repair を流した。
- purge-broken-files が「Unable to create a new fileset for duplicati-20250215T100001Z.dlist.zip.aes」で失敗した（時刻は 11:00:04 と 11:00:02）。
- そのあとの `test all` が DatabaseInconsistency になった（actual > dbsize、未解決）。

### ほかの報告の型

- **ブロックの合計が 0 で、ファイルの大きさが 150〜275 バイト（メタデータか 0 バイトのファイル）**: フォーラム 22340・22055・22100、#6822・#6877。#6854（2026-04）と #7215・#7226・#7229（2026-08）で kenkendk が対処済み。
- **dbsize 102400、actual 0**（フォーラム 22494・22561）: kenkendk によれば、repair が欠けたブロックを選び続ける不具合。2026-09 の時点で「次の canary で直る」。
- **actual > dbsize で、差がブロックの大きさの倍数**（フォーラム 22044 の purge 後、20457 の recreate 後）: 22044 の仕組みは未確認。20457 はブロックの大きさが 100 KB と 1 MB で混ざっていた。

### 報告の数字の読み方（検証済み、`git show 223950f29`）

2026-08-25 の [`223950f29`](https://github.com/duplicati/duplicati/commit/223950f29)（v2.4.0.100 canary 以降）より前は、メッセージの `actual size` に記録上の長さ、`dbsize` にブロックの合計が逆に入っていた。

そのため、それより前の報告の「actual > dbsize」は、実際には「長さ > ブロックの合計」、つまりブロックが欠けた状態を指す。
- 21865: 差は 1 ブロック以上。
- 22044: 差はちょうど 102400 = 1 ブロック。

どちらも今回の再現（長さ 3291691、ブロックの合計 3199531）と同じ向きで、消えた dblock のブロックだけが DB から落ちた形に合う。

## 対応（2026-10-30）

利用者の決定「A と B の両方」で `fix/purge-broken-files-timestamp-clash`（`bae582b2`）を push した。詳細は `PENDING-BRANCHES.md` の行と `pr-drafts/purge-broken-files-timestamp-clash.md`。

小さな候補（2026-10-30、利用者の指示で 1 つずつ）:
- **作り直しの途中の DB で、repair が purge-broken-files を案内する件**: 利用者の判断で見送り。
  - 「作り直しの途中」の印（`repair-in-progress`）は、recreate を落とした場合にも、最後まで終わったがブロックが欠けていた場合にも使われる（`RecreateDatabaseHandler.cs:777` が後者で purge-broken-files を案内し、purge-broken-files が印を外す）。後者では、この案内は設計どおり。
  - 落とした recreate（7 通りの時刻）に案内どおり purge-broken-files（`--dry-run`、`--disable-replace-missing-metadata` 付きも）を流すと、`FailedToLocateEmptyMetadataBlockset`・`AllFilesetsBroken`・`CannotListOnDatabaseInRepair` のどれかで止まり、データは消えなかった（検証済み、`inprogress.py`）。
  - recreate はブロックをまとめて読み込むので、一部だけ欠けた状態は作れなかった。
- **落とした compact のあとの compact が `UnexpectedUploadingFile` になる件**: `fix/compact-cleans-up-after-stopped-upload` で直した（`killcompact.py`）。
- **新しい候補: 落とした compact の後始末のあとの compact が、存在しない写しを `DuplicateBlock` に残す**（検証済み、master でも出る）。
  - 試験: `killcompact-r.py`（`REPAIR_FIRST=1`）で、compact を強制終了 → repair → compact → `test all`。master で 120 回中 11 回、`test all` が新しい dblock について `Missing: <hash>` を報告した。
  - 1 件の DB を調べた（`kc3-fix-32` の it30）。報告された 4 個は、どれも本体（`Block.VolumeID`）が別の dblock にちゃんとあった。そのうえで `DuplicateBlock` が、compact の出した新しい dblock にも写しがあると記録していたが、実物には入っていなかった。
  - 今すぐ復元できなくなるわけではない見込み。ただし、本体の側が後で compact されると、`PrepareForDeleteAsync` が `DuplicateBlock` の写しを本体に繰り上げるので、ブロックを失うおそれがある（推測、未確認）。
  - compact が `RegisterDuplicatedBlockAsync` で写しを記録する流れ（`CompactHandler.cs:229`）と、`PrepareForDeleteAsync` の付け替え（`LocalDeleteDatabase.cs:989`）が関わっていそう（推測）。

## `DuplicateBlock` の不具合への対応（2026-10-30）

- 原因（検証済み、テストと DB）: 後始末の `RemoveRemoteVolumesAsync` が `DuplicateBlock` を消さない。`Remotevolume.ID` の使い回しで、次の compact のボリュームが写しの記録を引き継ぐ。
- 実害（検証済み、CLI の 1 件）: `test` が dindex を DB から書き直して、誤った記録が宛先に入る。宛先から作り直すと、全部の復元が `BlockVolumeReader.ReadBlock` の `NullReferenceException` で止まった。単体テストの小さな構成では、復元は通った。
- `fix/removed-volume-duplicate-blocks`（`c44b1756`）で直した。

新しい小さな候補:
- 復元で、ボリュームに入っていないブロックを読むと `NullReferenceException` で復元全体が止まる（`BlockVolumeReader.ReadBlock` → `Utility.ForceStreamRead`）。どのブロックがどのボリュームにないのか分かる形で失敗すべき。 → 利用者の決定 B で、`fix/restore-skips-files-with-unreadable-block`（`d6178401` + `a00e5ea4`）にまとめた。ブロックを名指しし、そのブロックを使うファイルだけ失敗にして復元を続ける

## 未確認だった壊し方と、最後の確認（2026-10-30）

- **宛先を読み取り専用にする・消す**（`backend-errors`、25 回、master、Linux）。仕掛けの OSError 39 を直して流した。
  - 読み取り専用・一時的な消失は、どちらも次の backup で戻った。
  - 消えている間に一覧が通ったあと、最初のアップロードの前だと、Duplicati がフォルダーを作り直して 11 ファイルを書いた。`fix/no-recreate-vanished-destination` で直した。
  - その後の「please run repair」→ repair の「`--rebuild-missing-dblock-files` か purge-broken-files」は設計どおりで、仕掛けがその案内に従っていなかった。
- **前の一斉試験に、最後の `test all --full-remote-verification` と全部の復元の突き合わせを足した**（`final_check`）。kill-backup・sigint-backup・mutate・kill-compact・kill-delete・kill-purge を各 15 回流し、すべて test は 0 件のエラー、復元は差分 0。
- `LightWeightBackendManager`（同期ツール）の自動作成にも同じ穴があった（検証済み、テスト）。`fix/sync-no-recreate-vanished-destination`（`c79b5203`）で直した。
- 復元が 1 つのブロックの欠けで全体を止める件は、`fix/restore-skips-files-with-unreadable-block` で直した。
- CLI の restore が、ファイルが失敗しても終了コード 0 を返す件は、`fix/restore-exit-code-on-failed-files`（`cde76ca4`）で 3 を返すようにした。
