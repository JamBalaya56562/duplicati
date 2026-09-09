# Issue の再調査（2026-11-25）

open 376 件のうち、私たちのコメントが無く、close の可能性がありそうな 136 件を調べた。スレッドとコードは subagent 6 体が読み（ビルドや実行はなし）、**下の「実行して確かめた」と「確かめた根拠」は私が自分で行った**。実行は stable 2.4.1.0 のタグ（`v2.4.1.0_stable_2026-10-29`）をビルドしたもの、不具合は master `05b255ad` でも。投稿は承認後、出す前に open かを確かめる。

## 1. close 提案の下書き（残り 4 件、未投稿。#2076 は 11-28 に投稿した）

出さない・後回しにした理由（決めたら必ず理由を書く。利用者の指示 11-28）:
- #2411（出さない、11-25 の利用者の判断、理由は 11-28 に利用者が確認）: 根拠の Duplicati Console は有料の別サービスで、オープンソースの機能の要望を「有料のサービスがある」で閉じる提案はふさわしくない。コメント 139 件の多くの人が見ている Issue でもある。
- #3011（根拠が弱い）: 新しい UI ではログが About の中のタブになったが、ngax は今もログを別のページで開くので、報告の状況は旧 UI では変わっていない。
- #2544（根拠が弱い）: 遅かったクエリは 2025 年に書き換えられて索引を使うが、同じ大きさの DB で時間を測っていないので、直ったとは言えない。
- #2744（根拠が弱い）: 「両方の画面が復元の失敗を表示する」を自分でコードや実行で確かめていない（subagent の読みだけ）。


**11-28 に投稿した close 提案（返事待ち）**: 2 回目（利用者の承認）#4192・#2800・#1884・#2893・#3249・#5268・#5559・#2690・#3985・#3429、1 回目 #2947・#2115・#2470・#2967・#3701・#2368・#3752・#663・#2720。根拠は stable 2.4.1.1 のコードとスレッドで確かめ直した。

**11-28 に出さないことにしたもの**: #4208（ts678 が「open のままでも害はない」）・#6209（報告者の 504 の報告に返事がない）・#5554（kenkendk の可変ブロックの案が生きている）。


### 実行して確かめたもの（検証済み）

### 公式の stable 2.4.1.0 を fork の使い捨て runner で動かしたもの（検証済み、11-25）

### 未コメントの残り 82 件（要望）から（11-25）

### 重複（相手が open なことを確認済み）

### コード・文書・スレッドで確かめたもの

