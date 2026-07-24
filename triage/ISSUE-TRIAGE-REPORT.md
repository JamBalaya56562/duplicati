# Duplicati Open Issue トリアージ調査レポート

- **対象リポジトリ**: [duplicati/duplicati](https://github.com/duplicati/duplicati)（upstream）
- **調査日**: 2026-07-05
- **対象**: Open Issue **全647件**（作成日 2014-08-05 〜 2026-07-03）
- **現行リリース**: 2.3.0.106 canary（2026-07-03、`changelog.txt` 先頭より）
- **目的**: triage — ①コメントのみで close できる Issue を特定して投稿文案を用意、②実装で解決できる候補を洗い出す

> このレポートは「メタデータによる全件自動分類」＋「close/実装の有力候補を並列サブエージェントで個別スレッド精読」の二段構えで作成しています。Verdict は保守的に付与しており、実際の close/投稿前には各 Issue の最終確認を推奨します。

> **更新履歴 (2026-07-12)**: 初版（2026-07-05）以降に GitHub でクローズされた、本レポート掲載の 9 件を削除しました — 解決済み(COMPLETED): #2287, #1698, #7000, #6881 / 見送り(NOT_PLANNED): #5298, #5299, #5305, #5311, #5339。削除は §3.4 表・§4 詳細・§5 付録に反映し、隣接するバケット/表の件数も実数へ更新しています。§1 のサマリー統計（バケット別内訳・ラベル分布・年代分布）と §2 の方法論記述は初版スナップショットのまま据え置きです（本注記で補足）。同期間にクローズされた他 11 件（#4812, #6205, #6426 など）は元々本レポート未掲載のため対象外です。

> **更新履歴 (2026-07-16)**: 前回更新（2026-07-12）以降に GitHub でクローズされた、本レポート掲載の 2 件を削除しました（いずれも 2026-07-13 に COMPLETED でクローズ）— #314「Add parity file support」（§5 付録 enhancement バックログ）、#2717「Windows Service fails to start」（§3.4 表・§4.3 詳細・§5 付録 reproduced）。削除に伴い §3.4（18→17 件）・§5 付録 reproduced（12→11 件）・enhancement バックログ（171→170 件）・付録合計（632→630 件）の件数を更新しました。§1 のサマリー統計と §2 の方法論記述は従来どおり初版スナップショットのまま据え置きです。

---

## 1. エグゼクティブサマリー

647 件は 10 年以上分の在庫で、2016〜2018 年作成が最多です。最終更新は 2024〜2025 年に集中しており（407 件）、近年 upstream 側で一括ラベル整理・棚卸しが行われた形跡があります。約半数（340 件）はコメント 0〜2 件で議論が浅く、triage の余地が大きい状態です。

### バケット別内訳（全647件・自動分類）

| 分類 | バケット | 件数 |
|---|---|---:|
| **A. コメントのみで close 候補** | 重複ラベル | 1 |
| | pending user feedback（返信待ち→無反応 close） | 16 |
| | stale ラベル | 1 |
| | question（回答して close） | 3 |
| | 2017 年以前・低活動（stale close） | 24 |
| | **小計** | **45** |
| **B. 実装で解決できる候補** | reproduced（再現確認済みバグ） | 15 |
| | good first issue | 3 |
| | minor change | 31 |
| | **小計** | **49** |
| **C. 通常バックログ** | その他 bug | 68 |
| | enhancement | 171 |
| | UI 改善 | 9 |
| **D. 未整理** | **ラベル無し（要トリアージ）** | **250** |
| | その他 | 55 |
| | **合計** | **647** |

### ラベル分布（上位）

| 件数 | ラベル |
|---:|---|
| 226 | enhancement |
| 86 | bug |
| 68 | UI |
| 33 | help wanted |
| 33 | minor change |
| 21 | backend enhancement |
| 21 | performance issue |
| 18 | core logic |
| 16 | pending user feedback |
| 15 | reproduced |
| 13 | documentation / new backend |
| — | （`good first issue` 3、`question` 4、`duplicate` 1、`stale` 1 など） |

- **ラベル無し 250 件**が最大の未整理領域。うち **122 件が 2024〜2026 年作成**で、比較的新しく現行版でも有効な可能性が高いため、優先的なラベリング対象。

### 年代分布

| 作成年 | 件数 | | 最終更新年 | 件数 |
|---|---:|---|---|---:|
| 2014 | 21 | | 2017 | 34 |
| 2015 | 14 | | 2018 | 35 |
| 2016 | 56 | | 2019 | 20 |
| 2017 | 114 | | 2020 | 23 |
| 2018 | 92 | | 2021 | 32 |
| 2019 | 47 | | 2022 | 33 |
| 2020 | 39 | | 2023 | 25 |
| 2021 | 37 | | 2024 | 116 |
| 2022 | 38 | | 2025 | 292 |
| 2023 | 13 | | 2026 | 38 |
| 2024 | 74 | | | |
| 2025 | 84 | | | |
| 2026 | 19 | | | |

---

## 2. 調査方法

1. `gh issue list --repo duplicati/duplicati --state open --limit 700` で取得したメタデータ（番号・タイトル・ラベル・作成/更新日・コメント数・作者・マイルストーン）から、close 済みの 4 件を除外して全 647 件に更新。
2. Python で label + 年代 + コメント数のヒューリスティックにより 13 バケットへ自動分類（本レポート §1、全件は §5 Appendix）。
3. close 有力候補（`pending user feedback` / `question` / `duplicate` / `stale` / 2017 年以前低活動）と実装候補（`reproduced` / `good first issue` / `minor change`）、および最近のバグ（2025 年）計 66 件を、7 並列のサブエージェントで **全コメントスレッドを個別精読**。各 Issue で修正済みかを `changelog.txt` と照合し、Verdict・投稿文案・実装メモを付与（§3、§4）。

### Verdict 凡例

| Verdict | 意味 | 推奨アクション |
|---|---|---|
| `CLOSE_FIXED` | 新しいバージョンで修正済み | コメントして close |
| `CLOSE_DUPLICATE` | 他 Issue の重複 | 参照コメントして close |
| `CLOSE_STALE` / `CLOSE_DONE` | 陳腐化 / 既に実装済み | コメントして close |
| `CLOSE_NOREPLY` | 情報提供依頼に長期間無反応 | 無反応 close |
| `ANSWER` | 質問に回答可能 | 回答コメント（→解決なら close） |
| `IMPLEMENT` | 実装で解決すべき | 実装 |
| `KEEP_OPEN` | 有効・継続 | 維持（要ラベル） |
| `NEEDS_INFO` | 追加情報が必要 | 情報依頼 |

## 3. トリアージ判定サマリー（深掘り 66件）

close 有力候補・実装候補・確認済みバグを中心に 66 件のスレッドを個別精読しました。各カテゴリの表で全体像を、§4 に 1 件ごとの詳細所見と投稿文案（英語ドラフト）を掲載します。

### 3.1 即 close 可能（コメントして閉じる）── 35 件

投稿文案は §4 の各 Issue ブロックに用意しています。多くは「現行版で修正済み／実装済み」または「長期無反応・陳腐化」です。

| # | Verdict | 確度 | 根拠（要約） |
|---|---|---|---|
| [3320](https://github.com/duplicati/duplicati/issues/3320) | FIXED | 高 | recreate 進捗バーのレイアウトバグは PR #3192 で修正、UI も刷新済み |
| [2620](https://github.com/duplicati/duplicati/issues/2620) | FIXED | 高 | HTTP timeout 設定は `--read-write-timeout` 等で実装済み（TimeoutOptionsHelper） |
| [2846](https://github.com/duplicati/duplicati/issues/2846) | FIXED | 高 | ログファイルへのタイムスタンプ付与は実装済み（LogEntry.ToString） |
| [4631](https://github.com/duplicati/duplicati/issues/4631) | FIXED | 高 | auto-cleanup の "database is locked" は PreBackupVerify の DB 破棄＋WAL 既定化で解消 |
| [3445](https://github.com/duplicati/duplicati/issues/3445) | FIXED | 高 | force-stop 後のロックは Thread.Abort 廃止＋async cancelable SQLite で解消 |
| [3027](https://github.com/duplicati/duplicati/issues/3027) | FIXED | 高 | メールPWは ArgumentType.Password でマスク表示に |
| [2800](https://github.com/duplicati/duplicati/issues/2800) | STALE | 高 | 旧 OneDrive4Business の ID/PW 認証は廃止、現在は OneDrive v2(OAuth) |
| [2859](https://github.com/duplicati/duplicati/issues/2859) | STALE | 高 | 2017 canary、Amazon Cloud Drive(消滅)＋旧 OneDrive API が対象 |
| [2351](https://github.com/duplicati/duplicati/issues/2351) | NOREPLY | 高 | 報告者自身が「close して」と発言、フルバックアップで解消済み |
| [6198](https://github.com/duplicati/duplicati/issues/6198) | ANSWER | 高 | タイムゾーン質問は回答済み・報告者了承済み |
| [5908](https://github.com/duplicati/duplicati/issues/5908) | ANSWER | 高 | FTP TLS session reuse は .NET SslStream の上流制約（修正不可）→既知の制約として close |
| [4714](https://github.com/duplicati/duplicati/issues/4714) | STALE | 中 | カスタムビルドでの Jottacloud OAuth、現在は OAuthUrl が第一級オプション |
| [3011](https://github.com/duplicati/duplicati/issues/3011) | STALE | 中 | 2018 の旧 About ページ、UI 刷新済み |
| [4001](https://github.com/duplicati/duplicati/issues/4001) | FIXED | 中 | 宛先事前選択の race、新 Angular UI で修正済み |
| [3853](https://github.com/duplicati/duplicati/issues/3853) | FIXED | 中 | 0001-01-01 表示は BackendStatistics 由来、シリアライザで除外済み |
| [4405](https://github.com/duplicati/duplicati/issues/4405) | STALE | 中 | 旧 ngax の S3 SDK 表示バグ、UI 刷新済み |
| [2663](https://github.com/duplicati/duplicati/issues/2663) | FIXED | 中 | 一時ファイル削除の warning は DeleteOperation 改修で解消 |
| [2556](https://github.com/duplicati/duplicati/issues/2556) | STALE | 中 | WebDAV PROPFIND 解析を改善済み、8 年無反応 |
| [2641](https://github.com/duplicati/duplicati/issues/2641) | STALE | 中 | 旧 AWSSDK ハッシュ由来、S3 stack 刷新済み、18ヶ月無反応 |
| [2690](https://github.com/duplicati/duplicati/issues/2690) | STALE | 中 | blank page、原因は複数の無関係要因、UI 刷新済み |
| [2363](https://github.com/duplicati/duplicati/issues/2363) | ANSWER | 中 | GUI→CLI の質問は回答済み（Export as command-line） |
| [3419](https://github.com/duplicati/duplicati/issues/3419) | STALE | 中 | 2018 macOS Gatekeeper/署名(Mono .pkg)、現在は .NET8 署名済 pkg |
| [4208](https://github.com/duplicati/duplicati/issues/4208) | STALE | 中 | 要望だが報告者が close に同意済み |
| [2493](https://github.com/duplicati/duplicati/issues/2493) | DONE | 中 | %result% 引用符問題は JSON/Template 出力形式で解決 |
| [2903](https://github.com/duplicati/duplicati/issues/2903) | DONE | 中 | メールのパス漏洩は既定で redaction、Template 形式も追加 |
| [6110](https://github.com/duplicati/duplicati/issues/6110) | FIXED | 中 | recreate の ConstraintException、missing-blocks/empty-index 修正済み |
| [6076](https://github.com/duplicati/duplicati/issues/6076) | FIXED | 中 | auth token refresh クラッシュ、複数の refresh 修正済み |
| [5976](https://github.com/duplicati/duplicati/issues/5976) | FIXED | 中 | PRAGMA optimize は無害な warning、経路をガード済み |
| [6051](https://github.com/duplicati/duplicati/issues/6051) | FIXED | 中 | "Unexpected difference" は #6529(--changed-files) で修正済み |
| [5999](https://github.com/duplicati/duplicati/issues/5999) | DUPLICATE | 中 | 修正済み #5943（メタデータ誤検出）の重複 |
| [6101](https://github.com/duplicati/duplicati/issues/6101) | NEEDS_INFO | 中 | UI stuck、websocket 層を大幅改修、再現不能→likely-addressed で close |
| [4696](https://github.com/duplicati/duplicati/issues/4696) | NOREPLY | 中 | Wasabi root フォルダ、報告者が再テスト約束も 1.5 年放置 |
| [5621](https://github.com/duplicati/duplicati/issues/5621) | ANSWER | 中 | pCloud WebDAV の socket 切断、native pCloud backend へ誘導 |
| [3429](https://github.com/duplicati/duplicati/issues/3429) | ANSWER | 中 | Backup_Begin フェーズの質問は回答済み（曖昧な UX 要望のみ残存） |

### 3.2 現行版/新 UI で要再検証（リテスト依頼して当面 keep）── 5 件

旧 `ngax` UI やスケジューラで確認されたバグで、その後 UI/該当機能が大幅に書き換えられているもの。close ではなく「新 UI での再現確認を依頼するコメント」を推奨（文案は §4）。

| # | Verdict | 確度 | 概要 |
|---|---|---|---|
| [3483](https://github.com/duplicati/duplicati/issues/3483) | NEEDS_INFO | 高 | restore で子展開前に top チェック不可（旧 ngax）→ 新 ngclient で要再現確認 |
| [2604](https://github.com/duplicati/duplicati/issues/2604) | NEEDS_INFO | 高 | commandline のフィールド値ずれ（旧 ngax）→ 新 ngclient で要再現確認 |
| [2487](https://github.com/duplicati/duplicati/issues/2487) | NEEDS_INFO | 中 | 曜日変更で次回実行が再計算されない → 改修後スケジューラで要再現確認 |
| [2616](https://github.com/duplicati/duplicati/issues/2616) | NEEDS_INFO | 低 | FTP 接続失敗のメッセージ不明瞭 → FluentFTP 移行後で要再現確認 |
| [2654](https://github.com/duplicati/duplicati/issues/2654) | NEEDS_INFO | 低 | バックアップ中の restore のエラーメッセージ → queue runner 導入後で要再現確認 |

### 3.3 実装で解決できる候補 ── 1 件

スコープが明確な小〜中規模の変更。

| # | 規模 | 確度 | 対象ファイル / 概要 |
|---|---|---|---|
| [6448](https://github.com/duplicati/duplicati/issues/6448) | S–M | 中 | スケジュール編集に人間可読の要約文（"Run every day at 00:00"）を表示（ngclient） |

> #6448 は UI 系で、対象が新 `ngclient`（別リポジトリ ShipUI 由来、本チェックアウトに編集可能ソースなし）にあるため、着手前に配置確認が必要です。

### 3.4 維持推奨（有効なバグ・要望。将来の実装対象）── 17 件

close せず維持すべきもの。確認済みバグには §4 に根本原因と対象ファイルのメモを付けています。

| # | 種別 | 概要（将来対応の手がかり） |
|---|---|---|
| [6461](https://github.com/duplicati/duplicati/issues/6461) | バグ | abort 後にバックアップが停止しない（stop 改修後も残存、maintainer 報告） |
| [2074](https://github.com/duplicati/duplicati/issues/2074) | バグ | restore で not-associated-blocks（データ整合性、要 2.3.x 再検証） |
| [6032](https://github.com/duplicati/duplicati/issues/6032) | バグ | 無作業時 100% CPU（上流 Avalonia TrayIcon、12.0.2 で要再検証） |
| [6440](https://github.com/duplicati/duplicati/issues/6440) | バグ | Win Server 2019 で断続クラッシュ（診断進行中） |
| [5593](https://github.com/duplicati/duplicati/issues/5593) | バグ | macOS Sequoia メモリリーク（#4589 と重複領域） |
| [5846](https://github.com/duplicati/duplicati/issues/5846) | バグ | 重複ファイル名の扱い改善（maintainer 起票、要仕様） |
| [4041](https://github.com/duplicati/duplicati/issues/4041) | 性能 | DB recreate の改善（継続トラッキング、修正進行中） |
| [3733](https://github.com/duplicati/duplicati/issues/3733) | 性能 | 大容量 restore の断片化（設計課題、調査中） |
| [3060](https://github.com/duplicati/duplicati/issues/3060) | 要望 | 中断バックアップの自動再開（未実装） |
| [2467](https://github.com/duplicati/duplicati/issues/2467) | 要望 | 拡張子別ファイルサイズ分析（未実装、kenkendk 賛同） |
| [2504](https://github.com/duplicati/duplicati/issues/2504) | 要望 | AWS AssumeRole 対応（S3 backend 未対応） |
| [2612](https://github.com/duplicati/duplicati/issues/2612) | 要望 | Win 通知クリックで起動（NotifyUser がスタブ） |
| [2667](https://github.com/duplicati/duplicati/issues/2667) | 要望 | モバイルクライアント（未実装） |
| [2669](https://github.com/duplicati/duplicati/issues/2669) | 要望 | ソースから消えたファイルのみ表示（未実装） |
| [2838](https://github.com/duplicati/duplicati/issues/2838) | 要望 | ネイティブ環境変数構文 `$VAR`/`${VAR}`（Windows `%VAR%` のみ、TODO 残存） |
| [5527](https://github.com/duplicati/duplicati/issues/5527) | 要望 | ファイル単位で時刻チェック無効化（設計方針合意、仕様未確定） |
| [2885](https://github.com/duplicati/duplicati/issues/2885) | 要望 | import が DBPath を尊重しない（設計、UX 検討中） |

（※上記に加え、深掘り対象外だが維持が妥当な `enhancement`/`bug` バックログが多数。§5 Appendix 参照）

## 4. 詳細所見と投稿文案（全深掘り Issue）

各 Issue の Verdict・根拠・投稿文案（英語ドラフト）・実装メモ。調査バッチ（テーマ）ごとにまとめています。Issue 番号で検索可能です。


### 4.1 pending user feedback（返信待ち・議論の深い案件）

### #4041 — Database recreate desperately needs improvement
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: high
- **Last activity**: 2024-01-14 by gpatel-fr (maintainer)
- **Rationale**: Long-lived, actively-worked performance tracking issue (70 comments). Real fix landed in 2.0.7.100 (skip expensive per-block queries for undamaged blocks); further recreate/restore work continued through 2.1.x–2.3.x (new restore engine, empty-index handling, "Handle missing blocks on recreate"). Legitimate open tracking issue.

### #3320 — Recreate database layout bug
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024-01-17 by ts678 (collaborator), proposing to close
- **Rationale**: Reporter confirmed original progress-bar layout bug fixed via PR #3192. Only a minor button-layout nit remained; UI since fully replaced by new ngclient.
- **Draft comment**: The original recreate/restore progress-bar layout bug reported here was confirmed fixed (via PR #3192), and the UI has since been fully replaced by the new interface in the 2.1.x/2.3.x releases. The only remaining item was a minor button-alignment nit. Closing this as resolved — if the button layout is still off in a current release, please open a fresh issue with a screenshot. Thanks!

### #3733 — Large file restore causes large fragmentation and unnecessary IO
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2024-01-17 by ts678 (collaborator)
- **Rationale**: Genuine, still-valid design limitation (dblock-driven restore scatters writes → fragmentation). Last activity is the maintainer researching remedies; a new restore engine landed afterward that may change this. Keep open as design/enhancement item.

### #3060 — Feature request: automatically resume interrupted backup
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2024-01-19 by maxammann (commenter)
- **Rationale**: Legitimate, still-unimplemented enhancement with community interest. Duplicati still restarts the whole backup at next run rather than auto-resuming mid-stream. The "close imho" is soft and from a non-reporter. Keep as low-priority enhancement.

### #2800 — OneDrive 4 Business - The password has expired
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024-01-22 by ts678 (collaborator); no reporter reply since
- **Rationale**: Concerns the legacy OneDrive-for-Business username/password backend. Microsoft retired that auth path; Duplicati now uses OneDrive v2 (Graph / OAuth), eliminating the password-expiry failure class. Obsolete/stale.
- **Draft comment**: This report is about the legacy OneDrive-for-Business backend using username/password auth. Microsoft has since retired that authentication path, and Duplicati now uses the OneDrive v2 backend (Microsoft Graph API with OAuth), which avoids the password-expiry problem entirely. Since this predates that change and there's been no further activity, I'm closing it as obsolete. If you hit an auth problem on the current OneDrive v2 backend, please open a new issue. Thanks!

### #4696 — Wasabi "The requested folder does not exist"
- **Verdict**: CLOSE_NOREPLY
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-03-07 (bot); last human = reporter promised to re-test, never did
- **Rationale**: Maintainers couldn't reproduce root-of-bucket behavior on other S3; reporter committed to re-testing on latest release "and report back" but never did. ~1.5+ years awaiting promised feedback.
- **Draft comment**: Thanks for the report. We weren't able to reproduce the root-of-bucket "folder does not exist" behavior on other S3-compatible backends, and the plan was for you to re-test with a current release and report back — but we haven't heard since. The S3/backend handling has changed considerably in 2.1.x/2.3.x, so this may behave differently now. Closing due to inactivity; please reopen or file a fresh issue with results from a current release if you can still reproduce it. Thanks!

### #5621 — Fatal error SocketException: The socket has been shut down
- **Verdict**: ANSWER
- **Action**: answer-comment
- **Confidence**: med
- **Last activity**: 2025-01-05 (bot); last human = ts678 pointing to native pCloud backend
- **Rationale**: All affected reporters back up to pCloud over WebDAV; socket-shutdown is a known pCloud WebDAV symptom. Duplicati now ships a native pCloud backend (2.1.x canary) bypassing WebDAV. Answerable / close-as-addressed.
- **Draft comment**: The "socket has been shut down" errors here are all against pCloud over WebDAV, which is known to be unreliable. Duplicati has since added a native pCloud backend (no WebDAV) in recent releases, with subfolder support. Please update and reconfigure the destination to use the native "pCloud" backend instead of WebDAV — that should resolve these errors. If it persists on the native backend, let us know and we'll reopen. Closing as addressed by the native pCloud backend.

### #2859 — RemoteOperationDelete hangs in Canary 2017-10-20
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024-01-30 by ts678 (collaborator); no reporter reply
- **Rationale**: Hang reported on a 2017 canary against Amazon Cloud Drive (defunct) and classic OneDrive API (retired). Both backends gone; abort/stop mechanism reworked. Obsolete/stale.
- **Draft comment**: This hang was reported on a 2017 Canary build against Amazon Cloud Drive (since shut down) and the classic OneDrive API (retired by Microsoft). Both backends no longer exist, and stop/abort handling has been reworked — the current UI offers clean "Stop after current file" / "Stop now" options. With no way to reproduce on a supported backend and no further activity, closing as obsolete. If you see a comparable delete hang on a current release, please open a new issue with logs. Thanks!


### 4.2 pending user feedback / 質問（続き）

### #2556 — second backup to webdav not works, but the first works fine
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2017-07-03 by sunwayru (reporter); no reply since
- **Rationale**: Root cause was WebDAV PROPFIND parsing returning an empty list from Yandex. Changelog: "Improved parsing of WebDAV PROPFIND messages to cover more servers". 8-year-old report, reporter never confirmed.
- **Draft comment**: Thanks for the detailed PROPFIND capture back in 2017. Since then the WebDAV backend's PROPFIND parsing has been substantially reworked to handle more servers, and `--debug-propfind-file` is still available for diagnosis. As this is very old and predates that rework, closing as stale. If you still see an empty remote list on a second WebDAV backup with a current 2.3.x release, please open a new issue with a fresh `--debug-propfind-file` capture.

### #2641 — error "Expected hash not equal to calculated hash" (Wasabi/S3)
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-01-30 by ts678 (collaborator); no user reply since
- **Rationale**: Error originated in old bundled AWSSDK HashStream. S3 stack heavily reworked since (precomputed upload hashes, lowercased content hash, AWSSDK updates). 2024 confirmation request unanswered 18+ months.
- **Draft comment**: Closing as stale. This is from 2017 against a much older AWSSDK-based S3 implementation; the S3 backend has since been substantially reworked (precomputed upload hashes, updated AWS SDK, content-hash compatibility fixes). The 2024 follow-up asking whether anyone still hit this received no response. If you reproduce this on a current 2.3.x release against Wasabi/S3, please open a fresh issue with the full stack trace.

### #2690 — duplicati starts but the page is blank on load
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-02-08 by ts678 (collaborator); no user reply since
- **Rationale**: Mix of unrelated causes (browser cache, Firefox tracking protection, cookies) self-resolved by users. 2017 report on obsolete build; entire web UI since replaced.
- **Draft comment**: Closing as stale. This 2017 report accumulated several unrelated causes users resolved themselves (hard reload / clearing browser cache and cookies, a Firefox tracking-protection setting). The web UI has since been entirely rewritten in 2.1+/2.3, so the original code path no longer exists. If a blank page occurs on a current release, please open a new issue with browser, version, and any console/network errors.

### #2351 — backup hangs forever without no output
- **Verdict**: CLOSE_NOREPLY
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024-01-31 by ts678 (collaborator)
- **Rationale**: Reporter stated the problem disappeared after a fresh full backup, no longer reproducible, and himself suggested "Maybe close it for now and I will reopen." ts678 agreed. Consensual close.
- **Draft comment**: Closing per the reporter's own suggestion — the issue was resolved by a fresh full backup and is no longer reproducible, with insufficient information to investigate further. Please reopen or file a new issue if the hang recurs on a current release.

### #2074 — Restore Backup: Detected file entries with not associated blocks
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2024-02-08 by ts678 (collaborator)
- **Rationale**: Long (35-comment) thread about a real data-integrity symptom (missing files in restore / dangling block associations) with no confirmed fix for this specific condition. Substantive bug; best handled by maintainer re-test on 2.3.x, not a blind close.

### #6440 — Duplicate Crashes after some time on Windows Server 2019
- **Verdict**: NEEDS_INFO
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2025-08-04 by toinopt (reporter, actively responding)
- **Rationale**: Recent (2025) issue on 2.1.0.5, active reporter answering triage questions. Mid-diagnosis (NotFoundException on `/api/v1/filesystem/validate`, spontaneous crash) ~11 months ago. Awaiting next diagnostic step, not user silence.

### #6448 — Clarify that Daily Schedule / Run Again Every is a binary choice
- **Verdict**: IMPLEMENT
- **Action**: implement
- **Confidence**: med
- **Last activity**: 2025-08-08 by github-monkey (reporter)
- **Rationale**: Active UX discussion with kenkendk on the new schedule UI. Reporter suggested rendering a plain-language summary sentence from the schedule choices (e.g., "Run every day at 00:00"). Well-scoped UI enhancement.
- **Impl notes**: New Duplicati web UI (ngclient). Add a computed human-readable summary string to the schedule editor component reflecting anchor time + interval + excluded days. No backend/scheduler changes. Effort: S–M.

### #5593 — Memory Leak Sequoia 15.1
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2026-05-05 by JPar99 (asking for ETA)
- **Rationale**: Recently active (May 2026). The Linux VIRT/VSZ part was explained as normal .NET GC address-space reservation, but the macOS Sequoia RES-memory leak remains unconfirmed/unresolved. Overlaps with open #4589. Keep open.

### #6198 — question about Time Zone different
- **Verdict**: ANSWER
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2025-04-27 by chchia (reporter)
- **Rationale**: Pure question, fully answered by kenkendk (scheduler uses local/UTC conversion; UI follows container timezone). Reporter acknowledged "make sense, thanks."
- **Draft comment**: Glad the explanation helped. To summarize: the scheduler stores times in UTC and converts to the machine's local time (in Docker, whatever timezone the container is configured for), which is why the displayed schedule follows the container's timezone rather than the connecting client's OS timezone. Since the question is answered, closing — feel free to reopen if anything is still unclear.

### #2363 — using backup started from the UI in the commandline
- **Verdict**: ANSWER
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-02-18 by ts678 (collaborator)
- **Rationale**: Original question answered (Export → As Command-line; `--dbpath`; `help options`). Residual is a docs-improvement wish better tracked in the docs repo.
- **Draft comment**: The original question is answered: to reuse a GUI backup on the command line, use the job's Export → As Command-line (which lists every option and the correct target URL), and `--dbpath` lets you point at the GUI's local database. The remaining item is a docs request to document the `dbconfig.json` behavior in the User's Manual, best filed against the documentation repo. Closing as answered.


### 4.3 question / duplicate / stale / reproduced（混在バッチ）

### #3419 — When adding Duplicati to login items, it isn't launched on login
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2018-12-17 by daften
- **Rationale**: macOS Gatekeeper "damaged" quarantine issue from 2018 on old Mono/`.pkg` builds (disabling Gatekeeper "fixes" it = signing/quarantine problem). 2.3.0 ships re-architected .NET 8 macOS package with different signing/notarization. Mislabeled "duplicate" of #2614 (reporter rejected that). Really stale/unreproducible packaging issue.
- **Draft comment**: This report is from 2018 and concerns the old Mono-based macOS `.pkg` build. The symptoms (Gatekeeper reporting "damaged", resolved only by disabling Gatekeeper) point to a code-signing/quarantine-attribute problem in that package, not app logic. Duplicati has since moved to .NET 8 with a reworked, signed/notarized macOS package, so the original build can't be reproduced. Closing as stale — if you still hit "damaged and can't be opened" launching the current release from Login Items, please open a fresh issue with the version and `xattr -l /Applications/Duplicati.app` output.

### #4208 — Feature Request - Filter for recently deleted files to be kept in current backup set
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-01-29 by ts678
- **Rationale**: Feature request; reporter said "happy for this to be closed"; collaborator confirmed it doesn't fit current design ("could be a mess to implement"). Labeled stale; reporter consented.
- **Draft comment**: Thanks for the discussion. This "keep the last version of any deleted file" behavior doesn't fit Duplicati's current retention design and would be substantial to implement, and the OP indicated they're fine with closing. Development focus remains on bugs and core stability, so closing as stale. The underlying need overlaps with the "show all versions of a file" work (e.g. #72), and prior versions are searchable today via the CLI `find` command. If interest renews, this can be reopened or raised in the forum.

### #3429 — backup state/phases
- **Verdict**: ANSWER
- **Action**: answer-comment
- **Confidence**: med
- **Last activity**: 2024-02-06
- **Rationale**: Question/enhancement about the `Backup_Begin` phase + a vague "communicate better" UX ask. Pectojin answered the substance (lists/verifies backend files before counting local files). Remaining ask has no concrete spec.
- **Draft comment**: To summarize the `Backup_Begin` phase: before counting local files, Duplicati lists the backend files and runs a pre-backup verification of remote state, which is why `Backup_Begin` can sit a while with no local activity — on slow/high-latency backends this can take significant time. The newer ngclient UI (2.3.x) surfaces backend List/phase state more clearly than the 2018 UI. If you'd like more granular phase reporting, could you specify exactly which phases/counters you'd want surfaced? Otherwise this can remain a low-priority UI enhancement.

### #3483 — When restoring files the top level checkboxes cannot be selected until children are expanded
- **Verdict**: NEEDS_INFO
- **Action**: answer-comment (re-test on new UI)
- **Confidence**: high
- **Last activity**: 2024-01-17 by ts678 (reproduced on legacy UI)
- **Rationale**: Real, confirmed in legacy `ngax` — `restoreFilePicker.js` reads `p.children.length` before lazy load, throwing with multiple top-level roots. But 2.3.0 defaults to rewritten `ngclient` restore page (changelog: reworked tree-loading/folder-expansion). Code path likely gone; must re-verify.
- **Draft comment**: This was confirmed against the legacy `ngax` UI, where `restoreFilePicker.js` reads `node.children.length` before children are lazily loaded, throwing when you have multiple top-level roots (e.g. two drive letters). The default restore UI has since been rewritten (new `ngclient` in 2.3.x with reworked tree-loading). Could someone re-test on the current release: back up two separate top-level roots (e.g. `A:\` and `B:\Folder` via `subst`), go to Restore, and try checking a top-level box before expanding it? If it still fails we'll keep it open with a fresh repro; if it works, we can close.

### #2487 — scheduled Jobs are not updated after Change of weekday
- **Verdict**: NEEDS_INFO
- **Action**: answer-comment (re-test)
- **Confidence**: med
- **Last activity**: 2025-03-24 (label bump only); zero human comments since 2017
- **Rationale**: Bare zero-comment report from 2.0.1.53 (2017): changing allowed weekdays doesn't recompute next run (only changing time does). Scheduler/UI substantially reworked since (custom-schedule fixes, "show actual scheduled time", off-by-one/DST). Needs fresh repro on 2.3.0.
- **Draft comment**: Reported against 2.0.1.53 in 2017 with no verification since. The scheduler and schedule editor were substantially reworked (custom-schedule fixes, "show actual scheduled time", off-by-one/DST corrections, missed-backup ordering). Could someone re-test on 2.3.x: schedule a job for specific weekdays, then edit only the weekdays (not the time), and confirm "Next run" recalculates to the correct next matching day? If it still doesn't recompute we'll keep it open; otherwise close as fixed.

### #2604 — WebUI: commandline - some fields have the wrong value
- **Verdict**: NEEDS_INFO
- **Action**: answer-comment (re-test on new UI)
- **Confidence**: high
- **Last activity**: 2025-03-24 by ts678 (label bump)
- **Rationale**: Confirmed 2017 in legacy `ngax` "Edit as text" → list view: with >10 `--` params, switching back misassigns values (kenkendk + JonMikelV reproduced). Commandline/options UI rewritten in `ngclient` (changelog: "Fixed filters on Commandline page not being fully editable", "options missing from commandline view", "Export as commandline"). Re-test needed.
- **Draft comment**: Reproduced in 2017 against the old `ngax` Commandline UI, where toggling "Edit as text"/list with >~10 `--` parameters misaligned field values. That screen has since been fully rewritten in `ngclient` (default in 2.3.x) with related fixes (options no longer missing, filters fully editable, "Export as commandline" corrected). Could someone re-test on the current release: open a job's Commandline page, add 11+ advanced options, toggle text/list views, and confirm each value stays mapped to the correct field? If it persists we'll refresh the repro; otherwise close as fixed.


### 4.4 reproduced（再現確認済みバグ）

### #4714 — Creation of folder during Test Connection fails when using custom OAuth server
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-02-05 by ts678 (reproduced, but on a custom build)
- **Rationale**: Filed 2022 against a custom build testing then-unmerged PR #4699. In current code the OAuth URL is a first-class `OAuthUrl` option threaded uniformly into the auth helper (`Jottacloud.cs:180`); no separate hardcoded path remains. Custom-OAuth-server beta infra obsolete.
- **Draft comment**: This was reported in 2022 against a custom build while testing PR #4699 before Jottacloud OAuth was merged. Since then the OAuth service URL is a first-class option threaded uniformly into the auth helper for all operations (token refresh, test, folder creation all use the same `OAuthUrl`), so the hardcoded-production-URL path no longer exists. Closing as stale — if anyone can still reproduce a mismatch with a custom `oauth-url` on a current canary (2.3.0.x), please comment and we'll reopen.

### #4631 — Database is locked when performing auto-cleanup
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2023-04-05 (bot); substantive discussion through 2022
- **Rationale**: Root cause (auto-cleanup RepairHandler opening a 2nd SQLite connection while LocalBackupDatabase held an open transaction → lock → File.Move IOException) is fixed: `PreBackupVerifyAsync` now disposes the backup DB before `RepairHandler.RunAsync` and re-opens after (`BackupHandler.cs:295-303`); WAL mode enabled by default (`SQLiteLoader.cs:136`, PR #4612); layer moved to Microsoft.Data.Sqlite.
- **Draft comment**: The root cause identified here — the auto-cleanup Repair opening a second connection and INSERTing while the backup database still held an open transaction, leading to "database is locked" and then the `File.Move` IOException — has been addressed. `PreBackupVerify` now fully disposes the backup database before invoking the auto-cleanup repair and re-opens it afterward. In addition, WAL journal mode (PR #4612) is now enabled by default, so readers no longer block writers. Both are in current 2.3.0.x. Closing as fixed; please reopen with an Information-level log if you still hit this on a current build.

### #3445 — Error "database is locked" when trying to run a backup after a force stop
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024-03-12 by lapineige ("similar issue")
- **Rationale**: Regression from 2.0.3.6 concurrency rewrite: `Controller.cs` used `Thread.Abort()`, skipping `finally` blocks that dispose the DB connection. warwickmm declared it fixed by PR #3836 + #4042. `Thread.Abort` now entirely removed (CancellationToken throughout); SQLite async cancelable + WAL. Late "me too" comments lack version/log detail.
- **Draft comment**: The original mechanism — force-stop calling `Thread.Abort()`, skipping the `finally` blocks that release the SQLite connection — no longer exists. Stop handling was reworked (PR #3836/#4042), `Thread.Abort` removed in favor of `CancellationToken`, and the SQLite layer rewritten on Microsoft.Data.Sqlite with async cancelable queries and WAL. Closing as fixed. If you still see "database is locked" after stopping on a current 2.3.0.x canary, please open a fresh issue with version + Information-level log, as the cause would differ.
- **Note**: Related to #4631 but NOT a duplicate (different mechanism); both cured by the same modern refactors.

### #3011 — Buttons disappear after clicking Show log button
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2018-02-09 by Pectojin
- **Rationale**: 2018 cosmetic-navigation complaint about the legacy AngularJS "About" page. Web UI since rewritten as new Angular ngclient with different navigation/log layout. No activity 7+ years.
- **Draft comment**: This describes navigation on the legacy AngularJS "About" page from 2018. The web UI has since been fully rewritten as a new Angular application (ngclient) with a reworked navigation and log layout, now the default UI. The behavior described no longer applies. Closing as stale — if there's a comparable glitch in current ngclient, please open a fresh issue.

### #3027 — Mail password in advanced properties shouldn't be visible
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2024 by ts678 (single triage comment)
- **Rationale**: `send-mail-password` is `ArgumentType.Password` (`SendMail.cs:171`); advanced-options editor renders Password-typed options as `<input type="password">` (`advancedOptionsEditor.js:100-101`). Masked in current UI. 2018 screenshot predates option-type-aware rendering.
- **Draft comment**: `send-mail-password` is now declared as an `ArgumentType.Password` option, and the advanced-options editor renders any Password-typed option with `<input type="password">`, so the value is masked in both the current ngax editor and the new ngclient UI. The plain-text rendering in the 2018 screenshot predates the option-type-aware input handling. Closing as fixed. (As with any secret, it remains visible via "Edit as text", which is intentional.)

### #4001 — Target-Location not Pre-Selected when Entire Drive is to be backed up
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-01-16 by Jojo-1000
- **Rationale**: Minor load-order race in legacy ngax `file.html` (tree-vs-text decision ran before async Path resolved). Contributor Jojo-1000 stated "I think I fixed it in the new angular version"; agreed minor with trivial workaround. UI since rewritten to ngclient.
- **Draft comment**: This was a load-order race in the legacy ngax file-destination template, where the tree-vs-text decision ran before the saved path finished loading. As noted in the thread, it was addressed in the rewritten Angular UI (ngclient), now the default. The configured path was always correct — only the initial highlight was affected. Closing as fixed against the new UI; please open a fresh issue if the destination doesn't reflect the saved path in current ngclient.

### #3853 — EndTime: 0001-01-01T00:00:00, Duration: 00:00:00 after restore
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2024-02-02 (ts678 triage)
- **Rationale**: Bogus timing values were in the nested `BackendStatistics` block (`BackendWriter` never sets its own EndTime by design). Serializer now excludes EndTime/BeginTime/Duration for BackendWriter (`ResultClasses.cs:417-420`). Top-level restore result duration is set normally.
- **Draft comment**: The misleading `EndTime: 0001-01-01`, `Duration: 00:00:00`, and `BeginTime` values were the nested `BackendStatistics` block — a statistics sink (`BackendWriter`) that legitimately never sets its own timing fields. The result serializer now explicitly excludes those for `BackendWriter` instances, so these confusing zero values no longer appear in restore output. The top-level restore duration is populated correctly. Closing as fixed.

### #4405 — s3 SDK (aws/minio) setting doesn't stay or is overwritten
- **Verdict**: CLOSE_STALE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: ~2021 (bot); discussion 2020-2021
- **Rationale**: Timing/latency-dependent display bug in legacy ngax Destination screen — server returned correct `s3-client=minio` but the "Copy Destination URL" showed `aws` (only that screen; exports/CLI correct), worse in IE / high latency. UI since fully rewritten (ngclient).
- **Draft comment**: This was a timing/latency-dependent display bug in the legacy ngax Destination editor — the server always returned the correct `s3-client` value (exports and CLI were correct), but that one screen could show a stale value, notably in IE and over high-latency connections. The web UI has since been fully rewritten (ngclient). Closing as stale; if the S3 SDK selection is still displayed/saved incorrectly in current ngclient, please open a fresh issue against 2.3.0.x.

### 4.5 good first issue / minor change（実装候補）

### #5527 — Disable time check on a per file basis
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2025-08-20 (bot); last human = kenkendk agreeing on filter-based design
- **Rationale**: Genuine enhancement with agreed direction (filter/glob-based disable of filetime check) but no consensus on exact option shape. Touches filetime-check logic + UI + option parsing. Design needs pinning first; not good-first-issue.

### #2885 — Import does not seem to respect Backup.DBPath from a saved .json file
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2017-12-09 (bot bump 2025-06)
- **Rationale**: kenkendk confirmed "by design" (import ignores DBPath, auto-generates) but acknowledged annoying and solicited a UX idea; hcjehg proposed an import-time checkbox. Open UX enhancement with unresolved design question — not clear-cut to implement now, not stale enough to auto-close.

### #2663 — Fix warnings when delete operation clears temporary files
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-03-24 by kenkendk (triage only)
- **Rationale**: Delete-then-list warning behavior reworked in `BackendManager.DeleteOperation.cs` (~163-201). FileNotFound/Gone/404 on delete now logs Information + re-lists; if listing confirms absent, treats delete as succeeded (Information); warning only if listing confirms file still exists. Exactly the requested behavior.
- **Draft comment**: The delete path was reworked (`BackendManager.DeleteOperation.cs`). A delete that fails with FileNotFound/Gone/404 now logs at Information level and re-lists to confirm; if the listing shows the file is already gone, the delete is treated as successful (Information, not Warning). A warning is only raised when the listing confirms the file still exists. This addresses the spurious "FileNotFound listing contents" warning. Closing as fixed in current canary (2.3.0.106) — please reopen with a fresh log if you still see it.

### 4.6 2017 年以前の古参 Issue（棚卸し）

### #2467 — Analyze file size grouped by extension
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2017-05-17
- **Rationale**: No "Analyze sizes" feature in current source/changelog; source-picker has no per-extension size analysis. kenkendk endorsed the idea. Valid, unimplemented enhancement.

### #2493 — Update all %result% messages with double quotes to single quotes / delimiter
- **Verdict**: CLOSE_DONE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2017-05-23
- **Rationale**: Underlying need (machine-parseable output) solved by result-output-format system. `--send-mail-result-output-format=Json` gives escaped, quote-safe output; new `Template` (Handlebars) format lets user control delimiters. Rewriting every message string no longer the right fix.
- **Draft comment**: Since this was filed, Duplicati added selectable report output formats. To parse `%RESULT%` reliably, set `--send-mail-result-output-format=Json` (or `send-http-result-output-format` / `run-script-result-output-format`) — JSON escapes all quoting correctly. There's also a `Template` format (Handlebars) so you can define exactly which delimiters the output uses. Given these, individually re-quoting every message string is no longer necessary, so closing. Please reopen if a specific message still causes trouble on 2.3.0.x.

### #2504 — Add support for AWS Assume Role
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: high
- **Last activity**: 2017-05-29
- **Rationale**: S3 backend (`S3Backend.cs`) still only accepts static access-key/secret; no STS AssumeRole, session-token, or instance-profile support. Valid, unimplemented request.

### #2612 — Clicking Windows 10 notification does not open Duplicati
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2017-08-01
- **Rationale**: Tray icon rewritten onto Avalonia, but `AvaloniaRunner.NotifyUser` is effectively a stub (body commented out) and there's no click-to-open handler wiring a notification to the web UI. Requested behavior still not implemented. (Low priority; could alt. be closed as stale given tray rewrite.)

### #2616 — FTP fail-to-connect error not clear
- **Verdict**: NEEDS_INFO
- **Action**: keep-open (re-test)
- **Confidence**: low
- **Last activity**: 2017-08-01
- **Rationale**: FTP stack fully replaced (FluentFTP handles FTP + aFTP); FTP-message logging options added. Old "Invalid response from server" wording no longer applies, but couldn't confirm new text is clearer for the denied-IP case. Ask reporter to re-test on current backend.

### #2620 — Global HTTP timeout options
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2017-08-02
- **Rationale**: Implemented. `TimeoutOptionsHelper.cs` defines `--read-write-timeout`, `--short-timeout`, `--list-timeout`, applied per-backend across all backends. Delivers the configurable HTTP timeouts requested (filed by kenkendk himself).
- **Draft comment**: This has been implemented. Duplicati now exposes configurable timeouts as advanced options — `--read-write-timeout`, `--short-timeout`, and `--list-timeout` (see `TimeoutOptionsHelper`), applied consistently across backends. Closing as done; please reopen if a specific timeout is still not configurable on 2.3.0.x.

### #2654 — Bad error message when attempting to restore a target being backed up
- **Verdict**: NEEDS_INFO
- **Action**: keep-open (re-test)
- **Confidence**: low
- **Last activity**: 2017-08-28
- **Rationale**: Server now serializes operations through a queue runner (`IQueueRunnerService`) rather than letting restore collide with a running backup, which should change the "database is locked" behavior. But couldn't confirm the exact current user-facing message. Needs re-test.

### #2667 — Enhancement: Mobile client for viewing files
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2017-09-01
- **Rationale**: No native mobile (Android/iOS) client in repo/changelog. Responsive web UI works from a phone browser, but a dedicated app was never built. Valid open feature request.

### #2669 — Show only deleted/missing files
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2017-09-01
- **Rationale**: No "show only files missing from source" view in restore UI/changelog. Restore browser still shows the full backup tree; no toggle to list only paths absent from live source. Valid, unimplemented.

### #2838 — Support native environment variable syntax
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: high
- **Last activity**: 2017-11-17
- **Rationale**: Not implemented. `Utility.cs` still only matches Windows `%VAR%` (`ENVIRONMENT_VARIABLE_MATCHER_WINDOWS`); the TODO about switching to native `$VAR`/`${VAR}` is still in code (lines 989-990) with the native branch commented out. `$HOME`-style expansion on Linux/macOS still unsupported.

### #2846 — Log files do not contain timestamps
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: high
- **Last activity**: 2017-11-17
- **Rationale**: Primary request implemented: `LogEntry.ToString()`/`AsString` (used by `StreamLogDestination`) formats every line as `{yyyy-MM-dd HH:mm:ss zz} - [{tag}]: {message}`. Only the secondary "use native syslog/log4net" wish is unaddressed (aspirational, not the core ask).
- **Draft comment**: The core request — timestamps in the log file — is now implemented. Each line is written as `2026-07-05 11:40:09 +02 - [Tag]: message` (see `LogEntry.ToString()`), so file logs include a full date/time stamp. The separate idea of routing to the OS syslog facility was never adopted; if that's still wanted, it's better tracked as its own request. Closing this one as the timestamp ask is resolved — please reopen if timestamps are still missing on 2.3.0.x.

### #2903 — Ability to exclude "messages" section from email
- **Verdict**: CLOSE_DONE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2017-11-22
- **Rationale**: Reporter's real concern (sensitive paths leaking into email messages) now mitigated by default: log lines/body run through `SensitiveDataFilter.RedactPaths` unless `--allow-paths-in-log-messages` is set. To drop messages entirely: `--send-mail-max-log-lines=0` + custom `--send-mail-body`, or the new `Template` result format.
- **Draft comment**: Two things changed since 2017 that cover your case: (1) paths in reported/emailed log messages are now redacted by default, so the sensitive filenames no longer leak unless you set `--allow-paths-in-log-messages`. (2) You can suppress the messages section via `--send-mail-max-log-lines=0` and/or supply your own `--send-mail-body`, and there's now a `Template` result-output format (Handlebars) for fully custom emails. Given these, closing; please reopen if the messages section is still exposing sensitive data on 2.3.0.x.


### 4.7 最近（2025 年）のバグ報告

### #6461 — Backup can get stuck after requesting abort
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: high
- **Last activity**: 2025-08-11 by ts678
- **Rationale**: Filed 2025-08-07 by kenkendk against 2.1.0.120/.124/.125 — AFTER the async/cancelable SQLite + "kill signals" stop work (2.1.0.119–123). ts678 confirmed .124/.125 stuck for days; TrayIcon Quit wouldn't kill it. No later changelog entry addresses stop/hang. Still-valid, maintainer-owned bug with clean repro. Keep open for implementation.

### #6110 — recreate database failing
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-06-06 by wjansenw
- **Rationale**: Filed 2025-03-30 against 2.1.0.112. "ConstraintException: Detected N file(s) in FilesetEntry without corresponding FileLookup entry" after recreate. Fixes since: "Handle missing blocks on recreate" (2.2.0.103), "Improved handling of empty index files during recreate" (2.3.0.102). wjansenw recovered on 2.1.0.119 via `--replace-faulty-index-files` + purge-broken-files.
- **Draft comment**: Since this was filed (2.1.0.112), several database-recreate/index fixes shipped — notably "Handle missing blocks on recreate" (2.2.0.103) and "Improved handling of empty index files during recreate/restore" (2.3.0.102). @wjansenw also recovered by running a verify/backup with `--replace-faulty-index-files` then `purge-broken-files`. Could you retest the recreate on the latest canary (2.3.0.106+)? If it still fails with "FilesetEntry without corresponding FileLookup entry", please reopen with a fresh bugreport database. Closing as likely-fixed.

### #6101 — UI can enter a stuck state
- **Verdict**: NEEDS_INFO
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-03-28 by duplicatibot
- **Rationale**: Filed 2025-03-28 by kenkendk against ~2.1.0.110, tied to websocket handling. Many websocket fixes since: "Fixed websocket not connecting on welcome page" (2.3.0.103), "Improved websocket handling" + "Optimized query flow to use websockets" (2.3.0.102), "refreshToken race" fix (2.2.0.107). No concrete repro → unconfirmable.
- **Draft comment**: This was filed against an early 2.1.0.11x canary and traced to websocket message handling. The websocket layer has since been substantially reworked — "Optimized query flow to use websockets instead of polling" and "Improved websocket handling for remote management" (2.3.0.102), "Fixed websocket not connecting on welcome page" (2.3.0.103). Without a concrete repro we can't confirm the exact case. If anyone can still reproduce a stuck UI on the latest canary, please reopen with steps and browser console/websocket details. Closing as likely-addressed.

### #6076 — Duplicati regularly crashes while trying to refresh auth token
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-06-13 by ThomasChr
- **Rationale**: Filed 2025-03-24 against 2.1.0.5_stable. Crash is an unhandled `UnauthorizedException` from `/api/v1/auth/refresh` (WebUI/TrayIcon token refresh), not Azure-specific. Fixes since: "refreshToken race condition" (2.2.0.107), "auth refresh infinite loop in ngax" (2.3.0.100), "proxied auth and websocket authentication" (2.2.0.103).
- **Draft comment**: The stack trace shows this is the WebUI/TrayIcon auth token-refresh path (`/api/v1/auth/refresh`) throwing an unhandled `UnauthorizedException`, not anything Azure-specific. Several auth-refresh fixes shipped since 2.1.0.5: "Fixed refreshToken race condition that caused logout" (2.2.0.107), "Fixed auth refresh infinite loop in ngax" (2.3.0.100), "Fixed proxied auth and websocket authentication" (2.2.0.103). Could you update to the latest canary and see whether the periodic crashes stop? If it persists, reopen and note whether the WebUI tab is left open and whether a reverse proxy is involved. Closing as likely-fixed.

### #6051 — Backup fails with many "Unexpected difference in fileset version ,,,"
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-03-18 (bot); kenkendk asked for bugreport DB, never supplied
- **Rationale**: Filed 2025-03-17 on old 2.0.9.101. Exact symptom root-caused and fixed under #6529 (`--changed-files` introduces dangling entries), CLOSED 2026-01-30 with regression test `Issue6529.cs`. Changelog: "The `--changed-files` option has been fixed to not introduce extra dangling file entries" (2.2.0.104).
- **Draft comment**: The "Unexpected difference in fileset version … found X entries, but expected Y" failure was tracked down and fixed under #6529 — caused by dangling file entries from the changelist logic ("The `--changed-files` option has been fixed to not introduce extra dangling file entries", 2.2.0.104), now covered by a regression test. You were also on a quite old build (2.0.9.101). Please upgrade to the current canary; if the job still fails, run `purge-broken-files` and retry, and reopen with a bugreport database if it persists. Closing as fixed via #6529.

### #6032 — Using 100% CPU Without Running Any Tasks on My Windows Server
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: med
- **Last activity**: 2025-11-16 by Alfly-Alyx
- **Rationale**: Filed 2025-03-12 against 2.1.0.5; fresh "me too" as recent as 2025-11-16. Likely upstream Avalonia TrayIcon bug (AvaloniaUI/Avalonia#16750). Avalonia bumped to v12 (2.3.0.100/.101) and 12.0.2 (2.3.0.105, 2026-06-24). No changelog entry explicitly claims this fixed; last confirmation predates 12.0.2. Keep open, ask reporters to retest.
- **Draft comment**: The likely root cause is an upstream Avalonia TrayIcon issue (AvaloniaUI/Avalonia#16750). Duplicati has since bumped Avalonia to v12 and then 12.0.2 (2.3.0.105, 2026-06-24), changing rendering requirements. Could those still seeing 90–100% CPU (@gabmega, @Alfly-Alyx) retest on 2.3.0.105+ and report back, noting your OS and whether the TrayIcon is running? Keeping open until we confirm the Avalonia update resolves it.

### #5999 — Strange behaviour after upgrade to 2.1.0.4
- **Verdict**: CLOSE_DUPLICATE
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-03-05 by kenkendk
- **Rationale**: Filed 2025-03-03 against 2.1.0.4. GUI reports 0 new files, CLI ~8000 — spurious "changed" detection. Reporter linked #5943 ("2.1.0.2–2.1.0.4 incorrectly identifies metadata as changed"), now CLOSED. Fix: "Fixed a case where updated timestamps were discarded if no data was changed" (2.1.0.109).
- **Draft comment**: This looks like the same metadata-change false-positive tracked in #5943 ("v2.1.0.2–v2.1.0.4 incorrectly identifies metadata as changed"), which you linked and which is now fixed. The relevant fix ("Fixed a case where updated timestamps were discarded if no data was changed") shipped in 2.1.0.109, with further USN/metadata fixes since. Please retest on the latest canary — GUI and CLI should now agree on the changed-file count. Closing as a duplicate of the fixed #5943; reopen if the discrepancy persists on a current build.

### #5976 — Failure messages with `PRAGMA optimize`
- **Verdict**: CLOSE_FIXED
- **Action**: comment-and-close
- **Confidence**: med
- **Last activity**: 2025-02-14 by ts678
- **Rationale**: Filed 2025-02-14 by kenkendk against ~2.1.0.108/109. SQLite auto-index registers a schema change that aborts `PRAGMA optimize`. Fixes: "Ignore errors when closing and attempting pragma optimize", "Avoid optimize after vacuum" (2.1.0.117), plus SQLite swap to Microsoft.Data.Sqlite (2.1.0.121+). Benign warning, path now guarded.
- **Draft comment**: The `PRAGMA optimize` "database schema has changed" message was a benign warning caused by SQLite's auto-index registering as a schema change. Since filing, the optimize path was made resilient ("Ignore errors when closing and attempting pragma optimize", "Avoid optimize after vacuum", 2.1.0.117) and the SQLite layer migrated to Microsoft.Data.Sqlite (2.1.0.121+). These should no longer surface as failures. Please reopen if you still see a `PRAGMA optimize`-related error on the latest canary. Closing as addressed.

### #5908 — FTP error: SSL connection failed: session reuse required
- **Verdict**: ANSWER (upstream limitation)
- **Action**: answer-comment
- **Confidence**: high
- **Last activity**: 2025-01-30 by PacmanForever
- **Rationale**: Filed 2025-01-25 against 2.1.0.3_beta. kenkendk diagnosed: .NET SslStream doesn't support TLS session resumption, which the FTP server (Asus router) requires (FluentFTP#951). Not Duplicati-fixable without bundling a native TLS lib. No changelog fix.
- **Draft comment**: As diagnosed above, this is an upstream limitation: the .NET `SslStream` used by Duplicati/FluentFTP doesn't support TLS session resumption, but your FTP server (Asus router) enforces "session reuse required" (see FluentFTP#951). Fixing it would require bundling a native TLS library, not feasible across Duplicati's target platforms. Options: (1) use SFTP (SSH) instead of FTPS if supported, (2) plain FTP without TLS on a trusted LAN, or (3) a different endpoint. No Duplicati-side fix is planned, so closing as a known upstream limitation — happy to revisit if .NET adds session-resumption support.

### #5846 — Improve handling of duplicated filenames
- **Verdict**: KEEP_OPEN
- **Action**: keep-open
- **Confidence**: high
- **Last activity**: 2025-01-06 (created; no comments)
- **Rationale**: Opened by kenkendk as an improvement/tracking task (empty body, labeled bug). Design/enhancement item, not a regression — "fixed in later release" doesn't apply. Keep open as backlog. If pursued, touches filename/path handling in backup+restore pipeline (`Duplicati/Library/Main/Operation`), M–L, needs a concrete spec from kenkendk first.


## 5. Appendix — Open Issue 全 630 件のバケット別一覧

メタデータ（ラベル＋年代＋コメント数）による自動分類の全件リスト。§1 のバケット定義に対応します。

### 重複ラベル (close候補) (1件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [3419](https://github.com/duplicati/duplicati/issues/3419) | 2018-10-09 | 2018-12-17 | 8 | MacOS,duplicate | When adding Duplicati to login items, it isn't launched on login |

### pending user feedback (返信待ち→close候補) (16件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [2074](https://github.com/duplicati/duplicati/issues/2074) | 2016-10-31 | 2025-05-21 | 35 | pending user feedback | Restore Backup: Detected file entries with not associated blocks |
| [2351](https://github.com/duplicati/duplicati/issues/2351) | 2017-03-03 | 2025-05-21 | 6 | bug,core logic,pending user feedback | backup hangs forever without no output |
| [2556](https://github.com/duplicati/duplicati/issues/2556) | 2017-06-22 | 2025-03-24 | 4 | backend issue,bug,pending user feedback | second backup to webdav not works, but the first works fine |
| [2641](https://github.com/duplicati/duplicati/issues/2641) | 2017-08-14 | 2025-03-24 | 5 | backend issue,bug,pending user feedback | error "Expected hash not equal to calculated hash" when backing up to Wasabi |
| [2690](https://github.com/duplicati/duplicati/issues/2690) | 2017-09-04 | 2025-03-24 | 9 | bug,pending user feedback | duplicati starts but the page is blank on load |
| [2800](https://github.com/duplicati/duplicati/issues/2800) | 2017-10-06 | 2024-01-22 | 2 | backend issue,documentation,pending user feedback | onedrive 4 Business - The password has expired |
| [2859](https://github.com/duplicati/duplicati/issues/2859) | 2017-11-01 | 2025-03-24 | 1 | backend issue,bug,pending user feedback | RemoteOperationDelete hangs in Canary 2017-10-20 |
| [3060](https://github.com/duplicati/duplicati/issues/3060) | 2018-02-21 | 2024-01-19 | 3 | enhancement,pending user feedback | Feature request: automatically resume interrupted backup |
| [3320](https://github.com/duplicati/duplicati/issues/3320) | 2018-07-14 | 2024-01-17 | 5 | UI,pending user feedback | Recreate database layout bug |
| [3733](https://github.com/duplicati/duplicati/issues/3733) | 2019-04-11 | 2024-01-17 | 2 | pending user feedback,performance issue | Large file restore causes large fragmentation and unecessary IO |
| [4041](https://github.com/duplicati/duplicati/issues/4041) | 2020-01-05 | 2024-01-14 | 70 | local database issue,pending user feedback,performance issue | Database recreate desperately needs improvement |
| [4696](https://github.com/duplicati/duplicati/issues/4696) | 2022-03-21 | 2024-03-07 | 12 | backend issue,pending user feedback | Wasabi "The requested folder does not exist" |
| [5593](https://github.com/duplicati/duplicati/issues/5593) | 2024-10-17 | 2026-05-05 | 7 | bug,pending user feedback | Memory Leak Sequoia 15.1  |
| [5621](https://github.com/duplicati/duplicati/issues/5621) | 2024-11-01 | 2025-03-24 | 7 | bug,pending user feedback | Fatal error SocketException: The socket has been shut down |
| [6440](https://github.com/duplicati/duplicati/issues/6440) | 2025-07-30 | 2025-08-04 | 4 | pending user feedback | Duplicate Crashes after some time on Windows Server 2019 |
| [6448](https://github.com/duplicati/duplicati/issues/6448) | 2025-08-02 | 2025-08-08 | 2 | UI,pending user feedback,question | Bug/Feature: Clarify that Daily Schedule / Run Again Every is a binary choice. |

### stale ラベル (close候補) (1件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [4208](https://github.com/duplicati/duplicati/issues/4208) | 2020-05-24 | 2024-01-29 | 4 | enhancement,stale | Feature Request - Filter for recently deleted files to be kept in current backup |

### question (回答→close候補) (3件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [2363](https://github.com/duplicati/duplicati/issues/2363) | 2017-03-09 | 2025-05-21 | 7 | documentation,question | using backup started from the UI in the commandline |
| [3429](https://github.com/duplicati/duplicati/issues/3429) | 2018-10-15 | 2024-02-06 | 3 | UI,enhancement,question | backup state/phases |
| [6198](https://github.com/duplicati/duplicati/issues/6198) | 2025-04-23 | 2025-04-27 | 2 | question | question about Time Zone different |

### 2017年以前・低活動 (stale close候補) (24件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [2467](https://github.com/duplicati/duplicati/issues/2467) | 2017-05-08 | 2017-05-17 | 1 | enhancement | Analyze file size grouped by extension |
| [2468](https://github.com/duplicati/duplicati/issues/2468) | 2017-05-09 | 2017-05-17 | 1 | enhancement,help wanted,performance issue | Duplicati commandline list took hours  |
| [2504](https://github.com/duplicati/duplicati/issues/2504) | 2017-05-26 | 2017-05-29 | 0 | backend enhancement | Add support for AWS Assume Role |
| [2516](https://github.com/duplicati/duplicati/issues/2516) | 2017-05-31 | 2017-09-25 | 2 | enhancement | [Suggestion] Option to skip missing source drives |
| [2551](https://github.com/duplicati/duplicati/issues/2551) | 2017-06-20 | 2018-02-10 | 2 | enhancement,help wanted | [Feature Request] Option to launch on PC idle only. |
| [2583](https://github.com/duplicati/duplicati/issues/2583) | 2017-07-04 | 2017-09-03 | 1 | enhancement | Sparse file support |
| [2616](https://github.com/duplicati/duplicati/issues/2616) | 2017-07-31 | 2017-08-01 | 0 | documentation,enhancement | FTP fail to connect error not clear |
| [2620](https://github.com/duplicati/duplicati/issues/2620) | 2017-08-02 | 2017-08-02 | 0 | enhancement | Global HTTP timeout options |
| [2633](https://github.com/duplicati/duplicati/issues/2633) | 2017-08-10 | 2017-08-13 | 2 | enhancement,help wanted | Backup Across Multiple Rotating Drives |
| [2638](https://github.com/duplicati/duplicati/issues/2638) | 2017-08-13 | 2017-08-21 | 2 | enhancement | Visual feedback when clicking "Run now" while another job is running |
| [2642](https://github.com/duplicati/duplicati/issues/2642) | 2017-08-14 | 2017-08-21 | 1 | enhancement | 'System.IO.FileNotFoundException: Could not find file' during backup |
| [2653](https://github.com/duplicati/duplicati/issues/2653) | 2017-08-22 | 2017-09-02 | 2 | enhancement | Windows and Linux: multiple instance of the Duplicati GUI |
| [2654](https://github.com/duplicati/duplicati/issues/2654) | 2017-08-23 | 2017-08-28 | 0 | documentation,enhancement | Bad error message when attempting to restore a target being backed up |
| [2667](https://github.com/duplicati/duplicati/issues/2667) | 2017-08-27 | 2017-09-01 | 0 | enhancement | Enhancement : Mobile Client for viewing files |
| [2669](https://github.com/duplicati/duplicati/issues/2669) | 2017-08-29 | 2017-09-01 | 0 | enhancement | Show only deleted/missing files |
| [2697](https://github.com/duplicati/duplicati/issues/2697) | 2017-09-07 | 2017-09-14 | 1 | backend enhancement,core logic,enhancement | Tree structure for stored files |
| [2709](https://github.com/duplicati/duplicati/issues/2709) | 2017-09-11 | 2017-09-14 | 2 | UI,enhancement | FTP : Create folder if not exist on "test connection" |
| [2736](https://github.com/duplicati/duplicati/issues/2736) | 2017-09-18 | 2017-09-19 | 2 | enhancement | Using ShellCheck to test Shell Scripts? |
| [2764](https://github.com/duplicati/duplicati/issues/2764) | 2017-09-26 | 2017-10-13 | 2 | UI,enhancement,hacktoberfest | Simple visual indicator of backup status in UI |
| [2838](https://github.com/duplicati/duplicati/issues/2838) | 2017-10-22 | 2017-11-17 | 0 | enhancement | Support native environment variable syntax |
| [2846](https://github.com/duplicati/duplicati/issues/2846) | 2017-10-25 | 2017-11-17 | 1 | core logic,enhancement | Log files do not contain timestamps |
| [2895](https://github.com/duplicati/duplicati/issues/2895) | 2017-11-14 | 2017-11-24 | 1 | enhancement | usage-reporter.duplicati.com order of details in hover-popup |
| [2901](https://github.com/duplicati/duplicati/issues/2901) | 2017-11-19 | 2017-11-22 | 2 | UI,enhancement | Interface with different permission levels |
| [2903](https://github.com/duplicati/duplicati/issues/2903) | 2017-11-19 | 2017-11-22 | 1 | enhancement | Ability to exclude "messages" section from email [feature request] |

### reproduced 確認済みバグ (実装候補) (11件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [2487](https://github.com/duplicati/duplicati/issues/2487) | 2017-05-19 | 2025-03-24 | 0 | bug,help wanted,minor change,reproduced | scheduled Jobs are not updated after Change of weekday |
| [2604](https://github.com/duplicati/duplicati/issues/2604) | 2017-07-18 | 2025-03-24 | 5 | UI,bug,reproduced | WebUI: commandline - some fields have the wrong value |
| [3011](https://github.com/duplicati/duplicati/issues/3011) | 2018-02-06 | 2024-02-05 | 3 | UI,reproduced | Buttons disappear after clicking Show log button |
| [3027](https://github.com/duplicati/duplicati/issues/3027) | 2018-02-12 | 2024-01-30 | 1 | UI,reproduced | Mail password in advanced properties shouldn't be visible |
| [3445](https://github.com/duplicati/duplicati/issues/3445) | 2018-10-19 | 2025-03-24 | 21 | bug,local database issue,reproduced | Error "database is locked" when trying to run a backup after a force stop |
| [3483](https://github.com/duplicati/duplicati/issues/3483) | 2018-11-10 | 2024-01-17 | 21 | UI,needs testing,reproduced | When restoring files the top level checkboxes cannot be selected until children  |
| [3853](https://github.com/duplicati/duplicati/issues/3853) | 2019-08-08 | 2024-02-02 | 2 | reproduced | EndTime: 0001-01-01T00:00:00, Duration: 00:00:00 after restore with 2.0.4.21 (2. |
| [4001](https://github.com/duplicati/duplicati/issues/4001) | 2019-11-28 | 2024-02-05 | 6 | UI,reproduced | Target-Location not Pre-Selected when Entire Drive is to be backed up  |
| [4405](https://github.com/duplicati/duplicati/issues/4405) | 2020-12-30 | 2023-11-17 | 10 | UI,reproduced | s3 SDK (aws/minio) setting doesn't stay or is overwritten (or maybe displayed in |
| [4631](https://github.com/duplicati/duplicati/issues/4631) | 2021-10-25 | 2025-03-24 | 31 | bug,local database issue,reproduced | Database is locked when performing auto-cleanup |
| [4714](https://github.com/duplicati/duplicati/issues/4714) | 2022-04-23 | 2025-03-24 | 1 | bug,reproduced | Creation of folder during Test Connection fails when using custom OAuth server |

### good first issue (実装候補) (1件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [5527](https://github.com/duplicati/duplicati/issues/5527) | 2024-09-03 | 2025-08-20 | 5 | enhancement,good first issue,help wanted | Disable time check on a per file basis |

### minor change (実装候補) (31件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [1282](https://github.com/duplicati/duplicati/issues/1282) | 2015-02-07 | 2025-05-21 | 2 | enhancement,minor change | Case sensitive compare for FTP LIST output |
| [1443](https://github.com/duplicati/duplicati/issues/1443) | 2015-08-25 | 2025-05-21 | 1 | core logic,enhancement,help wanted,minor change | Exclude files Duplicati is writing to from backup |
| [1724](https://github.com/duplicati/duplicati/issues/1724) | 2016-04-24 | 2025-05-21 | 1 | enhancement,minor change | Restart duplicati option |
| [1757](https://github.com/duplicati/duplicati/issues/1757) | 2016-05-08 | 2025-05-21 | 4 | minor change | Duplicati tries, and fails, to backup its own locked files |
| [1814](https://github.com/duplicati/duplicati/issues/1814) | 2016-06-15 | 2025-05-21 | 2 | UI,enhancement,minor change | Error displaying log for backup that has never been run |
| [1910](https://github.com/duplicati/duplicati/issues/1910) | 2016-08-29 | 2025-05-21 | 1 | enhancement,minor change | Feature Request: logfile improvement to display the list-of-filters |
| [1925](https://github.com/duplicati/duplicati/issues/1925) | 2016-09-08 | 2025-05-21 | 1 | enhancement,minor change | Only backup files created or modified after a certain timestamp |
| [1940](https://github.com/duplicati/duplicati/issues/1940) | 2016-09-22 | 2025-05-21 | 0 | enhancement,minor change | Log GPG command and options |
| [2073](https://github.com/duplicati/duplicati/issues/2073) | 2016-10-31 | 2025-05-21 | 0 | enhancement,minor change | Verbose command with commandline should display filters |
| [2234](https://github.com/duplicati/duplicati/issues/2234) | 2017-01-08 | 2025-05-21 | 0 | core logic,enhancement,minor change | Improve purge to rewire metadata |
| [2259](https://github.com/duplicati/duplicati/issues/2259) | 2017-01-16 | 2025-05-21 | 2 | UI,enhancement,minor change | Dup 2: add report bug button |
| [2267](https://github.com/duplicati/duplicati/issues/2267) | 2017-01-19 | 2025-05-21 | 10 | UI,enhancement,help wanted,minor change | Make the OSX file listing more intuitive and similar to how OSX works |
| [2270](https://github.com/duplicati/duplicati/issues/2270) | 2017-01-20 | 2025-05-21 | 24 | help wanted,minor change | GPG asymmetric encryption module |
| [2311](https://github.com/duplicati/duplicati/issues/2311) | 2017-02-10 | 2025-05-21 | 0 | documentation,enhancement,minor change | Add Google Drive backup example to Duplicati CommandLine help.txt |
| [2330](https://github.com/duplicati/duplicati/issues/2330) | 2017-02-21 | 2025-05-21 | 2 | UI,enhancement,help wanted,minor change,server side | Feature request: run all backup tasks at once |
| [2361](https://github.com/duplicati/duplicati/issues/2361) | 2017-03-08 | 2025-05-21 | 1 | UI,enhancement,help wanted,minor change | Improve verification process from the UI [$15] |
| [2419](https://github.com/duplicati/duplicati/issues/2419) | 2017-04-04 | 2025-05-21 | 5 | enhancement,minor change,performance issue | SHA512 as standard hash |
| [2493](https://github.com/duplicati/duplicati/issues/2493) | 2017-05-21 | 2017-05-23 | 0 | enhancement,help wanted,minor change | Update all possible %result% text messages/errors/warning with quotation marks ( |
| [2499](https://github.com/duplicati/duplicati/issues/2499) | 2017-05-23 | 2017-05-29 | 1 | backend enhancement,enhancement,help wanted,minor change | Make SFTP backend resilient to no space problems with CoW file systems |
| [2612](https://github.com/duplicati/duplicati/issues/2612) | 2017-07-26 | 2017-08-01 | 0 | UI,enhancement,help wanted,minor change | Clicking Windows 10 notification does not open Duplicati |
| [2663](https://github.com/duplicati/duplicati/issues/2663) | 2017-08-26 | 2025-03-24 | 0 | bug,core logic,minor change | Fix warnings when delete operation clears temporary files |
| [2681](https://github.com/duplicati/duplicati/issues/2681) | 2017-09-01 | 2025-03-24 | 8 | bug,minor change | "Local folder or drive" destination folders containing the @ symbol corrupts the |
| [2701](https://github.com/duplicati/duplicati/issues/2701) | 2017-09-08 | 2017-09-21 | 2 | enhancement,help wanted,minor change | omit/postpone scheduled tasks |
| [2750](https://github.com/duplicati/duplicati/issues/2750) | 2017-09-22 | 2022-04-10 | 10 | enhancement,help wanted,minor change | Email notification enhancement: include list of files changed |
| [2765](https://github.com/duplicati/duplicati/issues/2765) | 2017-09-26 | 2018-11-26 | 2 | UI,enhancement,minor change | Feature request: Disable backupsets |
| [2766](https://github.com/duplicati/duplicati/issues/2766) | 2017-09-26 | 2017-11-16 | 4 | UI,enhancement,hacktoberfest,minor change | Feature request: Move/prioritise backupsets |
| [2839](https://github.com/duplicati/duplicati/issues/2839) | 2017-10-23 | 2017-11-17 | 1 | enhancement,help wanted,minor change | How is the right way to end / cancel duplicati on the command line? |
| [2885](https://github.com/duplicati/duplicati/issues/2885) | 2017-11-08 | 2025-06-03 | 2 | enhancement,local database issue,minor change | Import does not seem to respect Backup.DBPath from a saved .json file |
| [3340](https://github.com/duplicati/duplicati/issues/3340) | 2018-08-17 | 2018-10-16 | 1 | enhancement,minor change | Restoring a folder restores its contents but not the folder itself |
| [3440](https://github.com/duplicati/duplicati/issues/3440) | 2018-10-18 | 2024-02-07 | 0 | UI,enhancement,help wanted,minor change | Request: Dialogs that only have one button could be dismissed by simply pressing |
| [6031](https://github.com/duplicati/duplicati/issues/6031) | 2025-03-12 | 2025-03-24 | 0 | UI,enhancement,minor change | please consider about the dark theme font color |

### その他 bug (68件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [1226](https://github.com/duplicati/duplicati/issues/1226) | 2014-12-15 | 2025-04-28 | 5 | bug | Changing schedule settings in v 2.0.73 on windows 8 inconsistent |
| [1442](https://github.com/duplicati/duplicati/issues/1442) | 2015-08-19 | 2025-05-21 | 2 | bug | Verifying hang... |
| [2049](https://github.com/duplicati/duplicati/issues/2049) | 2016-10-24 | 2025-05-21 | 11 | bug | Duplicati stops in the middle of backup |
| [2263](https://github.com/duplicati/duplicati/issues/2263) | 2017-01-17 | 2025-05-21 | 7 | bug | GetResponse timeout on a large (>400GB) dataset to OneDrive |
| [2265](https://github.com/duplicati/duplicati/issues/2265) | 2017-01-18 | 2025-05-21 | 2 | bug | Repair - SQL Logic Error and Locked File |
| [2298](https://github.com/duplicati/duplicati/issues/2298) | 2017-02-01 | 2025-05-21 | 8 | bug,core logic | "Create Bugreport" never ends, consuming 100% CPU-load |
| [2359](https://github.com/duplicati/duplicati/issues/2359) | 2017-03-06 | 2025-05-21 | 11 | UI,bug,server side | database is locked database is locked |
| [2392](https://github.com/duplicati/duplicati/issues/2392) | 2017-03-20 | 2025-05-21 | 4 | UI,bug,help wanted | Failed to fetch path information in Pale Moon browser [unimportant] |
| [2443](https://github.com/duplicati/duplicati/issues/2443) | 2017-04-25 | 2025-03-24 | 0 | bug | GPG encryption: System.ObjectDisposedException: Cannot access a disposed object. |
| [2480](https://github.com/duplicati/duplicati/issues/2480) | 2017-05-17 | 2025-03-24 | 12 | bug | VSS problems after last update. |
| [2498](https://github.com/duplicati/duplicati/issues/2498) | 2017-05-23 | 2025-03-24 | 8 | backend issue,bug | Constant Issues |
| [2501](https://github.com/duplicati/duplicati/issues/2501) | 2017-05-24 | 2025-03-24 | 5 | bug,core logic | Can't repair after crash |
| [2566](https://github.com/duplicati/duplicati/issues/2566) | 2017-06-26 | 2025-03-24 | 4 | bug | Failure while invoking GnuPG, program won't flush output |
| [2594](https://github.com/duplicati/duplicati/issues/2594) | 2017-07-12 | 2025-03-24 | 1 | bug | Counting / Backup Loop |
| [2602](https://github.com/duplicati/duplicati/issues/2602) | 2017-07-17 | 2025-03-24 | 9 | bug | Database is full |
| [2631](https://github.com/duplicati/duplicati/issues/2631) | 2017-08-10 | 2025-03-24 | 24 | bug | Duplicati stuck at restore configuration |
| [2640](https://github.com/duplicati/duplicati/issues/2640) | 2017-08-13 | 2025-03-24 | 3 | bug,core logic,help wanted,windows | Directory junctions are restored as empty folders on Windows |
| [2680](https://github.com/duplicati/duplicati/issues/2680) | 2017-08-31 | 2025-03-24 | 1 | bug | 2 issues with translating at Transifex.com |
| [2720](https://github.com/duplicati/duplicati/issues/2720) | 2017-09-14 | 2025-03-24 | 10 | bug | VSS failure with snapshot-policy=Off (Resolved with suggestion) |
| [2744](https://github.com/duplicati/duplicati/issues/2744) | 2017-09-19 | 2025-03-24 | 1 | bug | Strange not descriptive errors, possible technical bugs or just UX bugs |
| [2825](https://github.com/duplicati/duplicati/issues/2825) | 2017-10-17 | 2025-03-24 | 1 | bug | Stuck on "Verifying backend data ..." (PM: UsageReporter failed) |
| [2862](https://github.com/duplicati/duplicati/issues/2862) | 2017-11-02 | 2025-03-24 | 6 | bug | LV error on Ubuntu 16.04 |
| [2904](https://github.com/duplicati/duplicati/issues/2904) | 2017-11-21 | 2025-03-24 | 7 | bug | Next scheduled execution can not be changed |
| [3020](https://github.com/duplicati/duplicati/issues/3020) | 2018-02-08 | 2025-03-24 | 5 | bug | Usage statistics causes Duplicati2 to crash when behind a proxy using authentica |
| [3040](https://github.com/duplicati/duplicati/issues/3040) | 2018-02-16 | 2025-03-24 | 2 | bug | Can't view log, "database is locked" |
| [3123](https://github.com/duplicati/duplicati/issues/3123) | 2018-03-24 | 2025-03-24 | 3 | bug | Bad handling of "" in commandline arguments in Duplicati.WindowsService |
| [3375](https://github.com/duplicati/duplicati/issues/3375) | 2018-09-11 | 2025-03-24 | 2 | bug | Repair never ends |
| [3536](https://github.com/duplicati/duplicati/issues/3536) | 2018-12-11 | 2025-03-24 | 22 | bug,core logic | Recursive Folders (due to symlinks?) in Linux |
| [3546](https://github.com/duplicati/duplicati/issues/3546) | 2018-12-18 | 2025-03-24 | 3 | bug | Unable to recover initial backup due to repair deadlock |
| [3644](https://github.com/duplicati/duplicati/issues/3644) | 2019-02-04 | 2025-03-24 | 19 | bug,core logic | Error / DB corruption: Unexpected difference in fileset version X: found Y entri |
| [3672](https://github.com/duplicati/duplicati/issues/3672) | 2019-02-23 | 2025-03-24 | 1 | bug | While restoring, received error message: Backend quota has been exceeded |
| [3750](https://github.com/duplicati/duplicati/issues/3750) | 2019-04-25 | 2025-03-24 | 1 | UI,bug | Custom storage class drop down not working |
| [3979](https://github.com/duplicati/duplicati/issues/3979) | 2019-11-06 | 2025-03-24 | 11 | backend enhancement,bug | S3 authorization header malformed |
| [4159](https://github.com/duplicati/duplicati/issues/4159) | 2020-04-03 | 2025-03-24 | 0 | bug | Running Delete Command from Webinterface whilst running Backup Job deletes wrong |
| [4644](https://github.com/duplicati/duplicati/issues/4644) | 2021-11-30 | 2025-03-24 | 2 | UI,bug | "Restore successful" message shown on failed restore |
| [4880](https://github.com/duplicati/duplicati/issues/4880) | 2022-12-14 | 2025-03-24 | 2 | bug | No "+" allowed in path of WebDAV destinations (plus sign issue; bypass provided) |
| [4927](https://github.com/duplicati/duplicati/issues/4927) | 2023-04-26 | 2025-03-24 | 4 | UI,bug | Backup Removable Storage |
| [5465](https://github.com/duplicati/duplicati/issues/5465) | 2024-08-16 | 2025-03-24 | 0 | bug | extract.sh to update localization files returns an error and does not seem to up |
| [5508](https://github.com/duplicati/duplicati/issues/5508) | 2024-08-30 | 2025-03-24 | 3 | bug | Investigate logouts after suspend |
| [5546](https://github.com/duplicati/duplicati/issues/5546) | 2024-09-08 | 2025-03-24 | 11 | bug | SFTP (SSH) backup from Windows to Synology NAS not possible, manual connection w |
| [5559](https://github.com/duplicati/duplicati/issues/5559) | 2024-09-13 | 2025-03-24 | 6 | bug | Duplicati CRC error, possibly caused by reallocated sectors / HDD failure |
| [5570](https://github.com/duplicati/duplicati/issues/5570) | 2024-09-24 | 2025-03-24 | 0 | bug | Failed to create a snapshot: The creation of a shadow copy is already in progres |
| [5572](https://github.com/duplicati/duplicati/issues/5572) | 2024-09-28 | 2025-03-24 | 0 | bug | live log may skip lines |
| [5573](https://github.com/duplicati/duplicati/issues/5573) | 2024-09-28 | 2025-03-24 | 0 | bug | Restore of locked file warns despite snapshot-policy=required |
| [5605](https://github.com/duplicati/duplicati/issues/5605) | 2024-10-28 | 2025-03-24 | 4 | bug,help wanted | Support OneDrive with WebDAV |
| [5670](https://github.com/duplicati/duplicati/issues/5670) | 2024-11-13 | 2025-04-25 | 1 | bug | Hyper-V backup in Windows Server 2025 errors out |
| [5677](https://github.com/duplicati/duplicati/issues/5677) | 2024-11-14 | 2025-03-24 | 0 | bug | Test function for OpenStack does not check for existing folder |
| [5720](https://github.com/duplicati/duplicati/issues/5720) | 2024-11-30 | 2025-03-24 | 8 | bug | SELinux alerts while trying to connect to the backend (wrong context on executab |
| [5786](https://github.com/duplicati/duplicati/issues/5786) | 2024-12-17 | 2025-03-24 | 8 | bug | Using a WebDAV mounted source fails on Windows |
| [5793](https://github.com/duplicati/duplicati/issues/5793) | 2024-12-18 | 2026-07-03 | 52 | bug | Storj causes crashes on Linux/Docker |
| [5830](https://github.com/duplicati/duplicati/issues/5830) | 2025-01-02 | 2025-03-24 | 4 | bug | Extremely slow HDD write on a large file |
| [5831](https://github.com/duplicati/duplicati/issues/5831) | 2025-01-02 | 2025-03-24 | 1 | bug | Drop-down menus shown in OS language despite language settings |
| [5832](https://github.com/duplicati/duplicati/issues/5832) | 2025-01-03 | 2025-03-24 | 1 | bug | Misleading header in Restore dialog |
| [5846](https://github.com/duplicati/duplicati/issues/5846) | 2025-01-06 | 2025-03-24 | 0 | bug | Improve handling of duplicated filenames |
| [5868](https://github.com/duplicati/duplicati/issues/5868) | 2025-01-12 | 2025-01-13 | 1 | bug | Using duplicati-cli on Mac |
| [5908](https://github.com/duplicati/duplicati/issues/5908) | 2025-01-25 | 2025-03-24 | 2 | bug | FTP error: SSL connection failed: session reuse required |
| [5944](https://github.com/duplicati/duplicati/issues/5944) | 2025-02-06 | 2025-03-24 | 1 | bug | Storj backup fails: indicating missing files or disk full |
| [5976](https://github.com/duplicati/duplicati/issues/5976) | 2025-02-14 | 2025-03-24 | 2 | bug | Failure messages with `PRAGMA optimize` |
| [5999](https://github.com/duplicati/duplicati/issues/5999) | 2025-03-03 | 2025-03-24 | 3 | bug | Strange behaviour after upgrade to 2.1.0.4 |
| [6032](https://github.com/duplicati/duplicati/issues/6032) | 2025-03-12 | 2025-11-16 | 8 | bug | Using 100% CPU Without Running Any Tasks on My Windows Server |
| [6042](https://github.com/duplicati/duplicati/issues/6042) | 2025-03-15 | 2025-05-29 | 4 | bug | duplicati-2.1.0.5 Debian : cannot login to remote with Apache2 proxy or webservi |
| [6051](https://github.com/duplicati/duplicati/issues/6051) | 2025-03-17 | 2025-03-24 | 2 | bug | Backup fails with many "Unexpected difference in fileset version ,,," |
| [6073](https://github.com/duplicati/duplicati/issues/6073) | 2025-03-23 | 2025-03-25 | 2 | bug | Web UI elements are empty or take very long to be filled |
| [6076](https://github.com/duplicati/duplicati/issues/6076) | 2025-03-24 | 2025-06-13 | 3 | bug | Duplicati regularly crashes while trying to refresh auth token for azure |
| [6101](https://github.com/duplicati/duplicati/issues/6101) | 2025-03-28 | 2025-03-28 | 1 | bug | UI can enter a stuck state |
| [6110](https://github.com/duplicati/duplicati/issues/6110) | 2025-03-30 | 2025-06-06 | 3 | bug | recreate database failing |
| [6214](https://github.com/duplicati/duplicati/issues/6214) | 2025-04-29 | 2025-05-03 | 1 | bug | Docker Image upgrade and Password reset |
| [6461](https://github.com/duplicati/duplicati/issues/6461) | 2025-08-07 | 2025-08-11 | 2 | bug | Backup can get stuck after requesting abort |

### enhancement バックログ (170件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [72](https://github.com/duplicati/duplicati/issues/72) | 2014-08-05 | 2025-05-21 | 34 | UI,enhancement | Show all versions of a file in the recovery tree |
| [191](https://github.com/duplicati/duplicati/issues/191) | 2014-08-05 | 2025-05-21 | 5 | enhancement,imported | scheduling before shutdown |
| [234](https://github.com/duplicati/duplicati/issues/234) | 2014-08-05 | 2025-10-15 | 41 | enhancement | Allow targeting multiple destinations |
| [290](https://github.com/duplicati/duplicati/issues/290) | 2014-08-05 | 2025-05-21 | 2 | enhancement,imported | Proxy support |
| [367](https://github.com/duplicati/duplicati/issues/367) | 2014-08-05 | 2025-05-21 | 2 | enhancement,imported | Ability to enable / disable proxies in order to copy data over two trusting wind |
| [479](https://github.com/duplicati/duplicati/issues/479) | 2014-08-05 | 2025-05-21 | 27 | enhancement,imported | The RAID backend |
| [519](https://github.com/duplicati/duplicati/issues/519) | 2014-08-05 | 2025-05-21 | 5 | enhancement,imported | Wake computer to perform backup and then put it back to sleep |
| [520](https://github.com/duplicati/duplicati/issues/520) | 2014-08-05 | 2025-05-21 | 5 | enhancement,imported | Postpone the backup until computer is idle |
| [525](https://github.com/duplicati/duplicati/issues/525) | 2014-08-05 | 2025-05-21 | 11 | enhancement,imported | Support friend to friend backup |
| [530](https://github.com/duplicati/duplicati/issues/530) | 2014-08-05 | 2025-05-21 | 3 | enhancement,imported | Option to choose the cipher-algo for GnuPG |
| [611](https://github.com/duplicati/duplicati/issues/611) | 2014-08-05 | 2025-06-13 | 7 | enhancement,imported | Backup time window - scheduled pause times |
| [616](https://github.com/duplicati/duplicati/issues/616) | 2014-08-05 | 2025-05-21 | 5 | enhancement,imported,new backend | Support for OwnCloud / OwnCube |
| [663](https://github.com/duplicati/duplicati/issues/663) | 2014-08-05 | 2025-05-21 | 3 | enhancement,imported | Avoid network VPN / WAN bottlenecks in a multi user environment |
| [866](https://github.com/duplicati/duplicati/issues/866) | 2014-08-05 | 2025-05-21 | 5 | enhancement,imported | Allow to set different throttling options for different networks |
| [996](https://github.com/duplicati/duplicati/issues/996) | 2014-08-05 | 2025-05-21 | 0 | enhancement,imported | Improving usability of scheduled backups on removable disk |
| [1032](https://github.com/duplicati/duplicati/issues/1032) | 2014-08-05 | 2025-05-21 | 11 | enhancement,imported | If system disk is SSD and backups are large, Duplicati's default options will ca |
| [1108](https://github.com/duplicati/duplicati/issues/1108) | 2014-08-17 | 2025-05-21 | 8 | enhancement | Duplicati2 Feature Request: Commandline config store like Duplicati-server.sqlit |
| [1152](https://github.com/duplicati/duplicati/issues/1152) | 2014-10-13 | 2025-12-19 | 17 | UI,enhancement | Combine logs in GUI |
| [1174](https://github.com/duplicati/duplicati/issues/1174) | 2014-11-02 | 2025-05-21 | 8 | enhancement | Duplicati 2: Display current task in status |
| [1266](https://github.com/duplicati/duplicati/issues/1266) | 2015-01-26 | 2025-05-21 | 1 | enhancement | Record name/properties of backup config in dlist file |
| [1270](https://github.com/duplicati/duplicati/issues/1270) | 2015-02-02 | 2025-05-21 | 1 | enhancement,help wanted | Start-as-daemon/service and Create installers |
| [1273](https://github.com/duplicati/duplicati/issues/1273) | 2015-02-02 | 2025-05-21 | 2 | enhancement | Feature request: Enhancement of verify options |
| [1308](https://github.com/duplicati/duplicati/issues/1308) | 2015-02-20 | 2025-05-21 | 9 | enhancement | Allow to restore all files for a certain timestamp (from the GUI) |
| [1374](https://github.com/duplicati/duplicati/issues/1374) | 2015-05-07 | 2025-05-21 | 31 | backend enhancement,enhancement | Store destination files in sub folders. |
| [1382](https://github.com/duplicati/duplicati/issues/1382) | 2015-05-17 | 2025-05-21 | 1 | enhancement | [Feature request] Show information on tray icon |
| [1417](https://github.com/duplicati/duplicati/issues/1417) | 2015-07-11 | 2025-05-21 | 2 | enhancement | [Feature request] Add ability to log to syslog |
| [1468](https://github.com/duplicati/duplicati/issues/1468) | 2015-09-17 | 2025-05-21 | 0 | enhancement | Detect if the assembly loading is being blocked by the .Net sandboxing policy |
| [1510](https://github.com/duplicati/duplicati/issues/1510) | 2015-12-09 | 2025-05-21 | 0 | UI,enhancement | No feedback on "Verify Backup files" |
| [1520](https://github.com/duplicati/duplicati/issues/1520) | 2015-12-15 | 2025-05-21 | 0 | enhancement | RFE: Allow using --alternate-destination-marker without --alternate-target-paths |
| [1521](https://github.com/duplicati/duplicati/issues/1521) | 2015-12-15 | 2025-05-21 | 0 | enhancement | No warning when an option is invalid in current context |
| [1530](https://github.com/duplicati/duplicati/issues/1530) | 2016-01-04 | 2025-05-21 | 0 | enhancement | --one-file-system option |
| [1586](https://github.com/duplicati/duplicati/issues/1586) | 2016-02-20 | 2025-05-21 | 8 | enhancement | Improved handling of restore into existing data |
| [1622](https://github.com/duplicati/duplicati/issues/1622) | 2016-03-13 | 2025-05-21 | 3 | UI,enhancement | ngax: Missing queue info |
| [1673](https://github.com/duplicati/duplicati/issues/1673) | 2016-03-31 | 2025-11-29 | 11 | enhancement | autoupdate of Duplicati |
| [1676](https://github.com/duplicati/duplicati/issues/1676) | 2016-04-01 | 2025-05-21 | 2 | backend enhancement,enhancement | Handle 'cold storage' restore dblocks for odrive.com files ending .vcloud |
| [1705](https://github.com/duplicati/duplicati/issues/1705) | 2016-04-17 | 2025-05-21 | 5 | enhancement | Disallow uploads on selected WiFi networks |
| [1739](https://github.com/duplicati/duplicati/issues/1739) | 2016-04-29 | 2025-05-21 | 10 | enhancement | Add support for choosing a user context to display the user interface in |
| [1740](https://github.com/duplicati/duplicati/issues/1740) | 2016-04-29 | 2025-05-21 | 1 | enhancement,new backend | Create a command-line backend |
| [1775](https://github.com/duplicati/duplicati/issues/1775) | 2016-05-18 | 2025-05-21 | 0 | enhancement | improved blocksize |
| [1788](https://github.com/duplicati/duplicati/issues/1788) | 2016-05-27 | 2025-05-21 | 48 | UI,documentation,enhancement,help wanted | Onedrive for business help - add to wiki faq |
| [1799](https://github.com/duplicati/duplicati/issues/1799) | 2016-06-08 | 2025-05-21 | 0 | enhancement,help wanted | Duplicati plugin for Total Commander |
| [1809](https://github.com/duplicati/duplicati/issues/1809) | 2016-06-14 | 2025-05-21 | 6 | core logic,enhancement | Enhanced integrity check with all dlist and dindex files, a `dry-run` restore wi |
| [1838](https://github.com/duplicati/duplicati/issues/1838) | 2016-07-01 | 2025-05-21 | 6 | UI,documentation,enhancement | Backing up tmp files |
| [1843](https://github.com/duplicati/duplicati/issues/1843) | 2016-07-07 | 2025-05-21 | 3 | enhancement | Load SSL certificate from WebUI |
| [1953](https://github.com/duplicati/duplicati/issues/1953) | 2016-09-26 | 2025-05-21 | 0 | UI,enhancement | check if source path is a file or folder |
| [1957](https://github.com/duplicati/duplicati/issues/1957) | 2016-09-28 | 2025-05-21 | 6 | backend enhancement,enhancement | FTP only lists a max 2000 files, is it possible to use subfolders? |
| [1966](https://github.com/duplicati/duplicati/issues/1966) | 2016-09-30 | 2025-05-21 | 5 | enhancement | Need an option to ignore existing files when restoring to original location |
| [1969](https://github.com/duplicati/duplicati/issues/1969) | 2016-10-01 | 2025-05-21 | 2 | UI,enhancement | Put advanced options on separate page? |
| [1970](https://github.com/duplicati/duplicati/issues/1970) | 2016-10-02 | 2025-05-21 | 1 | enhancement | Update options to use a typed structure |
| [2012](https://github.com/duplicati/duplicati/issues/2012) | 2016-10-14 | 2025-05-21 | 0 | enhancement | Add support for encryption keyfiles |
| [2018](https://github.com/duplicati/duplicati/issues/2018) | 2016-10-16 | 2025-05-21 | 0 | UI,enhancement | Missing "back" button on some pages |
| [2030](https://github.com/duplicati/duplicati/issues/2030) | 2016-10-19 | 2025-05-21 | 5 | enhancement | [feature request] Keep backups max file size |
| [2047](https://github.com/duplicati/duplicati/issues/2047) | 2016-10-23 | 2025-05-21 | 4 | enhancement | Resuming backups after connection downtime |
| [2076](https://github.com/duplicati/duplicati/issues/2076) | 2016-11-01 | 2025-05-21 | 0 | UI,enhancement | use big checkboxes everywhere |
| [2115](https://github.com/duplicati/duplicati/issues/2115) | 2016-11-10 | 2025-05-21 | 4 | enhancement | Conditional run of scheduled backup |
| [2148](https://github.com/duplicati/duplicati/issues/2148) | 2016-11-27 | 2025-05-21 | 0 | enhancement | Allow installing the update when backup is pending or server is paused |
| [2153](https://github.com/duplicati/duplicati/issues/2153) | 2016-12-03 | 2025-05-21 | 0 | enhancement | Allow user to manually / automatically add note/description to backup |
| [2185](https://github.com/duplicati/duplicati/issues/2185) | 2016-12-20 | 2025-05-21 | 4 | enhancement | Advanced options cannot be set when restoring files |
| [2189](https://github.com/duplicati/duplicati/issues/2189) | 2016-12-22 | 2025-05-21 | 3 | enhancement | md5 & sha1 inclusion in verification json |
| [2207](https://github.com/duplicati/duplicati/issues/2207) | 2016-12-28 | 2025-05-21 | 2 | enhancement | add GUI option to show changes files |
| [2211](https://github.com/duplicati/duplicati/issues/2211) | 2016-12-28 | 2025-05-21 | 1 | UI,enhancement | When restoring files, Advanced options cannot be selected from list |
| [2228](https://github.com/duplicati/duplicati/issues/2228) | 2017-01-04 | 2025-05-21 | 0 | enhancement |  [restore] skip based on modification date |
| [2230](https://github.com/duplicati/duplicati/issues/2230) | 2017-01-06 | 2025-05-21 | 0 | enhancement | Show metadata in file browser |
| [2238](https://github.com/duplicati/duplicati/issues/2238) | 2017-01-09 | 2025-05-21 | 0 | enhancement | Feature request: Backup Groups |
| [2310](https://github.com/duplicati/duplicati/issues/2310) | 2017-02-10 | 2025-05-21 | 0 | enhancement | General options are not exported |
| [2317](https://github.com/duplicati/duplicati/issues/2317) | 2017-02-13 | 2025-05-21 | 2 | core logic,enhancement | New Feature: Do not backup files present in a backuped archive |
| [2332](https://github.com/duplicati/duplicati/issues/2332) | 2017-02-21 | 2025-05-21 | 20 | core logic,enhancement | No incremental backups of VeraCrypt file containers |
| [2341](https://github.com/duplicati/duplicati/issues/2341) | 2017-02-28 | 2025-05-21 | 1 | UI,enhancement,help wanted,server side | Feature Request: Backups gracefully stopping after x hours to allow other queued |
| [2346](https://github.com/duplicati/duplicati/issues/2346) | 2017-03-02 | 2025-05-21 | 5 | enhancement | Request: During a full restore, how to identify 100% successful backups |
| [2365](https://github.com/duplicati/duplicati/issues/2365) | 2017-03-09 | 2025-05-21 | 3 | core logic,enhancement,help wanted | Log Retention |
| [2368](https://github.com/duplicati/duplicati/issues/2368) | 2017-03-11 | 2025-05-21 | 2 | UI,enhancement,server side | Add an option to lock and/or hid settings / harmful options |
| [2404](https://github.com/duplicati/duplicati/issues/2404) | 2017-03-26 | 2025-05-21 | 3 | enhancement | During repair snapshots are not used |
| [2411](https://github.com/duplicati/duplicati/issues/2411) | 2017-03-29 | 2025-05-21 | 100 | enhancement | Remote Management for Duplicati |
| [2466](https://github.com/duplicati/duplicati/issues/2466) | 2017-05-08 | 2021-09-26 | 8 | UI,enhancement,help wanted | Suggest better values for dblock-size and block size |
| [2470](https://github.com/duplicati/duplicati/issues/2470) | 2017-05-11 | 2020-11-17 | 9 | enhancement | OAuth does not work in China, appspot.com domain seems to be blocked by GFW. |
| [2496](https://github.com/duplicati/duplicati/issues/2496) | 2017-05-22 | 2022-03-25 | 6 | enhancement,help wanted | [Suggestion] [Feaure request] Pushover as alternative to XMPP or email reporting |
| [2544](https://github.com/duplicati/duplicati/issues/2544) | 2017-06-17 | 2018-02-19 | 5 | enhancement,performance issue | Getting "Completing Backup" for over 30 hours now. |
| [2571](https://github.com/duplicati/duplicati/issues/2571) | 2017-06-28 | 2017-06-29 | 6 | enhancement | Default TLS version for WebDAV |
| [2575](https://github.com/duplicati/duplicati/issues/2575) | 2017-06-29 | 2020-11-24 | 17 | enhancement,help wanted | lz4 as compression method |
| [2590](https://github.com/duplicati/duplicati/issues/2590) | 2017-07-09 | 2024-02-17 | 9 | enhancement | [Feature Request] Cloud providers as source data |
| [2630](https://github.com/duplicati/duplicati/issues/2630) | 2017-08-09 | 2019-01-22 | 7 | enhancement | Duplicati stores NAS credentials |
| [2689](https://github.com/duplicati/duplicati/issues/2689) | 2017-09-04 | 2022-06-16 | 6 | enhancement,help wanted | Publish snap(craft) image for Duplicati |
| [2768](https://github.com/duplicati/duplicati/issues/2768) | 2017-09-26 | 2020-11-12 | 8 | documentation,enhancement | Handling of external drives |
| [2769](https://github.com/duplicati/duplicati/issues/2769) | 2017-09-26 | 2017-09-28 | 3 | UI,enhancement | Feature request: Add groups/templates of settings? |
| [2775](https://github.com/duplicati/duplicati/issues/2775) | 2017-09-28 | 2020-05-07 | 7 | enhancement | Feature request: Run jobs in parallel |
| [2804](https://github.com/duplicati/duplicati/issues/2804) | 2017-10-08 | 2017-10-13 | 4 | enhancement | System Proxy: runtime changes are not detected |
| [2811](https://github.com/duplicati/duplicati/issues/2811) | 2017-10-13 | 2024-01-24 | 1 | UI,enhancement,hacktoberfest,help wanted | Improved advanced options editor |
| [2816](https://github.com/duplicati/duplicati/issues/2816) | 2017-10-14 | 2025-06-03 | 5 | core logic,enhancement,hacktoberfest,help wanted | Store temporary files in memory |
| [2848](https://github.com/duplicati/duplicati/issues/2848) | 2017-10-26 | 2018-03-16 | 6 | enhancement,performance issue | SQLite performance problem |
| [2921](https://github.com/duplicati/duplicati/issues/2921) | 2017-12-07 | 2025-05-21 | 9 | enhancement | Bandwith limit based on schedule |
| [2967](https://github.com/duplicati/duplicati/issues/2967) | 2018-01-16 | 2026-05-23 | 7 | enhancement | Android version planned ? |
| [2991](https://github.com/duplicati/duplicati/issues/2991) | 2018-01-30 | 2026-05-30 | 14 | enhancement | [feature request] Changing volume encryption password |
| [3013](https://github.com/duplicati/duplicati/issues/3013) | 2018-02-07 | 2026-05-11 | 14 | enhancement | Support for postgresql/mariadb |
| [3041](https://github.com/duplicati/duplicati/issues/3041) | 2018-02-16 | 2024-02-17 | 7 | UI,enhancement | Minor issue: Improving the State/Progress-Bar text |
| [3069](https://github.com/duplicati/duplicati/issues/3069) | 2018-02-26 | 2018-10-24 | 3 | enhancement | Client SSL certificate |
| [3076](https://github.com/duplicati/duplicati/issues/3076) | 2018-03-04 | 2018-03-04 | 0 | enhancement | Retention Policy - Keep minimum amount of versions |
| [3081](https://github.com/duplicati/duplicati/issues/3081) | 2018-03-05 | 2022-01-26 | 11 | enhancement | Mount backups as real folders |
| [3114](https://github.com/duplicati/duplicati/issues/3114) | 2018-03-19 | 2024-01-18 | 3 | backend enhancement,enhancement | [minor] Web UI doesn't reflect true no. of versions after restoring saved config |
| [3148](https://github.com/duplicati/duplicati/issues/3148) | 2018-04-04 | 2018-04-04 | 0 | enhancement | Run backups skipped on battery power upon connecting to AC power |
| [3179](https://github.com/duplicati/duplicati/issues/3179) | 2018-04-13 | 2018-05-02 | 2 | enhancement | stop all |
| [3188](https://github.com/duplicati/duplicati/issues/3188) | 2018-04-22 | 2024-01-18 | 2 | UI,enhancement | Poor update check UI |
| [3191](https://github.com/duplicati/duplicati/issues/3191) | 2018-04-25 | 2024-01-09 | 0 | UI,enhancement | GUI for backup folder selection (Enhancement) |
| [3211](https://github.com/duplicati/duplicati/issues/3211) | 2018-05-10 | 2024-01-24 | 3 | enhancement | [Enhancement Request] Improve how logging works |
| [3246](https://github.com/duplicati/duplicati/issues/3246) | 2018-05-28 | 2018-05-28 | 0 | enhancement | Add "Export log to file" command / GUI option |
| [3251](https://github.com/duplicati/duplicati/issues/3251) | 2018-05-31 | 2025-01-26 | 8 | enhancement | Add ability to skip missed scheduled backups |
| [3255](https://github.com/duplicati/duplicati/issues/3255) | 2018-06-04 | 2019-08-09 | 6 | core logic,enhancement,performance issue | VM virtual disk files - not deduping  |
| [3264](https://github.com/duplicati/duplicati/issues/3264) | 2018-06-10 | 2024-02-02 | 1 | enhancement,filters | add filter for drive labels |
| [3292](https://github.com/duplicati/duplicati/issues/3292) | 2018-06-22 | 2021-10-03 | 4 | enhancement,local database issue,performance issue | SQLite WAL & Memory mapped files - performance |
| [3369](https://github.com/duplicati/duplicati/issues/3369) | 2018-09-09 | 2018-10-03 | 2 | enhancement | Password isn't being prompted after idle time |
| [3376](https://github.com/duplicati/duplicati/issues/3376) | 2018-09-11 | 2018-10-03 | 6 | enhancement | Using existing backups |
| [3397](https://github.com/duplicati/duplicati/issues/3397) | 2018-09-28 | 2023-07-10 | 1 | enhancement | [Feature request] Show progress during compaction |
| [3408](https://github.com/duplicati/duplicati/issues/3408) | 2018-10-06 | 2018-10-15 | 2 | enhancement | backup only files from list (so that I can filter/include/exclude based on mtime |
| [3416](https://github.com/duplicati/duplicati/issues/3416) | 2018-10-08 | 2022-07-27 | 9 | enhancement | Repair command deletes remote files for new backups |
| [3447](https://github.com/duplicati/duplicati/issues/3447) | 2018-10-20 | 2020-08-23 | 3 | enhancement | Option to log --run-script-before output |
| [3450](https://github.com/duplicati/duplicati/issues/3450) | 2018-10-22 | 2022-03-22 | 2 | backend enhancement,enhancement | [Feature Request] Data output changes |
| [3471](https://github.com/duplicati/duplicati/issues/3471) | 2018-11-04 | 2018-11-04 | 0 | backend enhancement,enhancement | [enhancement] S3 error handling |
| [3477](https://github.com/duplicati/duplicati/issues/3477) | 2018-11-08 | 2018-11-10 | 0 | backend enhancement,enhancement | Suboptimal behavior when disconnecting internet during backup |
| [3478](https://github.com/duplicati/duplicati/issues/3478) | 2018-11-08 | 2018-11-08 | 0 | backend enhancement,enhancement | [Enhancement] Determine --concurrency-compressors based on memory requirements |
| [3479](https://github.com/duplicati/duplicati/issues/3479) | 2018-11-09 | 2018-11-09 | 0 | UI,enhancement | Change icon+text for queued jobs |
| [3487](https://github.com/duplicati/duplicati/issues/3487) | 2018-11-11 | 2024-06-14 | 2 | enhancement | Feature request: Skip next scheduled run |
| [3488](https://github.com/duplicati/duplicati/issues/3488) | 2018-11-12 | 2022-06-20 | 5 | backend enhancement,enhancement | [Enhancement] Multiple Concurrent Running Jobs |
| [3491](https://github.com/duplicati/duplicati/issues/3491) | 2018-11-12 | 2018-11-19 | 1 | enhancement | "Create bug report" should attach latest logs  |
| [3519](https://github.com/duplicati/duplicati/issues/3519) | 2018-11-28 | 2024-02-09 | 0 | UI,enhancement | No indication when running as root that Home=/root/ |
| [3539](https://github.com/duplicati/duplicati/issues/3539) | 2018-12-14 | 2018-12-15 | 3 | core logic,enhancement | Make use of Sqlite Exclusive Locking (PRAGMA locking_mode) |
| [3551](https://github.com/duplicati/duplicati/issues/3551) | 2018-12-20 | 2018-12-20 | 10 | enhancement | Notify user of eminent backup  |
| [3583](https://github.com/duplicati/duplicati/issues/3583) | 2019-01-04 | 2025-03-24 | 2 | enhancement,new backend | Backend support for Azure Data Lake Storage Gen2 |
| [3614](https://github.com/duplicati/duplicati/issues/3614) | 2019-01-18 | 2019-04-09 | 1 | enhancement | Option exclude files smaller than a certain size |
| [3689](https://github.com/duplicati/duplicati/issues/3689) | 2019-03-14 | 2019-08-12 | 2 | enhancement | [Feature Request] xz (lzma2) Compression Module |
| [3694](https://github.com/duplicati/duplicati/issues/3694) | 2019-03-21 | 2019-03-22 | 0 | UI,enhancement | Filesets listed in restore GUI should show file count / size |
| [3701](https://github.com/duplicati/duplicati/issues/3701) | 2019-03-30 | 2024-01-14 | 0 | enhancement | Mobile App |
| [3710](https://github.com/duplicati/duplicati/issues/3710) | 2019-04-03 | 2019-04-04 | 0 | UI,enhancement,server side | Queue manager / ability to sort and cancel jobs in queue? |
| [3711](https://github.com/duplicati/duplicati/issues/3711) | 2019-04-03 | 2024-01-25 | 2 | enhancement | http-send-url doesn't appear to work with Basic Auth URLs |
| [3751](https://github.com/duplicati/duplicati/issues/3751) | 2019-04-25 | 2024-02-02 | 2 | enhancement | Error when backup to S3 DEEP_ARCHIVE storage class |
| [3849](https://github.com/duplicati/duplicati/issues/3849) | 2019-08-04 | 2024-01-04 | 0 | UI,enhancement | Feature Request: Include Run All Button on dashboard |
| [3862](https://github.com/duplicati/duplicati/issues/3862) | 2019-08-17 | 2021-07-02 | 4 | enhancement | ZFS Periodic Snapshot integration |
| [3949](https://github.com/duplicati/duplicati/issues/3949) | 2019-10-17 | 2023-11-27 | 3 | enhancement,installer issue | Distribution through flatpak. |
| [3996](https://github.com/duplicati/duplicati/issues/3996) | 2019-11-21 | 2024-01-30 | 0 | UI,enhancement | Feature Suggestion: Better warnings about Backup failures |
| [4025](https://github.com/duplicati/duplicati/issues/4025) | 2019-12-16 | 2024-01-18 | 3 | enhancement | How to add HTTP Header for send-http reports |
| [4032](https://github.com/duplicati/duplicati/issues/4032) | 2019-12-28 | 2024-01-08 | 9 | enhancement | Feature request -- enable Backups of Mariadb/MySQL and others |
| [4091](https://github.com/duplicati/duplicati/issues/4091) | 2020-02-08 | 2021-05-20 | 7 | enhancement | Feature request: 3 new variables for Send-email |
| [4098](https://github.com/duplicati/duplicati/issues/4098) | 2020-02-12 | 2024-02-07 | 4 | enhancement | Feature Request: Locked files exclusion |
| [4199](https://github.com/duplicati/duplicati/issues/4199) | 2020-05-14 | 2024-01-17 | 2 | enhancement | [s3][minio] Feature request : authentication using OpenID |
| [4238](https://github.com/duplicati/duplicati/issues/4238) | 2020-06-28 | 2024-01-25 | 6 | backend enhancement,enhancement | Duplicati does not understand A records with multiple IP Addresses |
| [4266](https://github.com/duplicati/duplicati/issues/4266) | 2020-07-26 | 2024-11-27 | 14 | docker,enhancement | It will be useful if the Docker Image also have Docker inside  |
| [4317](https://github.com/duplicati/duplicati/issues/4317) | 2020-09-14 | 2026-05-26 | 3 | enhancement | Smart backup retention not deleting partial backups |
| [4334](https://github.com/duplicati/duplicati/issues/4334) | 2020-10-01 | 2021-02-28 | 4 | enhancement | How to use my API key/OAuth ID with Google Drive? |
| [4364](https://github.com/duplicati/duplicati/issues/4364) | 2020-11-14 | 2024-01-13 | 1 | enhancement | Feature request: immutability feature for randsomware protection. S3 / B2 'Objec |
| [4382](https://github.com/duplicati/duplicati/issues/4382) | 2020-12-05 | 2020-12-28 | 10 | enhancement | Add backup job time limit |
| [4389](https://github.com/duplicati/duplicati/issues/4389) | 2020-12-11 | 2024-01-30 | 7 | enhancement,local database issue | Suggestion: Switching to FluentMigrator and Linq2Db for a backup sqlite database |
| [4484](https://github.com/duplicati/duplicati/issues/4484) | 2021-04-11 | 2024-02-01 | 1 | UI,enhancement | Option to disable the automatic "bucket name should start with your username" di |
| [4494](https://github.com/duplicati/duplicati/issues/4494) | 2021-05-03 | 2024-01-25 | 6 | enhancement,installer issue | Add packages for WD in MyCloudOS 5 |
| [4497](https://github.com/duplicati/duplicati/issues/4497) | 2021-05-04 | 2024-01-04 | 0 | enhancement | [Feature proposal] SFTP browsing |
| [4552](https://github.com/duplicati/duplicati/issues/4552) | 2021-06-08 | 2024-01-30 | 0 | enhancement | Implement validation of mail server certificate |
| [4561](https://github.com/duplicati/duplicati/issues/4561) | 2021-06-16 | 2024-02-01 | 2 | enhancement,performance issue | Implement concurrent downloads |
| [4622](https://github.com/duplicati/duplicati/issues/4622) | 2021-10-13 | 2024-01-15 | 1 | UI,enhancement,security | Feature request: Two-factor authentication on Duplicati UI |
| [4630](https://github.com/duplicati/duplicati/issues/4630) | 2021-10-24 | 2024-01-13 | 1 | enhancement | feature request - halt backup after approximately XX GB uploaded (to avoid hitti |
| [4678](https://github.com/duplicati/duplicati/issues/4678) | 2022-02-07 | 2024-01-13 | 3 | UI,enhancement | feature request/ui improvement: add a page to see what files are backed up each  |
| [4681](https://github.com/duplicati/duplicati/issues/4681) | 2022-02-13 | 2022-02-15 | 4 | UI,enhancement | Feature Request: Option for In-Progress Backup Display |
| [4727](https://github.com/duplicati/duplicati/issues/4727) | 2022-05-28 | 2024-01-25 | 1 | enhancement | [question] How to show the file information in restoring window |
| [4734](https://github.com/duplicati/duplicati/issues/4734) | 2022-06-03 | 2024-01-13 | 5 | enhancement | Feature: Qos DSCP packet marking |
| [4830](https://github.com/duplicati/duplicati/issues/4830) | 2022-10-15 | 2022-10-23 | 0 | UI,enhancement | [feature request] Add top-level stats (e.g. duration, size stats) to the log ent |
| [4851](https://github.com/duplicati/duplicati/issues/4851) | 2022-11-20 | 2026-02-20 | 4 | enhancement | Allow setting a timeout between backups instead of scheduling a missed job |
| [4896](https://github.com/duplicati/duplicati/issues/4896) | 2023-02-26 | 2024-02-01 | 1 | backend enhancement,enhancement | Replace default delete dlist action when synchronizing missing files |
| [4920](https://github.com/duplicati/duplicati/issues/4920) | 2023-04-11 | 2023-04-17 | 24 | enhancement | How could I check which file (source file) was silent data corruption by check s |
| [4950](https://github.com/duplicati/duplicati/issues/4950) | 2023-06-01 | 2025-03-27 | 7 | enhancement | Old automatic sqlite backup files in AppData folder are never deleted |
| [4996](https://github.com/duplicati/duplicati/issues/4996) | 2023-07-20 | 2023-12-08 | 0 | UI,enhancement | Feature request: UI guided / wizzard support for "list-broken-files" and "purge- |
| [5166](https://github.com/duplicati/duplicati/issues/5166) | 2024-04-30 | 2025-01-31 | 5 | enhancement | Add nullable support |
| [5212](https://github.com/duplicati/duplicati/issues/5212) | 2024-06-01 | 2024-06-02 | 1 | enhancement | New special environment variable DUPLICATI_BACKUP_SOURCES |
| [5253](https://github.com/duplicati/duplicati/issues/5253) | 2024-07-01 | 2024-08-05 | 2 | enhancement | Duplicati gets an error if --keep-versions and --retention-policy are used at th |
| [5911](https://github.com/duplicati/duplicati/issues/5911) | 2025-01-27 | 2025-03-24 | 4 | enhancement | Add update-backup command to ServerUtil |

### UI 改善 (9件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [3351](https://github.com/duplicati/duplicati/issues/3351) | 2018-08-29 | 2021-08-13 | 5 | UI,filters | Trailing `/` in paths cause confusion -- bad UI design |
| [3611](https://github.com/duplicati/duplicati/issues/3611) | 2019-01-17 | 2025-09-03 | 3 | UI,server side | Solution: The connection to the server is lost -> Request Queue is full |
| [3851](https://github.com/duplicati/duplicati/issues/3851) | 2019-08-04 | 2024-07-16 | 6 | UI | Theme setting should stick across sessions and not be stored in a cookie |
| [4082](https://github.com/duplicati/duplicati/issues/4082) | 2020-02-03 | 2020-02-04 | 2 | UI | Running any Commandline from GUI fails with System.FormatException |
| [4103](https://github.com/duplicati/duplicati/issues/4103) | 2020-02-17 | 2024-01-25 | 1 | UI | Misleading summary of last successful backup and size after force stop/cancel |
| [4121](https://github.com/duplicati/duplicati/issues/4121) | 2020-02-29 | 2024-02-05 | 2 | UI | Build progress display into all operations [incl. "Starting backup ..."] |
| [4169](https://github.com/duplicati/duplicati/issues/4169) | 2020-04-10 | 2020-04-10 | 0 | UI | Jobs not visible in UI after first login after a docker container update.  |
| [4407](https://github.com/duplicati/duplicati/issues/4407) | 2021-01-01 | 2024-01-19 | 4 | UI | web UI isn't functional if system locale isn't set |
| [4599](https://github.com/duplicati/duplicati/issues/4599) | 2021-08-30 | 2021-09-07 | 4 | UI | skip metadata option isn't correctly passed when doing restores via GUI |

### ラベル無し (要トリアージ) (240件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [1684](https://github.com/duplicati/duplicati/issues/1684) | 2016-04-06 | 2025-05-21 | 1 | - | System notification pops up late |
| [1727](https://github.com/duplicati/duplicati/issues/1727) | 2016-04-26 | 2017-10-22 | 14 | - | UnrecognizedReparsePointException |
| [1745](https://github.com/duplicati/duplicati/issues/1745) | 2016-05-03 | 2025-05-21 | 18 | - | Extremely heavy disk I/O resulting in unreasonable performance |
| [1845](https://github.com/duplicati/duplicati/issues/1845) | 2016-07-08 | 2025-05-21 | 2 | - | Duplicati should retry restoring files that failed hash check/failed to restore |
| [2004](https://github.com/duplicati/duplicati/issues/2004) | 2016-10-11 | 2025-05-21 | 5 | - | Can't restore files/folders with special characters in name |
| [2072](https://github.com/duplicati/duplicati/issues/2072) | 2016-10-31 | 2025-05-21 | 1 | - | Add fallback to OAuth code |
| [2229](https://github.com/duplicati/duplicati/issues/2229) | 2017-01-05 | 2025-03-25 | 20 | - | Windows 10 Backup Very Slow |
| [2272](https://github.com/duplicati/duplicati/issues/2272) | 2017-01-20 | 2025-05-21 | 6 | - | Slow OneDrive backup speed |
| [2345](https://github.com/duplicati/duplicati/issues/2345) | 2017-03-02 | 2025-05-21 | 7 | - | Duplicati cannot access any files |
| [2655](https://github.com/duplicati/duplicati/issues/2655) | 2017-08-23 | 2017-10-11 | 4 | - | VSS fails on jobs including files from mounted .vhd volumes and parent drives |
| [2660](https://github.com/duplicati/duplicati/issues/2660) | 2017-08-25 | 2021-08-15 | 5 | - | MacOS Sierra 10.12.6 can't connect to WebDAV backend with digest authentication |
| [2798](https://github.com/duplicati/duplicati/issues/2798) | 2017-10-05 | 2022-10-18 | 4 | - | Duplicati generates WARNINGS for missing folders on restore.  |
| [2925](https://github.com/duplicati/duplicati/issues/2925) | 2017-12-12 | 2024-03-22 | 2 | - | Duplicati 2.0 canari doesn't resume after sleep |
| [2947](https://github.com/duplicati/duplicati/issues/2947) | 2018-01-02 | 2018-01-03 | 2 | - | Repair command is dangerous? |
| [2949](https://github.com/duplicati/duplicati/issues/2949) | 2018-01-03 | 2023-08-08 | 2 | - | HTTP frontend fails if "upgrade" connection header is specified |
| [2955](https://github.com/duplicati/duplicati/issues/2955) | 2018-01-09 | 2019-01-10 | 1 | - | Duplicati 2.0.2 Stall/Freezes/Hangs in Backup to Amazon S3 on Ubuntu 18.04 |
| [2968](https://github.com/duplicati/duplicati/issues/2968) | 2018-01-17 | 2018-05-07 | 3 | - | Duplicati freezes in the middle of backup (SSH backup) |
| [3006](https://github.com/duplicati/duplicati/issues/3006) | 2018-02-03 | 2022-09-23 | 3 | - | Non-existing paths on OneDrive cause internal server error when running Duplicat |
| [3018](https://github.com/duplicati/duplicati/issues/3018) | 2018-02-07 | 2018-02-08 | 0 | - | backup job metadata overwritten on save |
| [3028](https://github.com/duplicati/duplicati/issues/3028) | 2018-02-12 | 2018-02-12 | 0 | - | secure ftp upload errors |
| [3037](https://github.com/duplicati/duplicati/issues/3037) | 2018-02-15 | 2020-08-30 | 16 | - | Corrupt backup cannot be repaired |
| [3038](https://github.com/duplicati/duplicati/issues/3038) | 2018-02-15 | 2024-09-24 | 4 | - | Log-file defined with "--log-file" is not logging errors |
| [3039](https://github.com/duplicati/duplicati/issues/3039) | 2018-02-16 | 2018-06-23 | 5 | - | Built-in Update/Install function on "Update Available" popup fails to restart (r |
| [3057](https://github.com/duplicati/duplicati/issues/3057) | 2018-02-21 | 2018-03-05 | 1 | - | DB name specified in source with ID MyServer\LOCALDB#01F69570\MyDatabase cannot  |
| [3085](https://github.com/duplicati/duplicati/issues/3085) | 2018-03-06 | 2024-05-07 | 4 | - | Found inconsistency in the following files while validating database |
| [3150](https://github.com/duplicati/duplicati/issues/3150) | 2018-04-04 | 2026-04-01 | 6 | - | More precise locale, especially for dates |
| [3159](https://github.com/duplicati/duplicati/issues/3159) | 2018-04-06 | 2026-04-07 | 8 | - | OD4B - No SharePoint web could be logged in to at path 'https://***-my.sharepoin |
| [3163](https://github.com/duplicati/duplicati/issues/3163) | 2018-04-08 | 2023-01-05 | 1 | - | Cryptomator Drive: "Failed to process metadata..." |
| [3178](https://github.com/duplicati/duplicati/issues/3178) | 2018-04-13 | 2023-07-10 | 3 | - | Can't access file even with snapshot enabled, after installing MS Store app. |
| [3220](https://github.com/duplicati/duplicati/issues/3220) | 2018-05-15 | 2024-01-24 | 6 | - | "Removing source Foo because it is a subfolder" causing files to not be backed u |
| [3223](https://github.com/duplicati/duplicati/issues/3223) | 2018-05-16 | 2019-01-02 | 2 | - | local DB downgrade will corrupt backup forever (on destination) |
| [3231](https://github.com/duplicati/duplicati/issues/3231) | 2018-05-22 | 2018-09-28 | 2 | - | Direct Restore from Backend Failing - Found X remote files that are not recorded |
| [3249](https://github.com/duplicati/duplicati/issues/3249) | 2018-05-31 | 2019-05-04 | 1 | - | Failed to create a snapshot: System.Exception: The external command failed to st |
| [3271](https://github.com/duplicati/duplicati/issues/3271) | 2018-06-14 | 2018-06-14 | 0 | - | Restore symlink file missing |
| [3286](https://github.com/duplicati/duplicati/issues/3286) | 2018-06-21 | 2024-02-17 | 3 | - | "One or more errors occurred" with no further information |
| [3295](https://github.com/duplicati/duplicati/issues/3295) | 2018-06-25 | 2018-06-25 | 0 | - | Server left in "stuck" state when network disconnected and --send-to-url not con |
| [3323](https://github.com/duplicati/duplicati/issues/3323) | 2018-07-17 | 2018-07-17 | 2 | - | AggregateException: SQL logic error or missing database cannot commit - no trans |
| [3446](https://github.com/duplicati/duplicati/issues/3446) | 2018-10-19 | 2018-11-17 | 5 | - | Pinentry doesn't capture input correctly, crashes terminal instead |
| [3497](https://github.com/duplicati/duplicati/issues/3497) | 2018-11-15 | 2024-09-04 | 8 | - | Work in openmediavault get error "Cannot send a content-body with this verb-type |
| [3509](https://github.com/duplicati/duplicati/issues/3509) | 2018-11-22 | 2018-11-22 | 0 | - | Duplicati stuck indefinitely due to failed connection to FTPS on LAN (server was |
| [3530](https://github.com/duplicati/duplicati/issues/3530) | 2018-12-05 | 2021-11-05 | 6 | - | Report shows a lot of debug info and questionable info ("Could not find file") |
| [3533](https://github.com/duplicati/duplicati/issues/3533) | 2018-12-09 | 2019-01-01 | 6 | - | Cannot restore database with asymmetric encryption |
| [3535](https://github.com/duplicati/duplicati/issues/3535) | 2018-12-11 | 2024-02-04 | 26 | - | Failed to connect: Error: TrustFailure |
| [3548](https://github.com/duplicati/duplicati/issues/3548) | 2018-12-19 | 2019-01-11 | 8 | - | --auth-password doesn't work with special characters |
| [3570](https://github.com/duplicati/duplicati/issues/3570) | 2018-12-29 | 2022-03-25 | 1 | - | Send-xmpp not working with non-standard C2S port |
| [3588](https://github.com/duplicati/duplicati/issues/3588) | 2019-01-07 | 2019-08-08 | 5 | - | Amazon S3: "Unable to write data to the transport connection: Connection reset b |
| [3590](https://github.com/duplicati/duplicati/issues/3590) | 2019-01-08 | 2021-12-17 | 9 | - | Google-drive - UNIQUE constraint failed |
| [3594](https://github.com/duplicati/duplicati/issues/3594) | 2019-01-09 | 2022-07-29 | 27 | - | Locked files seems to cause corrupt backup |
| [3605](https://github.com/duplicati/duplicati/issues/3605) | 2019-01-14 | 2024-07-13 | 6 | - | Mail not sent after run-script fails |
| [3627](https://github.com/duplicati/duplicati/issues/3627) | 2019-01-25 | 2024-02-16 | 4 | - | Backup failed after a while, then missing files, then cant restore Database |
| [3635](https://github.com/duplicati/duplicati/issues/3635) | 2019-01-29 | 2019-12-15 | 12 | - | Cannot Access File |
| [3683](https://github.com/duplicati/duplicati/issues/3683) | 2019-03-05 | 2023-12-18 | 11 | - | Backup job hangs in the middle of the work |
| [3716](https://github.com/duplicati/duplicati/issues/3716) | 2019-04-05 | 2019-05-08 | 2 | - | gpg: public key decryption failed: No pinentry gpg: decryption failed: No secret |
| [3738](https://github.com/duplicati/duplicati/issues/3738) | 2019-04-17 | 2019-05-05 | 1 | - | Remove the Utility.AsyncHttpRequest class |
| [3752](https://github.com/duplicati/duplicati/issues/3752) | 2019-04-26 | 2024-02-20 | 6 | - | root\virtualization. Hyper-V is probably not installed |
| [3753](https://github.com/duplicati/duplicati/issues/3753) | 2019-04-27 | 2025-05-11 | 4 | - | Error during backup - Abort due to constraint violation UNIQUE constraint failed |
| [3806](https://github.com/duplicati/duplicati/issues/3806) | 2019-07-05 | 2019-07-05 | 1 | - | Update from 2.0.4.15 to 2.0.4.22 simply doesn't happen without manual interventi |
| [3819](https://github.com/duplicati/duplicati/issues/3819) | 2019-07-16 | 2019-07-16 | 0 | - | Set remote volume size and http-operation-timeout automatically based on bandwid |
| [3848](https://github.com/duplicati/duplicati/issues/3848) | 2019-08-04 | 2019-08-05 | 1 | - | Symlinks get restored owned by root instead of actual user |
| [3859](https://github.com/duplicati/duplicati/issues/3859) | 2019-08-15 | 2024-03-08 | 5 | - | XMPP not working in Docker Linux  |
| [3948](https://github.com/duplicati/duplicati/issues/3948) | 2019-10-16 | 2020-04-09 | 2 | - | No site ID was provided while using Sharepoint V2 |
| [3959](https://github.com/duplicati/duplicati/issues/3959) | 2019-10-23 | 2019-10-25 | 2 | - | Not able to work with IPv6 |
| [3985](https://github.com/duplicati/duplicati/issues/3985) | 2019-11-12 | 2024-02-06 | 8 | - | "Create bug report..." button does nothing |
| [3987](https://github.com/duplicati/duplicati/issues/3987) | 2019-11-13 | 2020-12-13 | 23 | - | Backup unexpectedly deleted with custom retention plan and scheduled backup |
| [4015](https://github.com/duplicati/duplicati/issues/4015) | 2019-12-09 | 2025-04-10 | 4 | - | 2.0.4.36 Canary "Fatal" OneDrive 404 not found error after backup |
| [4044](https://github.com/duplicati/duplicati/issues/4044) | 2020-01-07 | 2020-01-08 | 2 | - | RecoveryTool restore: Too many open files |
| [4051](https://github.com/duplicati/duplicati/issues/4051) | 2020-01-11 | 2024-03-16 | 3 | - | Success message after failing to restore files |
| [4155](https://github.com/duplicati/duplicati/issues/4155) | 2020-03-31 | 2020-03-31 | 0 | - | Duplicati throws wrong error when ssh server terminate connexion |
| [4157](https://github.com/duplicati/duplicati/issues/4157) | 2020-04-01 | 2023-08-28 | 8 | - | Limit temporary usage if temp directory isn't big enough |
| [4175](https://github.com/duplicati/duplicati/issues/4175) | 2020-04-19 | 2020-06-16 | 9 | - | Setting USN as required does not always use USN (Windows) |
| [4192](https://github.com/duplicati/duplicati/issues/4192) | 2020-05-07 | 2023-05-18 | 8 | - | Backend OneDrive for Business Errors - "Cannot send a content-body with this ver |
| [4198](https://github.com/duplicati/duplicati/issues/4198) | 2020-05-14 | 2022-08-30 | 11 | - | [s3][minio] MinIO API responded with message=Unsuccessful response from server w |
| [4209](https://github.com/duplicati/duplicati/issues/4209) | 2020-05-25 | 2020-05-26 | 1 | - | [s3][minio] Failing backup with missing files with working connexion to minio |
| [4216](https://github.com/duplicati/duplicati/issues/4216) | 2020-05-31 | 2022-10-22 | 8 | - | backup to google drive freezes on "waiting for the upload to finish" |
| [4218](https://github.com/duplicati/duplicati/issues/4218) | 2020-06-07 | 2020-06-19 | 5 | - | Large SFTP Backup fails with error "Session operation has timed out" / "Could no |
| [4220](https://github.com/duplicati/duplicati/issues/4220) | 2020-06-10 | 2023-12-31 | 13 | - | send-http-level with multiple enum values invalid |
| [4290](https://github.com/duplicati/duplicati/issues/4290) | 2020-08-21 | 2023-05-18 | 5 | - | Support Powershell Pre-Script |
| [4318](https://github.com/duplicati/duplicati/issues/4318) | 2020-09-17 | 2020-09-18 | 2 | - | Backups flagged as "Warning" because Duplicati mistakenly thinks the backend sto |
| [4328](https://github.com/duplicati/duplicati/issues/4328) | 2020-09-26 | 2022-04-26 | 7 | - | rclone storage type may hang when rclone errors unless disable-piped-streaming i |
| [4353](https://github.com/duplicati/duplicati/issues/4353) | 2020-10-27 | 2020-12-06 | 5 | - | Default restore-permissions option is ignored |
| [4468](https://github.com/duplicati/duplicati/issues/4468) | 2021-03-13 | 2021-03-13 | 0 | - | Restore impossible permissions in Rootless Docker don't result in warning or err |
| [4507](https://github.com/duplicati/duplicati/issues/4507) | 2021-05-12 | 2021-05-16 | 1 | - | Purge-Broken-Files not fixing problem |
| [4523](https://github.com/duplicati/duplicati/issues/4523) | 2021-05-27 | 2021-05-27 | 0 | - | Create separate issues for TODO-DNC markers |
| [4530](https://github.com/duplicati/duplicati/issues/4530) | 2021-05-27 | 2021-05-27 | 0 | - | Fix OS notifications |
| [4532](https://github.com/duplicati/duplicati/issues/4532) | 2021-05-27 | 2021-05-27 | 2 | - | Replace usages of WebClient, WebRequest and HttpWebRequest |
| [4533](https://github.com/duplicati/duplicati/issues/4533) | 2021-05-27 | 2021-05-28 | 0 | - | Rewrite thread interruption code |
| [4534](https://github.com/duplicati/duplicati/issues/4534) | 2021-05-27 | 2021-09-04 | 5 | - | Make all backends async |
| [4535](https://github.com/duplicati/duplicati/issues/4535) | 2021-05-27 | 2022-02-15 | 2 | - | Replace custom web server with Kestrel implementation |
| [4536](https://github.com/duplicati/duplicati/issues/4536) | 2021-05-27 | 2021-05-27 | 0 | - | Remove AlphaFS if possible |
| [4538](https://github.com/duplicati/duplicati/issues/4538) | 2021-05-27 | 2021-05-27 | 0 | - | Verify functionality of BackendTester |
| [4539](https://github.com/duplicati/duplicati/issues/4539) | 2021-05-27 | 2021-05-27 | 0 | - | Verify functionality of BackendTool |
| [4540](https://github.com/duplicati/duplicati/issues/4540) | 2021-05-27 | 2021-05-27 | 0 | - | Verify functionality of ConfigurationImporter |
| [4541](https://github.com/duplicati/duplicati/issues/4541) | 2021-05-27 | 2021-05-27 | 0 | - | Verify functionality of RecoveryTool |
| [4544](https://github.com/duplicati/duplicati/issues/4544) | 2021-05-28 | 2021-05-28 | 0 | - | Fix assumptions about relative paths |
| [4545](https://github.com/duplicati/duplicati/issues/4545) | 2021-05-28 | 2021-05-28 | 1 | - | X509Certificate2.X509Certificate2 isn't supported on macOS |
| [4546](https://github.com/duplicati/duplicati/issues/4546) | 2021-05-28 | 2021-05-28 | 0 | - | RSACryptoServiceProvider.RSACryptoServiceProvider isn't supported on Linux and m |
| [4554](https://github.com/duplicati/duplicati/issues/4554) | 2021-06-11 | 2021-06-11 | 1 | - | Embedded resources are missing on experimental/net5-split branch |
| [4586](https://github.com/duplicati/duplicati/issues/4586) | 2021-08-07 | 2022-10-16 | 3 | - | Remote file referenced ... but not found in list, registering a missing remote f |
| [4627](https://github.com/duplicati/duplicati/issues/4627) | 2021-10-20 | 2024-02-05 | 2 | - | error 400 on large header requests |
| [4671](https://github.com/duplicati/duplicati/issues/4671) | 2022-01-30 | 2022-01-30 | 0 | - | Add operation phase for verifying database consistency |
| [4675](https://github.com/duplicati/duplicati/issues/4675) | 2022-02-02 | 2025-10-28 | 4 | - | Duplicati freezes during backup or fails with unknown error due to Remote (SSH)  |
| [4709](https://github.com/duplicati/duplicati/issues/4709) | 2022-04-18 | 2022-06-10 | 1 | - | Backup stalls at verification |
| [4711](https://github.com/duplicati/duplicati/issues/4711) | 2022-04-19 | 2024-03-07 | 7 | - | No files with the backup prefix duplicati, but found the following backup prefix |
| [4719](https://github.com/duplicati/duplicati/issues/4719) | 2022-05-16 | 2025-01-05 | 4 | - | Cannot dismiss notifications/warnings browser flooded with net::ERR_INSUFFICIENT |
| [4733](https://github.com/duplicati/duplicati/issues/4733) | 2022-06-02 | 2024-04-01 | 12 | - | Can't connect using SSH-SFTP |
| [4737](https://github.com/duplicati/duplicati/issues/4737) | 2022-06-06 | 2024-10-28 | 8 | - | FTPES connection stopped working only on duplicati (returning 426) |
| [4750](https://github.com/duplicati/duplicati/issues/4750) | 2022-06-16 | 2022-06-16 | 1 | - | Cannot exclude Hyper-V VSS Writer on Windows Client version |
| [4753](https://github.com/duplicati/duplicati/issues/4753) | 2022-06-19 | 2023-11-01 | 4 | - | Not backing up filenames with ANSI encoding |
| [4792](https://github.com/duplicati/duplicati/issues/4792) | 2022-07-19 | 2024-02-02 | 3 | - | HTTP Report URL not working if there are lots of warnings in the backup |
| [4795](https://github.com/duplicati/duplicati/issues/4795) | 2022-07-22 | 2022-08-20 | 1 | - | Restore from OneDrive stalls after initiating CommitBlockMarker |
| [4798](https://github.com/duplicati/duplicati/issues/4798) | 2022-07-26 | 2022-08-06 | 2 | - | macOS 12.5: no Restore-Points "undefined" |
| [4799](https://github.com/duplicati/duplicati/issues/4799) | 2022-07-29 | 2022-09-25 | 17 | - | Duplicati tries and fails to access excluded file that is partially locked |
| [4803](https://github.com/duplicati/duplicati/issues/4803) | 2022-08-05 | 2022-08-05 | 0 | - | Storage Class Error @S3 Compatible |
| [4814](https://github.com/duplicati/duplicati/issues/4814) | 2022-09-03 | 2022-09-03 | 0 | - | Support github apt latest release  |
| [4818](https://github.com/duplicati/duplicati/issues/4818) | 2022-09-13 | 2022-09-13 | 0 | - | Fail if --restore-path has no path |
| [4827](https://github.com/duplicati/duplicati/issues/4827) | 2022-10-14 | 2022-10-14 | 0 | - | Restore function does not work |
| [4831](https://github.com/duplicati/duplicati/issues/4831) | 2022-10-15 | 2023-07-22 | 7 | - | FTPS (both TLS 1.2, TLS 1.3) broken with new FileZilla FTP server versions on Wi |
| [4832](https://github.com/duplicati/duplicati/issues/4832) | 2022-10-18 | 2022-10-29 | 6 | - | If an upload to Storj fails mid-way on the first backup, it makes all subsequent |
| [4833](https://github.com/duplicati/duplicati/issues/4833) | 2022-10-19 | 2024-10-01 | 8 | - | Web UI is not shown after the installation (400 error) |
| [4845](https://github.com/duplicati/duplicati/issues/4845) | 2022-11-09 | 2022-11-30 | 1 | - | S3 Compatible slow uploading when s3-signatureversion only 4 |
| [4846](https://github.com/duplicati/duplicati/issues/4846) | 2022-11-17 | 2024-02-01 | 1 | - | Revoked AuthID keeps working |
| [4878](https://github.com/duplicati/duplicati/issues/4878) | 2022-12-08 | 2023-06-07 | 1 | - | Storj DCS destination with API key does not work |
| [4984](https://github.com/duplicati/duplicati/issues/4984) | 2023-06-29 | 2023-06-29 | 0 | - | Test failure in DisruptionTests / Inconsistent partial backup behavior |
| [5007](https://github.com/duplicati/duplicati/issues/5007) | 2023-08-15 | 2023-08-15 | 0 | - | Database recreate does not catch missing encryption configuration |
| [5035](https://github.com/duplicati/duplicati/issues/5035) | 2023-09-26 | 2023-10-02 | 4 | - | re-created dindex file lacked list folder, so DB recreate ran pass 1 of dblock d |
| [5045](https://github.com/duplicati/duplicati/issues/5045) | 2023-10-19 | 2023-10-19 | 2 | - | unscheduling a job might not prevent it from running |
| [5055](https://github.com/duplicati/duplicati/issues/5055) | 2023-11-07 | 2023-12-29 | 2 | - | Enabling all-versions leads to confusing/broken behavior when selecting files to |
| [5082](https://github.com/duplicati/duplicati/issues/5082) | 2024-01-14 | 2024-02-15 | 3 | - | Alternative FTP backend misuses low level interfaces |
| [5087](https://github.com/duplicati/duplicati/issues/5087) | 2024-01-21 | 2025-02-07 | 5 | - | Ctrl-C on Windows doesn't interrupt, though it gives that appearance |
| [5092](https://github.com/duplicati/duplicati/issues/5092) | 2024-02-01 | 2024-02-23 | 7 | - | Deleting a backup should revoke the oauth token |
| [5093](https://github.com/duplicati/duplicati/issues/5093) | 2024-02-03 | 2024-02-03 | 0 | - | GUI backup job Progress: shows a percent sign without a number for an empty file |
| [5102](https://github.com/duplicati/duplicati/issues/5102) | 2024-02-19 | 2024-03-08 | 16 | - | Storj backups are failing - out of storage allowance, but error message didn't s |
| [5113](https://github.com/duplicati/duplicati/issues/5113) | 2024-03-05 | 2024-03-06 | 0 | - | sometimes hangs when FTP destination refuses login |
| [5114](https://github.com/duplicati/duplicati/issues/5114) | 2024-03-07 | 2024-03-08 | 5 | - | Unable to schedule backup to S3 |
| [5131](https://github.com/duplicati/duplicati/issues/5131) | 2024-03-17 | 2024-04-04 | 4 | - | "Unexpected difference in fileset version X", also not possible to delete versio |
| [5136](https://github.com/duplicati/duplicati/issues/5136) | 2024-03-25 | 2024-04-04 | 3 | - | TrayIcon crashed during backup, with .NET runtime exception code c0000005 |
| [5139](https://github.com/duplicati/duplicati/issues/5139) | 2024-04-02 | 2024-04-04 | 4 | - | S3 Minio SDK Connection Test - False Error |
| [5156](https://github.com/duplicati/duplicati/issues/5156) | 2024-04-23 | 2024-04-29 | 3 | - | Incorrect marking in the Source Data tab |
| [5175](https://github.com/duplicati/duplicati/issues/5175) | 2024-05-05 | 2024-06-29 | 5 | - | snapshot-policy USN plus attribute exclude may exclude all selected files |
| [5186](https://github.com/duplicati/duplicati/issues/5186) | 2024-05-13 | 2024-10-24 | 6 | - | Tray icon didn't show unpause on computer wake, while GUI icon did |
| [5205](https://github.com/duplicati/duplicati/issues/5205) | 2024-05-27 | 2024-07-31 | 5 | - | Remove the `use-ssl` flag and logic |
| [5210](https://github.com/duplicati/duplicati/issues/5210) | 2024-05-30 | 2024-06-01 | 2 | - | Incompatible NuGet packages for .NET 8 |
| [5224](https://github.com/duplicati/duplicati/issues/5224) | 2024-06-05 | 2024-06-14 | 4 | - | Tray icon disappears when backup starts |
| [5226](https://github.com/duplicati/duplicati/issues/5226) | 2024-06-05 | 2025-10-01 | 8 | - | Duplicati crashes when Storj backup starts, with no logs |
| [5239](https://github.com/duplicati/duplicati/issues/5239) | 2024-06-20 | 2024-06-20 | 0 | - | Rework the direct recovery process in the UI |
| [5240](https://github.com/duplicati/duplicati/issues/5240) | 2024-06-20 | 2024-06-27 | 12 | - | Improve direct restore speed |
| [5242](https://github.com/duplicati/duplicati/issues/5242) | 2024-06-21 | 2024-06-21 | 2 | - | Improve recovery tool usecases |
| [5244](https://github.com/duplicati/duplicati/issues/5244) | 2024-06-23 | 2024-06-27 | 1 | - | The Database Has Version 12 but the Largest Supported Version Is Version 10 (Upd |
| [5248](https://github.com/duplicati/duplicati/issues/5248) | 2024-06-27 | 2024-08-13 | 2 | - | TrayIcon Quit may cause icon to go away but leave Duplicati up |
| [5250](https://github.com/duplicati/duplicati/issues/5250) | 2024-06-30 | 2024-07-01 | 1 | - | VSS snapshot-policy gets into slow hard to spot etilqs reading SQL driven SQL |
| [5268](https://github.com/duplicati/duplicati/issues/5268) | 2024-07-17 | 2026-03-27 | 4 | - | IOException: Stale file handle |
| [5273](https://github.com/duplicati/duplicati/issues/5273) | 2024-07-18 | 2024-07-18 | 0 | - | Update TrayIcon to use websocket |
| [5398](https://github.com/duplicati/duplicati/issues/5398) | 2024-08-03 | 2024-08-04 | 2 | - | Backup fails because file can't be found |
| [5421](https://github.com/duplicati/duplicati/issues/5421) | 2024-08-12 | 2025-01-08 | 2 | - | Standardize argument parsing |
| [5440](https://github.com/duplicati/duplicati/issues/5440) | 2024-08-13 | 2024-08-14 | 0 | - | Implement optional RTL (right-to-left) layout |
| [5457](https://github.com/duplicati/duplicati/issues/5457) | 2024-08-15 | 2024-08-15 | 0 | - | Add screenshot test for visual regressions |
| [5482](https://github.com/duplicati/duplicati/issues/5482) | 2024-08-26 | 2024-08-27 | 1 | - | Support for stopping/pausing backups on metered connections  |
| [5553](https://github.com/duplicati/duplicati/issues/5553) | 2024-09-10 | 2024-09-10 | 1 | - | Detect low-power standby or no-network situations with the scheduler |
| [5554](https://github.com/duplicati/duplicati/issues/5554) | 2024-09-11 | 2024-11-11 | 5 | - | 有计划支持多线程和自定义其他数据库类型吗？ |
| [5590](https://github.com/duplicati/duplicati/issues/5590) | 2024-10-15 | 2025-03-24 | 0 | - | Backup of wsl filesystem should respect hidden files |
| [5591](https://github.com/duplicati/duplicati/issues/5591) | 2024-10-15 | 2025-03-24 | 2 | - | Improve first-visit experience |
| [5594](https://github.com/duplicati/duplicati/issues/5594) | 2024-10-19 | 2025-03-24 | 0 | - | Support for Passkey Password-less Login |
| [5599](https://github.com/duplicati/duplicati/issues/5599) | 2024-10-25 | 2025-03-24 | 0 | - | Create scripts for installing Duplicati |
| [5601](https://github.com/duplicati/duplicati/issues/5601) | 2024-10-25 | 2025-03-24 | 3 | - | Allow custom backup file suffixes instead of having to end with .zip.aes. |
| [5602](https://github.com/duplicati/duplicati/issues/5602) | 2024-10-27 | 2025-07-11 | 10 | - | Database reorder |
| [5635](https://github.com/duplicati/duplicati/issues/5635) | 2024-11-05 | 2025-03-24 | 3 | - | Remove `Library.Utility.Uri` |
| [5647](https://github.com/duplicati/duplicati/issues/5647) | 2024-11-07 | 2025-11-29 | 5 | - | Improve the updater to download the updated package and install it |
| [5649](https://github.com/duplicati/duplicati/issues/5649) | 2024-11-07 | 2025-03-24 | 6 | - | Support for (Free-)BSD |
| [5663](https://github.com/duplicati/duplicati/issues/5663) | 2024-11-09 | 2025-03-24 | 0 | - | Rename packageId from `osx` to `macos` |
| [5675](https://github.com/duplicati/duplicati/issues/5675) | 2024-11-14 | 2025-03-24 | 0 | - | Running the Agent on MacOS should be able to access documents |
| [5759](https://github.com/duplicati/duplicati/issues/5759) | 2024-12-11 | 2025-03-24 | 0 | - | Improve TemporaryFamily usage in tokens |
| [5764](https://github.com/duplicati/duplicati/issues/5764) | 2024-12-12 | 2025-03-24 | 2 | - | Possibility to directly backup into Proton Drive |
| [5794](https://github.com/duplicati/duplicati/issues/5794) | 2024-12-19 | 2025-03-24 | 3 | - | Make theme a server saved setting |
| [5853](https://github.com/duplicati/duplicati/issues/5853) | 2025-01-07 | 2025-03-24 | 3 | - | Remove warnings on restore for auto-created folders |
| [5912](https://github.com/duplicati/duplicati/issues/5912) | 2025-01-27 | 2025-03-24 | 2 | - | Add support for restarting the webserver by API |
| [5915](https://github.com/duplicati/duplicati/issues/5915) | 2025-01-27 | 2025-03-24 | 0 | - | Improve the way filelists are recorded in the database |
| [5916](https://github.com/duplicati/duplicati/issues/5916) | 2025-01-27 | 2025-05-07 | 1 | - | Support parallel downloads |
| [5917](https://github.com/duplicati/duplicati/issues/5917) | 2025-01-27 | 2025-03-24 | 0 | - | Add HEAD operation to IBackend |
| [5932](https://github.com/duplicati/duplicati/issues/5932) | 2025-01-30 | 2025-04-14 | 5 | - | Add option to automatically create database if none exists |
| [5933](https://github.com/duplicati/duplicati/issues/5933) | 2025-01-30 | 2025-03-24 | 3 | - | Support temporary backup configurations for restore purposes |
| [5934](https://github.com/duplicati/duplicati/issues/5934) | 2025-01-30 | 2025-03-24 | 2 | - | Add support for a `.duplicati-ignore` file |
| [5942](https://github.com/duplicati/duplicati/issues/5942) | 2025-02-05 | 2025-03-24 | 0 | - | Prioritise restore jobs over backup jobs |
| [5992](https://github.com/duplicati/duplicati/issues/5992) | 2025-02-27 | 2025-03-24 | 1 | - | Exclude self-folder when running in Docker |
| [6074](https://github.com/duplicati/duplicati/issues/6074) | 2025-03-23 | 2025-03-25 | 4 | - | Feature Request: Backup Job Option "rsync mirror" |
| [6112](https://github.com/duplicati/duplicati/issues/6112) | 2025-03-31 | 2025-03-31 | 0 | - | Customize the file name extensions stored on the backup destination. |
| [6133](https://github.com/duplicati/duplicati/issues/6133) | 2025-04-07 | 2025-05-31 | 1 | - | Integrate remote synchronization into the main flow |
| [6149](https://github.com/duplicati/duplicati/issues/6149) | 2025-04-11 | 2025-04-12 | 7 | - | Error option for empty source folder |
| [6152](https://github.com/duplicati/duplicati/issues/6152) | 2025-04-12 | 2025-04-12 | 1 | - | Allow recreate database process to continue |
| [6190](https://github.com/duplicati/duplicati/issues/6190) | 2025-04-23 | 2025-04-30 | 2 | - | Check if any other backup is using the same destination |
| [6209](https://github.com/duplicati/duplicati/issues/6209) | 2025-04-29 | 2025-05-26 | 8 | - | Shards path configuration |
| [6216](https://github.com/duplicati/duplicati/issues/6216) | 2025-04-30 | 2025-04-30 | 0 | - | Automatic code coverage reporting |
| [6221](https://github.com/duplicati/duplicati/issues/6221) | 2025-04-30 | 2025-11-10 | 2 | - | Ability to download via browser |
| [6228](https://github.com/duplicati/duplicati/issues/6228) | 2025-05-03 | 2025-05-03 | 0 | - | Add an unfreeze / thaw command |
| [6251](https://github.com/duplicati/duplicati/issues/6251) | 2025-05-13 | 2025-05-23 | 3 | - | "Failed to create built-in ZIP archive" Central directory warnings |
| [6252](https://github.com/duplicati/duplicati/issues/6252) | 2025-05-13 | 2025-05-15 | 2 | - | disable-file-scanner GUI status is negative, misleading, yet maybe useful |
| [6297](https://github.com/duplicati/duplicati/issues/6297) | 2025-05-25 | 2025-06-02 | 1 | - | Support for proxy configuration |
| [6304](https://github.com/duplicati/duplicati/issues/6304) | 2025-05-28 | 2025-06-16 | 5 | - | Start Backup automatically when drive connects |
| [6305](https://github.com/duplicati/duplicati/issues/6305) | 2025-05-28 | 2025-05-28 | 0 | - | Remove concurrent index file generation |
| [6308](https://github.com/duplicati/duplicati/issues/6308) | 2025-05-30 | 2026-01-27 | 1 | - | DUPLICATI_PRELOAD_SETTINGS_DEBUG=1 fails, stops TrayIcon console output |
| [6325](https://github.com/duplicati/duplicati/issues/6325) | 2025-06-10 | 2025-06-10 | 0 | - | Improve restore for multi-drive setups on Windows |
| [6327](https://github.com/duplicati/duplicati/issues/6327) | 2025-06-10 | 2025-06-10 | 2 | - | Implement rate-limit for requests per second |
| [6376](https://github.com/duplicati/duplicati/issues/6376) | 2025-06-29 | 2025-06-29 | 1 | - | Delete broken remote files |
| [6391](https://github.com/duplicati/duplicati/issues/6391) | 2025-07-04 | 2025-07-04 | 0 | - | Add option to expand environment variables when importing a backup |
| [6443](https://github.com/duplicati/duplicati/issues/6443) | 2025-07-31 | 2025-07-31 | 0 | - | Support setting machine-id from the UI |
| [6460](https://github.com/duplicati/duplicati/issues/6460) | 2025-08-06 | 2025-08-06 | 1 | - | Potentially broken uploads for B2 backend |
| [6490](https://github.com/duplicati/duplicati/issues/6490) | 2025-08-28 | 2026-05-21 | 5 | - | Reduce idle CPU usage |
| [6531](https://github.com/duplicati/duplicati/issues/6531) | 2025-09-27 | 2025-12-21 | 2 | - | Can't change base href with X-Forwarded-Prefix |
| [6535](https://github.com/duplicati/duplicati/issues/6535) | 2025-10-01 | 2025-10-02 | 1 | - | Backup as User - SQLiteException: unable to open database file |
| [6537](https://github.com/duplicati/duplicati/issues/6537) | 2025-10-04 | 2026-02-24 | 3 | - | Docker non-stable image tags  |
| [6551](https://github.com/duplicati/duplicati/issues/6551) | 2025-10-16 | 2026-06-24 | 8 | - | Sql server backup - No source folders specified for backup |
| [6557](https://github.com/duplicati/duplicati/issues/6557) | 2025-10-22 | 2025-10-31 | 1 | - | Mark docker image as "offical" on Docker-hub |
| [6575](https://github.com/duplicati/duplicati/issues/6575) | 2025-10-30 | 2025-11-01 | 2 | - | SQLiteException: constraint failed\r\nUNIQUE constraint failed: FilesetEntry.Fil |
| [6578](https://github.com/duplicati/duplicati/issues/6578) | 2025-10-30 | 2025-10-30 | 0 | - | System improvements :rchitectural Refactoring Proposal for Stability (SQLite WAL |
| [6597](https://github.com/duplicati/duplicati/issues/6597) | 2025-11-03 | 2025-11-03 | 0 | - | Minor race condition when restoring from files |
| [6603](https://github.com/duplicati/duplicati/issues/6603) | 2025-11-04 | 2025-11-15 | 1 | - | New UI does not work with Forever Token |
| [6607](https://github.com/duplicati/duplicati/issues/6607) | 2025-11-05 | 2025-12-04 | 2 | - | GPG: Backup without using the private key |
| [6611](https://github.com/duplicati/duplicati/issues/6611) | 2025-11-06 | 2025-11-07 | 2 | - | FR: Advanced Settings / Current settings and their source |
| [6621](https://github.com/duplicati/duplicati/issues/6621) | 2025-11-09 | 2025-11-09 | 1 | - | Problems with non-utf byte strings |
| [6626](https://github.com/duplicati/duplicati/issues/6626) | 2025-11-10 | 2025-11-10 | 1 | - | Backup failed in dblock upload has blocks treated as present in dlist. Restore f |
| [6629](https://github.com/duplicati/duplicati/issues/6629) | 2025-11-12 | 2026-01-20 | 18 | - | Large Azure Storage Blobs backend backups fail consistently after upgrade to 2.2 |
| [6639](https://github.com/duplicati/duplicati/issues/6639) | 2025-11-18 | 2025-11-19 | 1 | - | Connection test with FTPS fails even though duplicati-access-privileges-test.tmp |
| [6676](https://github.com/duplicati/duplicati/issues/6676) | 2025-12-11 | 2026-05-08 | 1 | - | Error while running Index was outside the bounds of the array. |
| [6683](https://github.com/duplicati/duplicati/issues/6683) | 2025-12-14 | 2026-01-05 | 4 | - | SynologyNAS WebDAV: Found X files that are missing from the remote storage |
| [6706](https://github.com/duplicati/duplicati/issues/6706) | 2026-01-13 | 2026-01-13 | 0 | - | Duplicati Upload Fails to Storj Bucket with Object Lock Enabled |
| [6744](https://github.com/duplicati/duplicati/issues/6744) | 2026-02-01 | 2026-03-25 | 1 | - | RESTORE causes constant writes to the TEMP directory and 100% SSD usage writing  |
| [6748](https://github.com/duplicati/duplicati/issues/6748) | 2026-02-05 | 2026-02-05 | 0 | - | The database rebuild failed |
| [6759](https://github.com/duplicati/duplicati/issues/6759) | 2026-02-09 | 2026-04-06 | 4 | - | Scheduled tasks do not start any more |
| [6767](https://github.com/duplicati/duplicati/issues/6767) | 2026-02-16 | 2026-02-16 | 0 | - | SMB Error: Failed to write to file, difference between bytes read and bytes writ |
| [6819](https://github.com/duplicati/duplicati/issues/6819) | 2026-03-26 | 2026-03-26 | 0 | - | Can't connect to my SMB share |
| [6827](https://github.com/duplicati/duplicati/issues/6827) | 2026-04-05 | 2026-05-14 | 6 | - | OneDrive for Business does not work anymore |
| [6829](https://github.com/duplicati/duplicati/issues/6829) | 2026-04-08 | 2026-05-19 | 7 | - | Local backup to USB drive has ridiculous 12 threads by default during restore |
| [6831](https://github.com/duplicati/duplicati/issues/6831) | 2026-04-08 | 2026-06-19 | 2 | - | Remote control claim never completes, machine stays in "click to claim" / "IsReg |
| [6835](https://github.com/duplicati/duplicati/issues/6835) | 2026-04-10 | 2026-05-28 | 7 | - | Add Movistar cloud as backend |
| [6837](https://github.com/duplicati/duplicati/issues/6837) | 2026-04-10 | 2026-04-10 | 0 | - | Duplicati does not allow the system to go to sleep even after all backups have f |
| [6840](https://github.com/duplicati/duplicati/issues/6840) | 2026-04-14 | 2026-04-14 | 1 | - | Duplicati.GUI.TrayIcon on Windows causes heavy CPU usage while screen is off |
| [6863](https://github.com/duplicati/duplicati/issues/6863) | 2026-04-25 | 2026-04-25 | 0 | - | Restored parent directory ownership does not match original when it does not exi |
| [6865](https://github.com/duplicati/duplicati/issues/6865) | 2026-04-28 | 2026-04-28 | 1 | - | Direct restore from SMB/UNC network repository has become unreliable / unusable |
| [6866](https://github.com/duplicati/duplicati/issues/6866) | 2026-04-28 | 2026-05-09 | 10 | - | Failed to create a snapshot: 0x80042316 as of 2.3.0.0 |
| [6867](https://github.com/duplicati/duplicati/issues/6867) | 2026-04-29 | 2026-04-29 | 0 | - | TrayIcon status is not synchronized when awaking |
| [6872](https://github.com/duplicati/duplicati/issues/6872) | 2026-04-30 | 2026-05-07 | 3 | - | longpolltime and LONGPOLL_TIMEOUT too long for HTTPS |

### その他 (55件)

| # | 作成 | 最終更新 | 💬 | ラベル | タイトル |
|---|---|---|---:|---|---|
| [1741](https://github.com/duplicati/duplicati/issues/1741) | 2016-04-29 | 2025-05-21 | 1 | backend enhancement | Update error handling in B2 backend |
| [1884](https://github.com/duplicati/duplicati/issues/1884) | 2016-08-11 | 2025-05-21 | 3 | backend issue | 2.0.1.18 issue with google drive No filesets found on remote target |
| [1904](https://github.com/duplicati/duplicati/issues/1904) | 2016-08-27 | 2025-05-21 | 3 | documentation | add info how to create debug log to template |
| [1918](https://github.com/duplicati/duplicati/issues/1918) | 2016-09-04 | 2025-05-21 | 13 | new backend | Add Yandex Disk WebDAV predefined backend |
| [1922](https://github.com/duplicati/duplicati/issues/1922) | 2016-09-05 | 2025-04-22 | 1 | installer issue | USE OBS |
| [1996](https://github.com/duplicati/duplicati/issues/1996) | 2016-10-10 | 2025-05-21 | 0 | documentation | "Best practices" document needed for type of disks used for database and tempdir |
| [2149](https://github.com/duplicati/duplicati/issues/2149) | 2016-11-29 | 2025-05-21 | 2 | backend issue | Google Drive: "Path on server" does not pick up shared folder |
| [2171](https://github.com/duplicati/duplicati/issues/2171) | 2016-12-12 | 2025-05-21 | 7 | windows | Errors on symlinks created with WSL |
| [2193](https://github.com/duplicati/duplicati/issues/2193) | 2016-12-23 | 2025-05-21 | 1 | backend enhancement | include x-amz-server-side-encryption AWS S3 |
| [2650](https://github.com/duplicati/duplicati/issues/2650) | 2017-08-18 | 2024-02-17 | 4 | documentation,local database issue | CLI : purge-broken-files ignores the configured database path. |
| [2889](https://github.com/duplicati/duplicati/issues/2889) | 2017-11-11 | 2025-05-21 | 18 | performance issue | Recreating broken  DB takes forever [$25] |
| [2893](https://github.com/duplicati/duplicati/issues/2893) | 2017-11-12 | 2024-01-22 | 6 | backend enhancement | Feature Request: Gdrive AppFolder |
| [2931](https://github.com/duplicati/duplicati/issues/2931) | 2017-12-17 | 2024-01-17 | 5 | performance issue | CREATE TEMPORARY TABLE "UsageReport takes hours to complete |
| [3100](https://github.com/duplicati/duplicati/issues/3100) | 2018-03-13 | 2018-03-31 | 13 | documentation | Creating MSI package for customized version of Duplicati. |
| [3175](https://github.com/duplicati/duplicati/issues/3175) | 2018-04-12 | 2021-08-13 | 0 | filters | Default filter for `control_dir_v2` should take into account the OEM settings pa |
| [3190](https://github.com/duplicati/duplicati/issues/3190) | 2018-04-25 | 2018-04-27 | 0 | performance issue | All VolumeUploadRequests' CreateIndexVolume are true, which might lead to runnin |
| [3194](https://github.com/duplicati/duplicati/issues/3194) | 2018-04-27 | 2023-10-22 | 38 | performance issue | Canary 2.0.3.6 and slow queries |
| [3197](https://github.com/duplicati/duplicati/issues/3197) | 2018-04-28 | 2019-03-19 | 1 | MacOS | Mac OSX Fresh Install Duplicati won't load |
| [3362](https://github.com/duplicati/duplicati/issues/3362) | 2018-09-05 | 2024-05-27 | 7 | backend enhancement | Feature request: Prometheus metrics |
| [3364](https://github.com/duplicati/duplicati/issues/3364) | 2018-09-06 | 2025-04-22 | 2 | performance issue | Bad UX when recreating database |
| [3671](https://github.com/duplicati/duplicati/issues/3671) | 2019-02-21 | 2020-04-20 | 0 | linux | Using LVM Snapshot - Unable to determine volume group |
| [3688](https://github.com/duplicati/duplicati/issues/3688) | 2019-03-13 | 2025-03-24 | 2 | new backend | Support mail.ru backend |
| [3870](https://github.com/duplicati/duplicati/issues/3870) | 2019-08-25 | 2020-12-16 | 4 | windows | JUNCTIONS not correctly restored |
| [3875](https://github.com/duplicati/duplicati/issues/3875) | 2019-08-28 | 2025-05-30 | 13 | backend issue | “Google Drive (full access) login” restricted in early 2020 |
| [4045](https://github.com/duplicati/duplicati/issues/4045) | 2020-01-09 | 2024-02-06 | 2 | windows | 2.0.5.0_experimental - Denied access to System Volume Information gives a Warnin |
| [4056](https://github.com/duplicati/duplicati/issues/4056) | 2020-01-20 | 2024-01-16 | 0 | performance issue | Performance issue with Debian/Docker |
| [4101](https://github.com/duplicati/duplicati/issues/4101) | 2020-02-15 | 2020-04-03 | 1 | translation | Translation of "hibernate" to Finnish |
| [4125](https://github.com/duplicati/duplicati/issues/4125) | 2020-03-03 | 2020-03-03 | 0 | performance issue | Understanding file enumeration performance |
| [4134](https://github.com/duplicati/duplicati/issues/4134) | 2020-03-12 | 2021-08-13 | 4 | documentation,filters | Documentation: improve page on 'how filters work' |
| [4230](https://github.com/duplicati/duplicati/issues/4230) | 2020-06-17 | 2020-07-24 | 2 | backend issue | Incorrect warning when backup to Google Team Drives exceeds Google personal driv |
| [4411](https://github.com/duplicati/duplicati/issues/4411) | 2021-01-02 | 2021-01-07 | 43 | MacOS | Internationalisation bug? |
| [4481](https://github.com/duplicati/duplicati/issues/4481) | 2021-04-11 | 2022-02-01 | 15 | performance issue | Insufficient memory to continue the execution of the program |
| [4628](https://github.com/duplicati/duplicati/issues/4628) | 2021-10-21 | 2025-03-24 | 1 | new backend | Native nextcloud integration |
| [4635](https://github.com/duplicati/duplicati/issues/4635) | 2021-11-07 | 2021-11-09 | 6 | windows | Warning exist when trying to restore file |
| [4636](https://github.com/duplicati/duplicati/issues/4636) | 2021-11-07 | 2022-11-08 | 3 | tests | Unit tests can fail trying to load Duplicati.Library.Backend.OneDrive.dll when r |
| [4645](https://github.com/duplicati/duplicati/issues/4645) | 2021-12-02 | 2023-06-27 | 26 | local database issue,performance issue | Backup gets stuck executing a query |
| [4673](https://github.com/duplicati/duplicati/issues/4673) | 2022-01-31 | 2025-12-22 | 21 | new backend | Add support for cloudflare R2 |
| [4710](https://github.com/duplicati/duplicati/issues/4710) | 2022-04-18 | 2022-04-18 | 0 | backend enhancement | Consider migrating to Google Drive API v3 |
| [4783](https://github.com/duplicati/duplicati/issues/4783) | 2022-07-02 | 2025-03-24 | 7 | new backend | IDrive Backend removed |
| [4786](https://github.com/duplicati/duplicati/issues/4786) | 2022-07-07 | 2025-07-01 | 3 | installer issue | Please make autorun link in Windows for current user not for all (ask for defaul |
| [4808](https://github.com/duplicati/duplicati/issues/4808) | 2022-08-14 | 2024-02-05 | 4 | backend enhancement,performance issue | Improvement: Set asynchronous-concurrent-upload-limit to 1 when destination is " |
| [4908](https://github.com/duplicati/duplicati/issues/4908) | 2023-03-20 | 2023-06-01 | 8 | backend issue | Storj-backup fails and not possible to "delete and repair" |
| [4926](https://github.com/duplicati/duplicati/issues/4926) | 2023-04-23 | 2023-06-01 | 3 | performance issue | Direct Restore from Backup works 100% correct, but is waaaaaaaaaay tooooo sloooo |
| [4992](https://github.com/duplicati/duplicati/issues/4992) | 2023-07-14 | 2024-08-01 | 1 | security | JQuery is significantly out of date with multiple XSS vulnerabilities  |
| [5086](https://github.com/duplicati/duplicati/issues/5086) | 2024-01-21 | 2026-05-16 | 9 | new backend | Add Support for Proton Drive |
| [5637](https://github.com/duplicati/duplicati/issues/5637) | 2024-11-05 | 2025-03-24 | 0 | new backend | Add support for Seagate Lyve |
| [5662](https://github.com/duplicati/duplicati/issues/5662) | 2024-11-09 | 2025-03-24 | 0 | installer issue | Add scripts to install the Agent |
| [5885](https://github.com/duplicati/duplicati/issues/5885) | 2025-01-17 | 2025-03-24 | 2 | help wanted,installer issue,windows | Add support for WiX v5 |
| [6058](https://github.com/duplicati/duplicati/issues/6058) | 2025-03-19 | 2025-03-19 | 0 | new backend | Add support for Oracle Cloud storage |
| [6174](https://github.com/duplicati/duplicati/issues/6174) | 2025-04-16 | 2025-06-12 | 2 | installer issue,windows | Bundle VC redist with MSi |
| [6182](https://github.com/duplicati/duplicati/issues/6182) | 2025-04-21 | 2025-07-07 | 1 | installer issue | Distribute duplicati with official Linux repositories |
| [6349](https://github.com/duplicati/duplicati/issues/6349) | 2025-06-15 | 2026-06-06 | 8 | new backend | Native Internxt integration |
| [6365](https://github.com/duplicati/duplicati/issues/6365) | 2025-06-24 | 2025-11-09 | 2 | new backend | Support Terabox as a storage destination |
| [6396](https://github.com/duplicati/duplicati/issues/6396) | 2025-07-07 | 2025-07-07 | 1 | linux | Support for disable-sleep on Linux |
| [6546](https://github.com/duplicati/duplicati/issues/6546) | 2025-10-12 | 2025-10-31 | 6 | performance issue | Use hard links instead of copying when the backup files and the temporary workin |

