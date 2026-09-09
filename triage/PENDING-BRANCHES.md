# PR 待ちブランチ — origin に push 済み、PR はまだ出していない修正

- **最終更新**: 2026-09-16（4 本を PR に：#7323 #7324 #7325 #7326。残り 7 本：task-queue は #7323 の上に積んであるのでそのマージ後。一覧系 4 本＋fileset 完全一致は `DirectListHandlerTests.cs` を触るので #7326 のマージ後に rebase して出す。purge/set-locks は独立、ただし `SetLocksHandlerTests.cs` を fileset 完全一致と共有）
- **方針**: open な PR が多い間は新しい PR を出さず、修正だけ origin（`JamBalaya56562/duplicati`）に push しておく。
  古い PR がマージされたら、ここから順に PR を出す
- **PR 本文の下書き**: [`pr-drafts/`](pr-drafts/)（英語、`Fixes` 無し、末尾に 🤖 行）。ブランチ名の `fix/` を除いた名前で 1 ファイル
- **PR の出し方**: `gh pr create -R duplicati/duplicati --head JamBalaya56562:<bookmark> --title "<コミット 1 行目>" --body-file triage/pr-drafts/<name>.md`。
  出したらこの表の「PR」欄を埋め、下書きは残す（本文の修正は GitHub 側で）
- **CI**: PR を開くまで CI は走らない。2026-09-15 の rebase 後はローカルでビルド・テストを**していない**（利用者の指示：CI で赤が出たら見る）

## 一覧（全部 master `343d00c4` 直上の 1 コミット、衝突なし）

