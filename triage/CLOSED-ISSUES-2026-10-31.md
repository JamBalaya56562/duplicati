# triage で扱った Issue のうち閉じられたもの（2026-10-31 に確認）

- 調べ方: `gh issue list --state closed --search "closed:>=2026-10-30"`（7 件）と、10-30 の確認（`CLOSED-ISSUES-2026-10-30.md`）に入っていない 10-29 の 3 件（#7629〜#7631）。閉じた人と閉じた PR・コミットは GraphQL の `ClosedEvent`（`closer` が空なら手で閉じたもの）
- 10 件とも triage のどれかのファイルに番号が出てくる

| Issue | 閉じた日 | 閉じ方 | 閉じた人 | 閉じた PR・コミット | 題名 | triage での扱い |
|---|---|---|---|---|---|---|
| #3416 | 2026-10-31 | COMPLETED | kenkendk | — | Repair command deletes remote files for new backups | 10-31 に閉じる依頼をコメント（`ISSUE-CLOSE-COMMENTS-2026-10-31.md` 1 回目）、約 3 時間後に閉じられた |
| #4364 | 2026-10-31 | COMPLETED | kenkendk | — | immutability feature for ransomware protection (Object Lock) | 同上。kenkendk は「`--soft-delete-prefix` も今はあり、削除の権限を与えない要望も満たす」と追記 |
| #6190 | 2026-10-31 | COMPLETED | kenkendk | — | Check if any other backup is using the same destination | `ISSUE-TRIAGE-REPORT.md` の付録だけ。kenkendk「filelist のタイムスタンプを見て、保存先のデータで避けるようにした」 |
| #6214 | 2026-10-31 | COMPLETED | kenkendk | — | Docker Image upgrade and Password reset | 10-31 の bug ラベルの判定で EXTERNAL/NOT-A-BUG。kenkendk「解決したと思う、続くなら新しい Issue を」 |
| #6216 | 2026-10-31 | COMPLETED | kenkendk | — | Automatic code coverage reporting | 付録だけ。kenkendk「しばらく試したが、うるさく広告だらけだった」 |
| #7543 | 2026-10-30 | COMPLETED | kenkendk | [`3df0f8b2`](https://github.com/duplicati/duplicati/commit/3df0f8b273)（#7647、自分の PR） | Drive died and Duplicati just wiped my whole backup | `fix/unreadable-source-stops-backup`、マージ済み |
| #7628 | 2026-10-30 | COMPLETED | kenkendk | #7648（自分の PR） | Stopping a backup during the file scan causes two problems | `fix/stop-before-processing-no-version`、マージ済み |
| #7629 | 2026-10-29 | DUPLICATE | Cyberchicken（報告者） | — | Stopping a backup during the file scan causes two problems | 10-31 の候補で「重複」 |
| #7630 | 2026-10-29 | DUPLICATE | Cyberchicken（報告者） | — | Alert when no backup has succeeded for N hours | 同上 |
| #7631 | 2026-10-29 | DUPLICATE | Cyberchicken（報告者） | — | Job editor: tabs with a Save button instead of a wizard | 同上 |

- 10-31 の閉じる依頼 5 件のうち、閉じたのは #3416・#4364 の 2 件。#4561・#1809・#2153 は open のままで、メンテナーの反応はまだない（10-31 夕方に確認）