**#2544** "Completing Backup" for 30 hours（検証済み: 2.4.1.0 のコード、時間は測っていない）
> The query that was running here counted the added, changed and deleted files by joining two lists without an index. It was rewritten in 2025 ([8b72528](https://github.com/duplicati/duplicati/commit/8b7252803063afc1e9f16fb7e1ddd4806dbdc275)) and now uses an index on the path. I have not timed it on a database of this size. Can this be closed?

**#2411** Remote management（コード、文書）
> Duplicati can now connect to the [Duplicati Console](https://docs.duplicati.com/duplicati-console/using-the-duplicati-console), which gives central monitoring and remote management of connected machines. Monitoring was described here as the main need. Can this be closed?

**#2744** XSRF error, empty restore form, success after a failed restore（コード、スレッド）
> The XSRF problem behind most of this was fixed in #2635. Both web interfaces now check the result of the restore task and show an error if it failed. Can this be closed?

**#3011** "Show log" leaves the About tabs（コード。ngax は今も別のページ）
> In the new UI the log is one of the tabs on the About page, so the other tabs stay visible. The old UI still opens a separate page. Can this be closed?

## 2. 実際に起きる不具合（検証済み、master `05b255ad`）

#3271（#8012）・#2501（#8014）・#2955 と #2968（#8013）・#3716（#8015）・#3178（#8016）・#2655（#8017）と、WebDAV の親フォルダー（#8018）は PR がマージされ、Issue も 11-27 に閉じたので、項目を消した。

- **（直した: `fix/recoverytool-hash-algorithms`、[#8051](https://github.com/duplicati/duplicati/pull/8051)）RecoveryTool がファイルとブロックのハッシュが違うバックアップを復元できない**（Issue なし）: 1 ブロックのファイルは `blockhash` でなくファイルのハッシュでブロックを探して `Unable to locate block`（`Restore.cs:197`）、複数ブロックは `block-hash-algorithm` を 2 回読むので `Restored file hash mismatch`（`Restore.cs:87`）。`--file-hash-algorithm=SHA512` で両方とも 2.4.1.0 で確認、master も同じコード。
- **（直した: `fix/zip-compression-methods`、[#8053](https://github.com/duplicati/duplicati/pull/8053)）`--zip-compression-method` の Xz・GZip・Deflate64 は選べるが必ず失敗する**（Issue なし、#3689 の調査で発見）: `Invalid compression method: Xz`。ZStandard・LZMA・BZip2・PPMd は通る（2.4.1.0）。
- **（直した: `fix/repair-force-block-use-help`、[#8054](https://github.com/duplicati/duplicati/pull/8054)）`--repair-force-block-use` の help が `--repair-only-paths` の説明になっている**（Issue なし、`Options.cs:657`、2.4.1.0 の help で確認）。
- ngclient の「Last successful backup」はエラーのあった実行でも更新される（#6607 の残り。kenkendk は「Last completed backup」を提案。推測、コードを読んだだけ）。
- **WebDAV のアップロードも止まると固まる**（検証済み、stable 2.4.1.0）: 本文を読まない偽サーバーで、`--read-write-timeout=10s` でも 240 秒で終わらない。`fix/stalled-upload-timeout` の `WithUploadTimeout` で直した: `fix/webdav-stalled-upload-timeout`（11-28 に #8042 で PR にした）。

## 3. canary / master で直っていて stable 待ち

11-28 に、待っていた close 提案を利用者の指示でまとめて投稿した（13 件、下の PENDING-BRANCHES の一覧）。出さなかったものと理由は `issue-drafts/close-proposals-not-posted.md`。

## 4. 動かして確かめた結果、open のままにするもの（11-25）

- **#3471**: (1) nginx の 413 は、aws クライアントなら `RequestEntityTooLarge` と出るが、**minio クライアントは `Object reference not set to an instance of an object.` だけ**（Minio 6.0.0。`ParseErrorFromContent` の中）。→ `fix/minio-non-xml-error-answer` で直した（11-26、PR 未）。(2) フォルダーを `/` にすると（`s3://bucket//`）、aws は署名の不一致、minio は書けたファイルを一覧で見つけられず `MissingRemoteFiles`（RustFS・MinIO とも）。`s3://bucket/` は問題なし。先頭の `/` は #4711 と同じで、直しは 10-30 に取り下げ済み。→ 名前は変えず、理由を警告する `fix/s3-leading-slash-warning`（Fixes #3471、11-26、PR は B のマージ後）。
- **#2229**（Windows が遅い）: runner（4 コア、Windows）で 512 MB × 6 は 57 秒、**20 kB × 10 万件（2 GB）は 1041 秒**（毎秒 96 件、ただのコピーは 117 秒）、変更なしの 2 回目は 35 秒。手元（master の Debug ビルド）は 1 万件で 52 秒、`--skip-metadata` で 29 秒。Linux は 40 万件で 473 秒（毎秒 850 件）。Windows の小さいファイルの遅さは今もある。原因は未調査（推測: ACL などのメタデータと Defender）。

runner で動かした残り 13 件は 1 節に下書きがある。

## 5. 弱いので今は出さないもの

#3197（原因不明のまま）・#3159（2026-04 に新しいコメント）・#4783（メンテナーの返事なし）・#3875・#4334（Google のログインのまとめ役）・#2641（SDK の版を確かめていない）・#2419（手元の openssl では SHA512 の方が速く、閉じる根拠にならない）。

## 6. open のまま（今はすることなし）

616・2669・2895・3949・3689・3150・6835・2633・3671・3683・4216・4845・2272・1442・2049・4711（先頭の `/`。直しは 10-30 に取り下げ）・4169（ngax の一覧の再試行）・5670・2468・2556・3040・3533・6051・5944・4832・4908・1845・2885・4125・2149・2189・1724・1966・3179・3710・3478・4101（翻訳は Transifex）・5605・5092・5590・6305・7664・7627・2365・2238・3551・4753・5205・5240・5242・5759・5912・5915・5942・6376・6304・2346・2653・1152・611・2921・5992・3255。

## 7. 要望のうち、今回読んで open のままにしたもの（11-25）

6557・6365・6058・5934・5675・5663・5662・5599・5649・5594・5553・5457・5440・5421・5166（未対応の csproj は 112 のうち 55）・4734（Windows はグループ ポリシーで可、スレッド）・4622・4494・4389・4199・4032・3862・3819・3688・1918（rclone で代わりになるが弱い）・3583・3539・3450・3246・3211・3081・3041・2991・2901・2816・2769・2764・2689・2667・2655・2583・2466・2317・2267・2234・2072・2030・2012・1996・1969・1922・1775・1740・1739・1673・1586・1032・996・866・525・520・519・191・72・6621・6182・4710・3362・2467・2207・1970・1417。#7664 は 11-05 に kenkendk が質問し、報告者の返事待ち。
