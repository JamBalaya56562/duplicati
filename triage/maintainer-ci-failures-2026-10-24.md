# メンテナーの PR でだけ動く CI の失敗（2026-10-24 に調べた）

fork からの PR では secrets が無いので、`backendtests.yml`（Backend Live Tests）の各バックエンドの job は skipped になる。
成否はメンテナーのブランチからの PR でしか分からない。`build-packages.yml`・`tests.yml` は fork の PR でも動く。

## 調べた範囲

`gh run list --status failure` の直近 40 件と、メンテナーの PR 14 本（#7514〜#7557）の checks。
メンテナーの PR でだけ失敗していたのは Backend Live Tests の job だけだった。

| 日付 | PR / ブランチ | 失敗した job |
|---|---|---|
| 10-24 | #7554 feature/fix-cookie-path-on-proxy | Google Drive (windows) |
| 10-23 | #7536 feature/google-workspace-delta-tracking | CloudStack (ubuntu) |
| 10-21 | feature/fix-vacuum-startup-race | Google Drive (macos) |
| 10-21 | #7515 point-in-time-restores | Drime (macos・ubuntu・windows) |
| 10-20 | feature/add-support-for-reporting-secret-provider | Google Drive (ubuntu) |
| 10-14 | feature/support-duplicati-storage-as-secondary-storage | Google Drive (windows) |
| 10-12 | feature/avoid-logging-destination-url-for-multi-destination | Google Drive (macos・windows) |

ほかに、#7539 の Build packages (windows) が 6 時間で打ち切られた（後述）。
`build-packages.yml` は fork の PR でも動き、直近 15 回はすべて 34〜72 分で成功している。

## 1. Google Drive: アップロードが打ち切られたあとに同じ名前のファイルが 2 つ残る（コードの不具合、直す候補）

**ログで確かめたこと（検証済み）**
- 10-21 の macos（job 119147797034）・10-20 の ubuntu（118524206512）・10-12 の windows（114690612812）の 3 件が同じ形だった。
- アップロードが read-write timeout（60 秒）で `TaskCanceledException` になる。
- BackendTester がアップロードを再送すると、再送は成功する。
- 削除のあと、ファイルが 1 つ残る。`Remote folder contains 1 file(s), aborting` や `Remote folder contains … after cleanup` になる。

**コードで確かめたこと（`GoogleDrive.cs`、ドキュメント根拠ではなくコードを読んだもの、Google 上での再現は未検証）**
- `PutAsync` は失敗すると `m_filecache` を消す。
- 再送のときは一覧を取り直し、同じ名前が無ければ POST で新しく作る。
- 打ち切られた 1 回目が Google 側では最後まで終わっていると、同じ名前のファイルが 2 つになる。Google Drive は同じ名前のファイルを許す。
- 再送が成功すると、キャッシュには 2 回目の 1 件だけが入る（`m_filecache[remotename] = [res]`）。
- そのため `DeleteAsync` は、キャッシュにある 1 件しか消さない。1 回目のファイルは残る。

**本番への影響（推測）**
- 同じ名前のファイルが 2 つ残ると、あとの `GetFileEntriesAsync` や `RenameAsync` で `GoogleDriveMultipleEntries` の例外が出得る。
- 消したはずの dblock が残って容量を使い続ける。

**直し方の案**
- 失敗したアップロードの再送の前、または削除の前に、キャッシュではなく一覧を取り直して、同じ名前のものをすべて扱う。
- 試験は、stub の HttpMessageHandler で「1 回目の POST が打ち切られるが、一覧には後から現れる」を作る（オフラインで書ける）。

## 2. Google Drive: 403 Forbidden が数秒続いて失敗する（原因の確定には本文が要る）

**ログで確かめたこと（検証済み）**
- 10-24 の windows（120805652859）・10-14 の windows（115740126893）・10-12 の macos（114690612712）の 3 件が該当する。
- 一覧・ダウンロード・削除が `403 (Forbidden)` で失敗した。BackendTester の 1 秒・2 秒の再試行でも続いた。
- 3 つの OS の job は `max-parallel: 1` で順に走り、リポジトリ全体で 1 つの concurrency group に入っている。
- 失敗したのは、ほとんどが 2 番目か 3 番目の job だった（同じ run の前の job が先に API を使っている）。

**ドキュメント根拠**
- Google Drive API は、利用量の制限（`userRateLimitExceeded`・`rateLimitExceeded`）を 403 で返す。
- 指数的に間隔を空けて再試行するよう求めている。

**推測**
- 利用量の制限に当たっている。
- ただし、`JsonWebHelperHttpClient.GetResponseAsync`（243 行目）が `EnsureSuccessStatusCode` で本文を捨てるので、ログに Google の reason が残らず確定できない。

**直す候補**
- 403 の本文の reason を例外とログに残す。
- reason が利用量の制限のときは、再試行できる失敗として扱う。

## 3. CloudStack（OpenStack Swift、infomaniak）: 消したファイルがあとで一覧に戻る（外の要因と見る）

- 10-23 の ubuntu（120294497810）。
- run 0 で `khHXh_Zm` を rename した（COPY のあと DELETE）。run 0 の一覧の確認と、片付けのあとの空の確認は通った。
- run 1 の片付けのあとに、`khHXh_Zm` が一覧に出た（検証済み、ログ）。
- Swift のコンテナの一覧は結果整合なので、消したものが一時的に戻ったと見る（推測）。
- 同じ CloudStack の job は、ほかの run ではすべて成功している。コードの直す所は見つけていない。

## 4. Drime: 3 つの OS すべてで `Access denied. Check your permissions.`（外の要因と見る）

- 10-21 の #7515 だけで起きた。一覧の最初の要求から拒まれている（検証済み、ログ）。
- 前後の run ではすべて成功しているので、その時のトークンや権限の側の問題と見る（推測）。

## 5. Build packages (windows): `linux-arm7-cli` の作成で 5 時間 40 分止まった（1 回だけ）

- #7539（job 120527404050）。`Building linux-arm7-cli ...` のあと出力がなく、6 時間の上限で打ち切られた（検証済み、ログ）。
- `linux-arm7-gui` までは 3 分ほどずつで終わっている。
- 止まった理由はログに無く、分からない（未検証）。
- `build-packages.yml` に `timeout-minutes` が無いので、止まると 6 時間ランナーを使う。直近 15 回の最長は 72 分。
- `timeout-minutes`（例: 120）を付ける候補がある。

## ついでに見つけたこと

- メンテナーの #7556「Avoid passing `--store-task-config`」（open）は、`fix/store-task-config-not-passed` と同じ `Runner.cs` の同じ直し。
- こちらのブランチで足しているのは `ServerApiIntegrationTests.cs` の試験だけになる。
