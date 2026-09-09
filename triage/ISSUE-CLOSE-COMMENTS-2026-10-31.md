# 実装済みの enhancement へのコメント（2026-10-31）

- 対象: `ENHANCEMENTS-2026-10-31.md` で IMPLEMENTED とした 35 件。#2620 は 2026-07-17 に自分がコメント済みなので外した（34 件）
- 基準: master [`7f5d95a12044ee01611d287f8fe40d9cade8d56e`](https://github.com/duplicati/duplicati/commit/7f5d95a12044ee01611d287f8fe40d9cade8d56e)、最新の stable は 2.4.1.0（2026-10-29）
- 確かめたこと（検証済み）:
  - 下で引くコミットのリリースは `git tag --contains` で調べた。canary にしか入っていないもの（restore-test・version-name・restore の詳細オプション・LogData のチェック）は、`git grep` で 2.4.1.0 stable の中身にあることを確かめた（stable は cherry-pick の枝なので、祖先ではなく中身で確認）
  - ngclient の引用コミットは、2.4.1.0 に同梱の `@duplicati/ngclient` 0.0.244（ngclient `4c2cb9a0`）の祖先であることを `git merge-base --is-ancestor` で確かめた
  - 10-31 に 34 件とも OPEN で、自分のコメントがないことを確かめた
- 確かめていないこと: どれもコードとリリースを読んだだけで、機能を動かしてはいない（未検証）。UI のものはブラウザで開いていない
- 投稿の前に、コメント数と最終更新日がこの表から変わっていないことを確かめる
- **GitHub にはまだ何も投稿していない**（利用者の承認待ち、5 件程度ずつ）

## 1 回目: オプションで実現済み（根拠が最も強い）

### #4561 Implement concurrent downloads（warwickmm、c=2、2024-02-01）
> This is available now: `--restore-volume-downloaders` sets how many volumes a restore downloads in parallel, and it defaults to half the number of CPU cores. It was added in [`7aa19f851ed5e57b7d936d04e279cbe5d8d5587b`](https://github.com/duplicati/duplicati/commit/7aa19f851ed5e57b7d936d04e279cbe5d8d5587b) and has been in releases since 2.1.0.3 beta.
> Would it be OK to close this?

### #3416 Repair command deletes remote files for new backups（Livven、c=9、2022-07-27）
> Repair now checks for this case: when the remote destination has filesets newer than the local database, repair stops with an error, so it no longer deletes files from newer backups. `--repair-ignore-outdated-database` overrides the check. It was added in [`bae82feeae9bc4327ef3cb568151237de26b42b3`](https://github.com/duplicati/duplicati/commit/bae82feeae9bc4327ef3cb568151237de26b42b3) and has been in releases since 2.1.0.109 canary and 2.1.2.0 beta.
> Would it be OK to close this?

### #1809 Enhanced integrity check with all dlist and dindex files（balazer、c=6、2025-05-21）
> This is available as `test all --full-remote-verification=ListAndIndexes`. It downloads and checks every dlist and dindex file without downloading the dblock files, and the remote listing confirms the dblock files are present with the expected sizes. It was added in [#5037](https://github.com/duplicati/duplicati/pull/5037) and has been in releases since 2.0.8.1 beta.
> Would it be OK to close this?

### #4364 Immutability / Object Lock for ransomware protection（bbccdd、c=1、2024-01-13）
> The Object Lock approach is available now: `--remote-file-lock-duration` locks uploaded volumes for the given time on S3, B2, Azure Blob, Google Cloud Storage and iDrive e2. It was added in [`0f81b42146b5dc55f3a9461038638909d34688f2`](https://github.com/duplicati/duplicati/commit/0f81b42146b5dc55f3a9461038638909d34688f2) and has been in releases since 2.2.0.103 canary and 2.2.1.0 beta.
> Would it be OK to close this?

### #2153 Allow user to add a note/description to a backup（u1735067、c=0）
> Versions can have labels now: `--version-name` sets a label when the backup runs, and the label can be changed later with the `set-version-label` command or on the version labels page of the new UI. The restore version picker shows it. It was added in [`4573c8ab9be75c96ade103c771c92d3ce150b794`](https://github.com/duplicati/duplicati/commit/4573c8ab9be75c96ade103c771c92d3ce150b794) and is in 2.4.1.0 stable.
> Would it be OK to close this?

- 注: 報告の「Run now を押したときに入力を促す」画面はない。上の文面ではそれを言っていない。気になるなら 2 回目以降に回す

## 2 回目: 設定の保存・検証・宛先

### #3376 Using existing backups（ahmed-rashed、c=6、2018-10-03）
> This is covered now: with `--store-task-config` (on by default for encrypted backups), the job configuration is stored in the backup itself. After a reinstall, the new UI can import it from the destination, so the source folders and settings come back. It was added in [`dcaba2fbcd6267e84c1f48cc09bbbe5f20134a7e`](https://github.com/duplicati/duplicati/commit/dcaba2fbcd6267e84c1f48cc09bbbe5f20134a7e) and [`d0d6eb6d204721a3a9914a1477cd4da8769fba32`](https://github.com/duplicati/duplicati/commit/d0d6eb6d204721a3a9914a1477cd4da8769fba32), in releases since 2.3.0.105 canary and 2.3.1.0 beta.
> Would it be OK to close this?

### #1266 Record name/properties of backup config in dlist file（robbat2、c=1）
> The job configuration can be stored in the backup now: `--store-task-config` writes the exported job configuration into the dlist files, so a backup can be identified and set up again without the original database. It was added in [`dcaba2fbcd6267e84c1f48cc09bbbe5f20134a7e`](https://github.com/duplicati/duplicati/commit/dcaba2fbcd6267e84c1f48cc09bbbe5f20134a7e) and has been in releases since 2.3.1.0 beta.
> Would it be OK to close this?

### #1273 Enhancement of verify options（PrismaComputer、c=2）
> Point 1 is available now as the `restore-test` command. It restores a sample of files using only remote data, can rebuild the database from the destination into a temporary file first (it does this automatically when there is no local database), and checks every restored file against its recorded hash and size. It was added in [`bf6deafcde0b8d1c0ff67ad77e47e0e6ffbd3cfb`](https://github.com/duplicati/duplicati/commit/bf6deafcde0b8d1c0ff67ad77e47e0e6ffbd3cfb) and is in 2.4.1.0 stable.
> Would it be OK to close this?

- 注: Issue の 2 点目（`test all` で落としたデータを restore に使う）は実現していない。本人も「普通の restore で足りるかも」と書いているので、文面は「Point 1 is available」とし、2 点目は閉じてよいかを尋ねる形にする。投稿するなら末尾を "Point 2 is not implemented; would a regular restore cover it, so this can be closed?" にする（10-31 に本文を読み直した）

### #3751 Error when backing up to S3 DEEP_ARCHIVE storage class（CGsama、c=2、2024-02-02）
> This is handled now: volumes in an archive storage class are skipped by the verification after a backup, and `--s3-archive-classes` (which includes DEEP_ARCHIVE and GLACIER by default) decides which classes count as archived. It was added in [`71b3152f711b9dbc68479e68a64a4ee84d790e0d`](https://github.com/duplicati/duplicati/commit/71b3152f711b9dbc68479e68a64a4ee84d790e0d) and has been in releases since 2.1.0.117 canary and 2.1.2.0 beta.
> Would it be OK to close this?

### #2709 FTP: Create folder if it does not exist on "test connection"（LM1LC3N7、c=2）
> This works now: the FTP connection test changes into the folder, a missing folder is reported as such, and the UI then offers to create it. The FTP part was changed in [`5712264e6a4a919bd9590deee0dab2d8db92858a`](https://github.com/duplicati/duplicati/commit/5712264e6a4a919bd9590deee0dab2d8db92858a), in releases since 2.1.0.2 beta.
> Would it be OK to close this?

## 3 回目: 新しい UI（ngclient、2.4.1.0 に同梱の 0.0.244 に入っている）

### #4996 UI support for list-broken-files and purge-broken-files（modem-man-gmx、c=0）
> The new UI has a page for this now: it lists the broken files of a backup and can purge them, using the server endpoints added in [`1c50542b46188ffca48a3ca614246922f0f87b19`](https://github.com/duplicati/duplicati/commit/1c50542b46188ffca48a3ca614246922f0f87b19) and the page in duplicati/ngclient@3e89585b21f483b7026cc060fddacc867621b537. It is in 2.4.1.0 stable.
> Would it be OK to close this?

### #4681 Option for in-progress backup display / ETA（kahomono、c=4、2022-02-15）
> The status page of the new UI shows the estimated time remaining and the current speed while a backup runs (duplicati/ngclient@585ce578f0d52191031a982e78e672dbbbcaa53f). It is in 2.4.1.0 stable.
> Would it be OK to close this?

### #4830 Add top-level stats to the log entry titles（taz-il、c=0）
> The log page of the new UI now shows the duration, the uploaded size and the backup size in the title of each entry (duplicati/ngclient@baba2f2643a7127d3f0b97aaa4c841d1ef72fa9b). It is in 2.4.1.0 stable.
> Would it be OK to close this?

### #4497 SFTP browsing（darrepac、c=0）
> The new UI can browse the destination now: the destination page has a "select folder" dialog that lists the folders on the server, and the SFTP backend supports it (duplicati/ngclient@75cf5d3dbfbcf79997f281601ca7860b05facb47). It is in 2.4.1.0 stable.
> Would it be OK to close this?

### #2185 Advanced options cannot be set when restoring files（kees-z、c=4）
> The restore options step of the new UI has an advanced options list now, for restores from a job and for direct restores, using the capability added in [`7b68a81e190c4a7f6de9096626399591ea04aca0`](https://github.com/duplicati/duplicati/commit/7b68a81e190c4a7f6de9096626399591ea04aca0) and duplicati/ngclient@244ce02eabb54cfe53b81c31b070e1f6cfb2fdb7. It is in 2.4.1.0 stable. #2211 asks for the same thing.
> Would it be OK to close this and #2211?

### #2211 When restoring files, advanced options cannot be selected from the list（kees-z、c=1）
> This is covered by the same change as #2185: the restore options step of the new UI has the advanced options list with a picker, in 2.4.1.0 stable.
> Would it be OK to close this?

- 注: 旧 UI（ngax）にはない。「新しい UI で」と書いているので嘘ではないが、メンテナが旧 UI も気にするかは不明

## 4 回目: その他、根拠のあるもの

- #1174 現在の処理の表示（ngclient の `status-states.constant.ts`）
- #2018 戻るボタン（ngclient の各ページ）
- #1814 実行していないバックアップのログ表示のエラー（`BackupGet.cs:194,207`、[`76d082480f8b0b8c9a2f4a6066c9ea39f2546f2f`](https://github.com/duplicati/duplicati/commit/76d082480f8b0b8c9a2f4a6066c9ea39f2546f2f)、2.4.1.0）
- #2630 NAS の資格情報が Windows に残る（ネイティブの `smb://`、[`99ee234640d475ab80ba8e26a7d2b4923e4b7711`](https://github.com/duplicati/duplicati/commit/99ee234640d475ab80ba8e26a7d2b4923e4b7711)、2.1.0.3 beta）
- #2590 クラウドをソースに（`BackendSourceProvider`、[`8c935a7344df2678cd8af638e59af86e375719e7`](https://github.com/duplicati/duplicati/commit/8c935a7344df2678cd8af638e59af86e375719e7)、2.1.2.0 beta）

1〜3 回目の反応を見てから文面を書く。

## 5 回目: 古い要望（2017〜2018）

- #2846 ログのタイムスタンプ（[`842fd965439c6f1e6aac2d9ecaedfac1981e16c9`](https://github.com/duplicati/duplicati/commit/842fd965439c6f1e6aac2d9ecaedfac1981e16c9)、2.0.4.3 beta。syslog はない）
- #2848・#3292 SQLite の WAL・mmap・synchronous（[`322e4f15e4b39128821279a662fc1ee0d3d59170`](https://github.com/duplicati/duplicati/commit/322e4f15e4b39128821279a662fc1ee0d3d59170)、2.2.1.0 beta）
- #3264 ドライブのラベル（`\\?\Volume{GUID}\` のソース、[`f9618b958722ade7cb390385ddec529a816f1c42`](https://github.com/duplicati/duplicati/commit/f9618b958722ade7cb390385ddec529a816f1c42)、2.0.3.2 beta）
- #2493 %RESULT% の引用符（`--send-mail-result-output-format=Json`、[`b7bda1d1c4f2a40afb37e22203ecd4d8be6ac860`](https://github.com/duplicati/duplicati/commit/b7bda1d1c4f2a40afb37e22203ecd4d8be6ac860)、2.0.4.3 beta）

## 保留: 根拠が弱い・一部だけ（投稿するなら動かして確かめてから）

| # | 弱い点 |
|---|---|
| #1270 | kenkendk 自身の 2015 年の追跡用 Issue。インストーラーとサービスはあるが、閉じるかは本人の判断 |
| #1308 | コードを読んだだけ（各バージョンは完全なスナップショット）。UI で確かめていない |
| #2496 | Pushover は汎用の HTTP レポートで送れる見込み。実際の Pushover では未確認 |
| #2571 | .NET の既定の TLS（ドキュメント根拠）。WebDAV で未確認 |
| #2811 | 中身がフォーラムへのリンクだけで、何をもって完了かが曖昧 |
| #2903 | パスは既定で伏せられるが、「messages を消す」スイッチはない |
| #3491 | バグレポートの DB に LogData が残る（コード）。2018 年にメンバーが確認済み |
| #4098 | ロックされたファイルは警告つきで飛ばされ、`--suppress-warnings=FileLocked` で情報に下げられるが、要望のチェックボックスはない |

## 投稿の記録

### 1 回目（2026-10-31、利用者がこのセッションで承認）
投稿の直前に、5 件ともコメント数と最終更新日が上の表と変わっていないこと（#4561: 2 件・2024-02-01、#3416: 9 件・2022-07-27、#1809: 6 件・2025-05-21、#4364: 1 件・2024-01-13、#2153: 0 件・2025-05-21）と、`--remote-file-lock-duration` の対応先（`ILockingBackend` を実装するのが S3・Backblaze・AzureBlob・GoogleServices・Idrivee2）を確かめた。投稿された本文は下書きと一致（末尾の空行を除いて diff で比較）。
- #4561 https://github.com/duplicati/duplicati/issues/4561#issuecomment-6540604837
- #3416 https://github.com/duplicati/duplicati/issues/3416#issuecomment-6540605051
- #1809 https://github.com/duplicati/duplicati/issues/1809#issuecomment-6540605260
- #4364 https://github.com/duplicati/duplicati/issues/4364#issuecomment-6540605471
- #2153 https://github.com/duplicati/duplicati/issues/2153#issuecomment-6540605712

### 1 回目の結果（2026-10-31 夕方に確認）
- #3416・#4364 は kenkendk が閉じた（COMPLETED）。#4364 には「`--soft-delete-prefix` も今はあり、削除の権限を与えない要望も満たす」と追記
- #4561・#1809・#2153 は open のまま、反応なし
