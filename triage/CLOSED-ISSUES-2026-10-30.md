# triage で扱った Issue のうち閉じられたもの（2026-10-30 に確認）

- 調べ方: `gh issue list --state closed --search "closed:>=2026-10-15"`（42 件）のうち、triage のどれかのファイルに番号が出てくるもの 25 件。閉じた人と、閉じた PR・コミットは GraphQL の `ClosedEvent`（`closer` が空なら手で閉じたもの）
- どれも stateReason は COMPLETED
- 自分がコメントしてから閉じられたもの: #4833（10-29 の投稿の直後）・#4535・#4318・#5210（10-24 の投稿）・#7298（10-03 の投稿）。これまでの投稿 32 件（下の「投稿の一覧」）のうち閉じたのは 10 件

| Issue | 閉じた日 | 閉じた人 | 閉じた PR・コミット | 題名 |
|---|---|---|---|---|
| #7454 | 2026-10-25 | kenkendk | #7552 | HTTP reporting: Failure of one endpoint prevents delivery to subsequen |
| #7298 | 2026-10-25 | kenkendk | — | [Bug fix/solution] RAM usage keeps increasing until 100% on Unraid |
| #7289 | 2026-10-22 | lambolighting | — | RAM usage keeps increasing until 100% on Unraid |
| #7251 | 2026-10-25 | kenkendk | — | Duplicati 2.3.0.4 on Windows Server 2022/2025 two annoying bugs |
| #7236 | 2026-10-25 | kenkendk | — | Retries a file upload forever |
| #7225 | 2026-10-25 | kenkendk | — | Restore does not work |
| #6872 | 2026-10-25 | kenkendk | — | longpolltime and LONGPOLL_TIMEOUT too long for HTTPS |
| #6867 | 2026-10-25 | kenkendk | — | TrayIcon status is not synchronized when awaking |
| #6831 | 2026-10-25 | kenkendk | — | Remote control claim never completes, machine stays in "click to claim |
| #6759 | 2026-10-19 | kenkendk | 8730ebd | Scheduled tasks do not start any more |
| #6748 | 2026-10-19 | kenkendk | #7464 | The database rebuild failed |
| #6042 | 2026-10-19 | kenkendk | #7462 | duplicati-2.1.0.5 Debian : cannot login to remote with Apache2 proxy o |
| #5976 | 2026-10-22 | kenkendk | — | Failure messages with `PRAGMA optimize` |
| #5210 | 2026-10-24 | Jojo-1000 | — | Incompatible NuGet packages for .NET 8 |
| #5175 | 2026-10-19 | kenkendk | #7466 | snapshot-policy USN plus attribute exclude may exclude all selected fi |
| #4992 | 2026-10-27 | kenkendk | #7584 | JQuery is significantly out of date with multiple XSS vulnerabilities  |
| #4833 | 2026-10-29 | kenkendk | — | Web UI is not shown after the installation (400 error) |
| #4818 | 2026-10-19 | kenkendk | ec521a4 | Fail if --restore-path has no path |
| #4535 | 2026-10-26 | kenkendk | — | Replace custom web server with Kestrel implementation |
| #4523 | 2026-10-26 | kenkendk | #7585 | Create separate issues for TODO-DNC markers |
| #4318 | 2026-10-26 | kenkendk | — | Backups flagged as "Warning" because Duplicati mistakenly thinks the b |
| #3948 | 2026-10-28 | kenkendk | #7574 | No site ID was provided while using Sharepoint V2 |
| #3848 | 2026-10-19 | kenkendk | #7461 | Symlinks get restored owned by root instead of actual user |
| #3605 | 2026-10-26 | kenkendk | #7583 | Mail not sent after run-script fails |
| #2171 | 2026-10-19 | kenkendk | 53ad17e | Errors on symlinks created with WSL |

補足:
- #4992（jQuery の XSS）は kenkendk の #7584（ログインとサインインのページから jQuery を外す）で閉じられた。PR 未作成の `chore/ngax-remove-jquery`（ngax 本体から jQuery を外す、「Related to #4992」）は残る作業なので、PR の本文の参照は「Related to #4992」のまま（閉じた Issue への参照になる）
- `stale-issues-2026-10-24.md` で (C)「まだ起きる」とした #3605・#3948・#4523・#4992 は、どれもその後の PR（#7583・#7574・#7585・#7584）で閉じられた
- 前に `IMPLEMENTATION-CANDIDATES` や `PENDING-BRANCHES` に「OPEN のまま」と書いた Issue のうち、#3848・#2171・#6748・#6042・#5175・#4818・#6759 は 10-19 に閉じられた