| ブランチ | commit | 内容 | 赤→緑（実測済み） | PR |
|---|---|---|---|---|
| `fix/sync-mode-without-parameter` | 822a2773 | remote sync の宛先が `mode: interval` なのに `interval` 無し（`counting` なのに `count` 無し）だと**最初の 1 回しか同期されない**。警告して inline で走る | Win + WSL 4 件、`TestCategory=RemoteSync` 44/44 | [#7324](https://github.com/duplicati/duplicati/pull/7324)（09-15） |
| `fix/task-info-finished-current-task` | 4c9275e9 | `GET /api/v1/task/{id}` が終わったタスクを `Running` と答える窓（runner が `TaskFinished` を立ててから `_current` を消す）。`GetTaskQueue` と同じくキャッシュ結果から答える。#6597 の調査で発見（ngclient 側は別リポの `fix/restore-repair-failure`） | Win + WSL 2/6、統合テスト 2 件緑 | [#7323](https://github.com/duplicati/duplicati/pull/7323)（09-15、ngclient 側の PR は利用者が別途） |
| `fix/fileset-exact-match-no-fallback` | 94af4bf1 | `GetFilesetIDsAsync(singleTimeMatch: true)` が一致しないと**全 fileset に fallback** → `list-folder` が別の版を返す／`SetLocksHandler` が存在しない版時刻で最新版をロック。0 件を返すように | Win + WSL 3 件、回帰 70 合格 | — |
| `fix/abort-unblocks-backend-call` | 6d82bdd6 | 「今すぐ停止」が token を見ないバックエンド呼び出しで戻らない（#6461 の一機構）。`UntilCancelledAsync` = `WhenAny(呼び出し, cancel)`。`StallingBackend`（`stall://`）で決定的に再現 | Win + WSL、回帰 61 緑 | [#7325](https://github.com/duplicati/duplicati/pull/7325)（09-15） |
| `fix/list-file-versions-full-path` | 5e43402d | `list-file-versions` / V2 `list-versions` が**常に空**：ハンドラが全パスに区切りを付け、DB は `FileLookup.Path`（末尾部分）と比較。版時刻も epoch 秒を ticks で読んで年 0001。フルパスで引く・返す | Win + WSL 3 件、`DirectListHandlerTests` 14/14 | [#7326](https://github.com/duplicati/duplicati/pull/7326)（09-15） |
| `fix/root-listing-file-prefix` | bc60d345 | ルート一覧が、ファイルソースの名前を延ばした別ソース（`notes.txt` と `notes.txt.old`）を落とす → 復元ツリーに出ない。フォルダ（末尾区切り）のルートだけが配下を吸収 | Win + WSL 2 件、15/15 | — |
| `fix/list-folder-trailing-separator` | 1cc5f099 | `list-folder-contents "<folder>"` を末尾区切り無しで渡すと空。ハンドラで `AppendDirSeparator` | Win + WSL 1 件、14/14 | — |
| `fix/search-folder-subfolders` | 5fd6d2f4 | `search "<folder>"` が直下しか見ない（help は subfolders と言う）。prefix の完全一致を `[folder, 末尾 1 文字 +1)` の範囲比較に | Win + WSL 1 件、14/14 | — |
| `fix/list-folder-default-latest` | 788d82a7 | `list-folder-contents` を `--version`/`--time` 無しで呼ぶと 2 つ目のバックアップから `MultipleFilesetsFound`（help は「最新版を選ぶ」）。指定が無ければ version 0 を選ぶ。UI は常に時刻を渡すので CLI と API 直叩きのみ | Win + WSL 1 件、`DirectListHandlerTests` 14/14 | — |
| `fix/purge-locks-strict-selection` | fd0fc701 | `purge --version=<無い版>` / 古い `--time` が**全版から消す**（無効な版は警告して捨てられ WHERE 句が空、0 件なら fallback が全件）。`set-locks` も同経路で全版をロック。新メソッド `GetSelectedFilesetIDsAsync`（fallback 無し）を purge と set-locks だけが使う。restore/list の fallback は仕様のまま | Win + WSL 2 件、Purge + LockHandler 9/9 | — |
| `fix/task-queue-waiting-status` | 7e31b595 | `GET /api/v1/tasks` が開始前のタスクを `Running` と報告（`TaskFinished == null` だけで判定）。`GetTaskInfo` と同じく位置で `Running`/`Waiting`。**#7323（`fix/task-info-finished-current-task` 4c9275e9）の上に積んである** — マージ後に `jj rebase -r 7e31b595 -d master` で上の 1 コミットだけ載せ替えてから出す | Win + WSL 2 件（番人 2 件は両側緑）、TaskQueue + FolderStatus 39/39 | — |

### 注意

- **一覧系 5 本**（list-file-versions / root-listing / list-folder-trailing-separator / search-folder-subfolders / list-folder-default-latest）は全部
  `DirectListHandlerTests.cs` にテストを足し、3 本が `LocalListDatabase.cs` の別メソッドを、2 本が `ListFolderHandler.cs` の別の行を触る。意味的な衝突は無いが、
  1 本マージされるごとに残りを master に rebase してから PR を出す（テストファイルで文面上の衝突が出る）
- `fix/abort-unblocks-backend-call` は #6461 の**一部**。source ファイルの同期読み取りと SQLite 文の非 cancel 待ちは未対応。`Fixes` は付けない
- `fix/task-info-finished-current-task` も `Fixes #6597` は付けない（issue の race は再現できていない。再現できたのは「repair 失敗を UI が無視する」経路）

## 見つけたが直していないもの（同じ調査で）

- `search` の help が `--version` で「無ければ最新（version=0）」、同じブロックの `--all-versions` で「全版が既定」と言っていて矛盾。実装は後者（実測：版指定なしで versions=1,0,0 が返る）

- ~~`TaskQueueService.GetTaskQueue` が待機中タスクを `Running` と報告~~ → `fix/task-queue-waiting-status` で修正
- `QueueRunnerService` の `CachedTaskResult.TaskFinished` が `DateTime.Now`（ローカル）、`TaskStarted` が `UtcNow`。JSON はオフセット付きで出るので瞬間は正しい
- ~~`SetLocksHandler` の「No version specified」が「指定はあったが一致しない」場合にも出る~~ → `fix/purge-locks-strict-selection` で修正
- `RecordSyncOperation` が `Operation` 表に `Rsync N` 行を入れ、`Controller` の後始末が最新 Operation 行に相乗りする → バックアップのログが sync の operation id に紐づく可能性。`LogData.OperationID` を join して読む箇所が見つからず症状を示せない
- `ShouldTriggerSync` は `m_dbpath` を検査しない（`RecordSyncOperation` はする）。backup では dbpath が常に有るので実害なし

## 使い捨ての再現テスト（scratchpad、セッション e8cd3eb2 が消えたら消える）

`ProbeListFileVersions.cs`、`ProbeListFolder.cs`、`ProbeSearchFolder.cs` — Controller 経由で症状を `TestContext.Progress` に出すだけの
テスト。同じ内容は各ブランチのテストに正式に入っているので、無くなっても困らない。
