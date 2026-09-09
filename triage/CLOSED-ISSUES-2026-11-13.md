# triage で扱った Issue のうち閉じられたもの（2026-11-13 に確認）

- 調べ方: `gh search issues --commenter JamBalaya56562 --state closed` で 10-24 以降に閉じられたものは 24 件。10-31 までの 7 件は `CLOSED-ISSUES-2026-10-30.md`・`CLOSED-ISSUES-2026-10-31.md` に記録済みなので、ここには 11-09 以降の 17 件を書く。閉じた人と閉じたコミット・PR は GraphQL の `ClosedEvent`（`closer` が空なら手で閉じたもの）。17 件とも COMPLETED
- 利用者の報告「メンテナーがコメントした Issue を閉じてくれた」を受けて確認（225）

| Issue | 閉じた日 | 閉じた人 | 閉じたコミット・PR | 題名 | triage での扱い |
|---|---|---|---|---|---|
| [#2496](https://github.com/duplicati/duplicati/issues/2496) | 2026-11-13 | kenkendk | — | Pushover as alternative to XMPP or email reporting | 11-13 に閉じる依頼（`issue-drafts/enhancement-close-2026-11-13-b.md`）、同じ日に閉じられた |
| [#2590](https://github.com/duplicati/duplicati/issues/2590) | 2026-11-13 | kenkendk | — | Cloud providers as source data | 11-12 に閉じる依頼（`issue-drafts/enhancement-close-ui-2026-11-13.md`） |
| [#2811](https://github.com/duplicati/duplicati/issues/2811) | 2026-11-13 | kenkendk | — | Improved advanced options editor | 11-12 に閉じる依頼、kenkendk「Yes, lets close it.」 |
| [#4681](https://github.com/duplicati/duplicati/issues/4681) | 2026-11-13 | kenkendk | — | Option for In-Progress Backup Display | 11-12 に閉じる依頼（`enhancement-close-ui-2026-11-13.md`） |
| [#4098](https://github.com/duplicati/duplicati/issues/4098) | 2026-11-13 | kenkendk | — | Locked files exclusion | 11-12 に閉じる依頼。kenkendk「suppress で要望は満たす。ただロックされたファイルを無視するのは危ない。サービスで動かすか、ロックされると分かっているファイルを除外するほうがよい。無視するチェックボックスは作りたくない」 |
| [#1174](https://github.com/duplicati/duplicati/issues/1174) | 2026-11-13 | kenkendk | — | Display current task in status | 11-12 に閉じる依頼、kenkendk「今は詳細を出す状態のページもある」 |
| [#2185](https://github.com/duplicati/duplicati/issues/2185) | 2026-11-13 | kenkendk | — | Advanced options cannot be set when restoring files | 11-12 に閉じる依頼（`enhancement-close-ui-2026-11-13.md`） |
| [#3292](https://github.com/duplicati/duplicati/issues/3292) | 2026-11-12 | mnaiman（報告者） | — | SQLite WAL & Memory mapped files - performance | 11-12 に閉じる依頼（`enhancement-close-2026-11-13.md`）、報告者が閉じた |
| [#7783](https://github.com/duplicati/duplicati/issues/7783) | 2026-11-12 | kenkendk | [`ac8c61e949f4ddd22a39fa342f0fd1d102b3be76`](https://github.com/duplicati/duplicati/commit/ac8c61e949f4ddd22a39fa342f0fd1d102b3be76)（#7785、自分の PR） | Sync copy mode skips remote SFTP/SMB source with SourceRootMissing | `fix/sync-remote-source-root`、マージ済み |
| [#6863](https://github.com/duplicati/duplicati/issues/6863) | 2026-11-12 | kenkendk | [`90326c13c8e119617415bd049670bb171b7e2a4a`](https://github.com/duplicati/duplicati/commit/90326c13c8e119617415bd049670bb171b7e2a4a)（#7784、自分の PR） | Restored parent directory ownership does not match original | `fix/record-folder-of-file-source`、マージ済み |
| [#7024](https://github.com/duplicati/duplicati/issues/7024) | 2026-11-10 | kenkendk | #7757（自分の PR） | Ability to send emails in html format | マージで閉じた |
| [#7474](https://github.com/duplicati/duplicati/issues/7474) | 2026-11-09 | kenkendk | #7733（自分の PR） | Drime backup failing: more unique active IDs | マージで閉じた（machpa への返事待ちとしていたもの） |
| [#7737](https://github.com/duplicati/duplicati/issues/7737) | 2026-11-09 | kenkendk | [`1b6ae9c2c2b507d5050b254d60d7fb11310abe5e`](https://github.com/duplicati/duplicati/commit/1b6ae9c2c2b507d5050b254d60d7fb11310abe5e)（#7738、自分の PR） | DrimePaginationException on Drime Sync | マージで閉じた |
| [#4407](https://github.com/duplicati/duplicati/issues/4407) | 2026-11-09 | kenkendk | — | web UI isn't functional if system locale isn't set | 11-08 にコメント（`OLD-ISSUES-2026-11-07.md`）、kenkendk「Kestrel になったので起きない」 |
| [#4635](https://github.com/duplicati/duplicati/issues/4635) | 2026-11-09 | kenkendk | — | Warning exist when trying to restore file | 11-08 にコメント、kenkendk「長く報告がないので直ったとみなす」 |
| [#3194](https://github.com/duplicati/duplicati/issues/3194) | 2026-11-09 | kenkendk | — | Canary 2.0.3.6 and slow queries | 11-08 にコメント、kenkendk「たぶん直った、2023 年から報告もない」 |
| [#4645](https://github.com/duplicati/duplicati/issues/4645) | 2026-11-09 | kenkendk | — | Backup gets stuck executing a query | 11-08 にコメント、kenkendk「統計の更新で直ったはず」 |

- 11-12・11-13 に出した enhancement の閉じる依頼で閉じたのは #2496・#2590・#2811・#4681・#4098・#1174・#2185・#3292 の 8 件（ほかは open のまま、下書き 3 本の先頭に一覧）
- 11-08 の古い Issue へのコメントで閉じたのは #4407・#4635・#3194・#4645 の 4 件
- 自分の PR のマージで閉じたのは #7783・#6863・#7024・#7474・#7737 の 5 件
