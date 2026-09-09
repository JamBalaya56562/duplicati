# 別件: only_paths で作った一時ジョブの DB でそのまま復元すると失敗する

2026-11-10、ngclient#449 の切り分けで見つけた。一覧の修正（`fix/list-folder-other-system-separator`）とは独立（検証済み）。

## 症状
`POST /api/v1/backups?temporary=true` → `POST /api/v1/backup/{id}/repairupdate {only_paths: true, time}`（ngclient の select-files と同じ）
→ 同じ `{id}` に `POST /api/v1/backup/{id}/restore` すると、タスクは Failed:
`Found 2 remote files that are not recorded in local storage ...`、ファイルは作られない。

## 観測（検証済み、Windows と WSL の Linux、修正版と master のどちらでも）
| 経路 | 結果 |
|---|---|
| 一覧に使った一時ジョブでそのまま restore（同 OS・異 OS とも） | Failed、上のメッセージ |
| ngclient と同じく `copytotemp` してから restore（パスは `.../Documents/*`） | Completed、`payload.txt` だけ、内容一致 |
| 一覧を見ていない新しい一時ジョブで restore | Completed、内容一致 |

例外の位置: `FilelistProcessor.VerifyRemoteListAsync`（`FilelistProcessor.cs:182`）← `RestoreHandler.DoRunNewAsync`（`RestoreHandler.cs:910`）。
ログ: `Extra unknown file: ...dblock.zip`、`...dindex.zip`。only_paths の再作成は dblock・dindex を DB に記録しないので、復元前のリモート一覧の照合で「余分なファイル」になる。

## 判断
UI は `copytotemp`（`restore-flow.state.ts:145-158`、「file picking 用の部分 DB」とコメント）で避けているので、UI の経路では起きない。前回のセッションの API プローブ固有。
ただし API を直接使う呼び出し元（スクリプト・別クライアント）は踏む。

## 修正候補（未実装）
1. only_paths で作った DB に印（Configuration など）を残し、restore がそれを見たら部分 DB を作り直す（または no-local-db 相当で走る）。
2. 一時ジョブの restore では、サーバー側で常に `copytotemp` 相当を行う。
3. 少なくともエラーを「この DB は一覧用の部分 DB」と分かる文言にする。
DB に only_paths の印は今は無い（`RecreateDatabaseHandler.cs:757` はログだけ）。