## 投稿の一覧（2026-10-30 時点の状態）

| Issue | 投稿 | 状態 |
|---|---|---|
| #2004 | https://github.com/duplicati/duplicati/issues/2004#issuecomment-5974796787 | closed (2026-10-05) |
| #2298 | https://github.com/duplicati/duplicati/issues/2298#issuecomment-6506581860 | open |
| #2650 | https://github.com/duplicati/duplicati/issues/2650#issuecomment-5974794669 | open |
| #2949 | https://github.com/duplicati/duplicati/issues/2949#issuecomment-5974794392 | open |
| #3038 | https://github.com/duplicati/duplicati/issues/3038#issuecomment-5974796272 | closed (2026-10-05) |
| #3530 | https://github.com/duplicati/duplicati/issues/3530#issuecomment-5974796059 | open |
| #3738 | https://github.com/duplicati/duplicati/issues/3738#issuecomment-6378533638 | open |
| #4045 | https://github.com/duplicati/duplicati/issues/4045#issuecomment-6506581258 | open |
| #4103 | https://github.com/duplicati/duplicati/issues/4103#issuecomment-5974795677 | open |
| #4220 | https://github.com/duplicati/duplicati/issues/4220#issuecomment-5974793294 | closed (2026-10-05) |
| #4318 | https://github.com/duplicati/duplicati/issues/4318#issuecomment-6383094967 | closed (2026-10-26) |
| #4468 | https://github.com/duplicati/duplicati/issues/4468#issuecomment-5974795149 | open |
| #4532 | https://github.com/duplicati/duplicati/issues/4532#issuecomment-6384134855 | open |
| #4534 | https://github.com/duplicati/duplicati/issues/4534#issuecomment-6384136350 | open |
| #4535 | https://github.com/duplicati/duplicati/issues/4535#issuecomment-6384135596 | closed (2026-10-26) |
| #4536 | https://github.com/duplicati/duplicati/issues/4536#issuecomment-6378533060 | open |
| #4545 | https://github.com/duplicati/duplicati/issues/4545#issuecomment-6384137657 | open |
| #4546 | https://github.com/duplicati/duplicati/issues/4546#issuecomment-6384137015 | open |
| #4554 | https://github.com/duplicati/duplicati/issues/4554#issuecomment-6383094376 | open |
| #4627 | https://github.com/duplicati/duplicati/issues/4627#issuecomment-6506061707 | open |
| #4636 | https://github.com/duplicati/duplicati/issues/4636#issuecomment-6378532691 | open |
| #4792 | https://github.com/duplicati/duplicati/issues/4792#issuecomment-5974794035 | open |
| #4833 | https://github.com/duplicati/duplicati/issues/4833#issuecomment-6506062588 | closed (2026-10-29) |
| #4846 | https://github.com/duplicati/duplicati/issues/4846#issuecomment-5974794873 | open |
| #5007 | https://github.com/duplicati/duplicati/issues/5007#issuecomment-5974792575 | open |
| #5087 | https://github.com/duplicati/duplicati/issues/5087#issuecomment-5970133908 | closed (2026-10-06) |
| #5113 | https://github.com/duplicati/duplicati/issues/5113#issuecomment-5970133589 | open |
| #5210 | https://github.com/duplicati/duplicati/issues/5210#issuecomment-6378533299 | closed (2026-10-24) |
| #5398 | https://github.com/duplicati/duplicati/issues/5398#issuecomment-5970133212 | open |
| #6535 | https://github.com/duplicati/duplicati/issues/6535#issuecomment-5970134929 | closed (2026-10-03) |
| #6744 | https://github.com/duplicati/duplicati/issues/6744#issuecomment-5970134390 | open |
| #7298 | https://github.com/duplicati/duplicati/issues/7298#issuecomment-5970135504 | closed (2026-10-25) |
