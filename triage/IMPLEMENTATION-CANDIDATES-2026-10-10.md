# 実装候補 2026-10-10（Issue の再調査 3 回目）

open Issue 594 件（10-10 取得）のうち、triage のどのファイルでも深掘りしていないもの（本レポートの §5 付録にだけ出るもの）480 件、機能要望・質問などのラベルを除いた 264 件、2024 年以降に動きのある 171 件を出した。タイトルでバグの報告らしく Windows で外部アカウントなしに確かめられそうな 32 件を選び、4 つのサブエージェント（A: Web サーバー・UI、B: トレイ・スケジューラー・スリープ・認証、C: DB・コア・列挙、D: 暗号化・バックエンドほか）で Issue・コメント・master `95a8adcc`（ngclient は手元の 0.0.240）のコードを読んだ。**どれも読んだだけで実行していない**。上位 4 件の要の主張だけ自分でコードを読んで確かめた（下の「確かめた」）。

## 順位（直す価値があり、手元で確かめられるもの）

| 順 | Issue | 一文 | 確かめた | 再現 | 規模・場所 |
|---|---|---|---|---|---|
| 1 | [#1757](https://github.com/duplicati/duplicati/issues/1757)（と #5603） | 自分の DB をバックアップしようとしてロックで失敗。`BackupHandler.GetBlacklistedPaths` は `Dbpath + "-journal"` だけを除くが、[`322e4f15`](https://github.com/duplicati/duplicati/commit/322e4f15e)（2025-06）で WAL が既定になり、生きているのは `-wal`・`-shm`。#5603 の修正（[`30075265`](https://github.com/duplicati/duplicati/commit/300752652)）が古くなった | `BackupHandler.cs:146-151` と `SQLiteLoader.cs:143` を読んだ。`-wal`/`-shm` はコードのどこにもない | dbpath をソースの中にしてバックアップ、`-wal`・`-shm` が fileset に入らない・警告なし（Windows、ローカルのバックエンド） | 極小。2 行 |
| 2 | [#6819](https://github.com/duplicati/duplicati/issues/6819) | `server min protocol = SMB3_11` の Samba に繋がらない。SMBLibrary 1.5.4 は SMB 3.1.1 を出さない（1.5.5 で `SMB2Client(enableSMB311Support)` が入った、とサブエージェント） | csproj が 1.5.4、`SMBShareConnection.cs:95` が引数なしの `new SMB2Client()` | Samba の Docker（`server min protocol = SMB3_11`）。fork CI の CIFS の testcontainers でも | 小。パッケージの更新と 1 引数。CIFS と同じプロジェクトなので API の差を確かめる |
| 3 | [#2566](https://github.com/duplicati/duplicati/issues/2566) + [#2443](https://github.com/duplicati/duplicati/issues/2443) | GPG の後始末が固定の 5 秒（`m_t.Join(5000)`）で、遅い gpg だと `GPGFlushError`。そのとき出力の stream が閉じられ、まだ書いている Runner のスレッド（try/catch なし）が `ObjectDisposedException` でプロセスごと落ちる（#2443 の stack と同じ） | `GPGStreamWrapper.cs:48-60` を読んだ | 入力を読み切ってから数秒待つ偽の gpg（`--gpg-program-path`） | 小。待ち方とスレッドの例外。1 PR で両方 |
| 4 | [#4719](https://github.com/duplicati/duplicati/issues/4719) | 通知が数千あると「すべて消す」で ERR_INSUFFICIENT_RESOURCES。ngclient（`forkJoin`）も ngax も 1 件ずつ DELETE を一斉に出し、サーバーは 1 件ずつの DELETE しかなく、1 件ごとに全件を読む | `Notification.cs:39` が個別の DELETE だけ、ngclient の `notifications.state.ts:138` が `forkJoin` | 通知を約 2,000 件入れて「すべて消す」 | 中。サーバーに一括 DELETE（C# でテスト可）＋ ngclient（別リポ）。ngclient だけで並列数を絞るのは小 |
| 5 | [#2171](https://github.com/duplicati/duplicati/issues/2171) | WSL のシンボリックリンク（reparse tag `0xA000001D`）は `LinkTarget` が null で普通のファイル扱い、開けずに警告。`--symlink-policy=ignore` も効かない（見立て） | 未確認 | WSL で `ln -s`、Windows からバックアップ | 中。restore でどう戻すかの判断が要る |

## 閉じてよさそうなもの（見立てのまま、コメント案は未作成）

- A: #4627・#4833（古い HttpServer のヘッダーの上限、Kestrel で解消 `235568da`）、#3611（プロキシの設定、今は WebSocket）、#3985（キューの順番待ちで設計どおり、新しい UI で表示を改善）、#4711（このメッセージはもう出ない、UI が先頭の `/` を警告）
- B: #5186（#7408・#7396・#7407）、#2925（ネイティブの電源通知 `3f4eb39a`・`379f05a5`＋#7396・#7407）、#1226（ngclient の日付修正と #7085）、#5114（コンテナの DNS）、#5136（.NET Framework のトレイはもうない）
- C: #4045（#7258）、#3286（非同期化とメッセージ）、#3085（`baf52549`・`d18ba56f` で repair と purge-broken-files の道ができた）、#2298（`a8a32ea1`）、#2744（古い UI、再報告を依頼）、#3753（ぶら下がったリンクで試してから）
- D: #5102（#5120、2.0.7.101）、#6214（`CLI_ARGS` は linuxserver.io、2.1.0.5 の壊れたビルド）、#3020（落ちる経路は消えた、プロキシ認証は要望）

## 判断待ち・見送り

- #5508（スリープ後のログアウト）: refresh token の再利用検出（30 秒・drift 1）の設計の話。ngclient で起きるか確認を頼む程度
- #5786（WebDAV の割り当てドライブをソースに）: 手元で再現できるが原因は未診断
- #4407（ロケールなしの Linux）、#5156（古い UI の表示）、#5224（Linux の Avalonia）、#5092（OAuth の revoke、要望で外部アカウントが要る）、#5465（ngax の翻訳ツール）

## ついでに気づいたもの（どれも推測、別 Issue 相当）

- ngclient のスケジュールの既定の日付が `new Date().toISOString().split('T')[0]`（`schedule.component.ts:252,343`）で UTC の日付。JST の 9 時前は前日になる
- `Localizations/duplicati/extract.sh` が全 `.cs` を `tr -d "\r"` で書き換える（改行が混在するリポジトリで破壊的）。**→ 10-12 に実測（251 ファイル・49,103 行が変わる）して `fix/extract-keeps-line-endings`（`aad55af8`）で修正、`PENDING-BRANCHES.md` に記録**。後続（推測）: `Duplicati/WebserverCore/Services/LoginProvider copy.cs`（`eaf6fe5f`、2025-05 に入った複製らしきファイル）が置き去りかもしれない。**→ 10-12 に確認: 置き去りではなく名前だけの誤り**（中身は `ProgressStateProviderService`、`IProgressStateProviderService` の唯一の実装で `ServiceCollectionsExtensions.cs:72` で DI 登録。2024-03-15 の WIP `32e852a3` で入った）。利用者の指示で、子セッション（rename-loginprovider-cop）が `ProgressStateProviderService.cs` への改名を `chore/rename-progress-state-provider-file` で作業中。実行時の訳の照合も確認済み（`MoLocalizationService.cs:149` が探す前に `\r\n` を `\n` にするので、CR を落とした .pot と一致、追加の修正は不要）。WSL の gettext は apt で削除済み
- ~~recreate が、孤立した dindex の指す dblock を Temporary として登録しブロックを残す（`RecreateDatabaseHandler.cs:494-523`、#5136 のコメントから）~~ → **10-30 に使い捨ての試験で否定（検証済み、master `31bf7aa0`、Windows）**。`Issue6552` と同じ手順（1 回目の dblock と dlist を消し、その dindex だけを戻して DB を消す）で recreate すると、警告 3 件（`MissingFileDetected` と、`CleanupMissingVolumesAsync` を 588 行と 739 行で 2 回呼ぶための `MissingVolumesDetected` 2 件。10-30 の 2 回目の確認で全文を出すと 1 件目は「there are now 1 missing volumes」、2 件目は「now 0」で、最初に「同じ文面が 2 回」と書いたのは出力が途中で切れていたための誤り。2 件目が最後の状態を正しく言っている）は出るが、終わった DB に Temporary の dblock もそのブロックも残らない（RemoteVolume は dlist・dblock・dindex 2 つが Verified だけ）。そのあと list-broken-files・backup・`--full-remote-verification` の test・restore（A と B の中身が一致）はすべて errors=0・warnings=0。孤立した dindex は宛先に残り、recreate のたびに同じ警告 3 件が出る。compact（deleted=0）では消えず、既存の DB での repair が消す（その後の recreate は警告 0）。直すほどの害はないので見送り。残る食い違いは `LocalRecreateDatabase.cs:1374` のコメント「次の compact まで残す」だけ（実際に消すのは既存の DB での repair の `DeletingEmptyIndexFile`、compact は消さない）。試験は scratchpad の `ProbeOrphanDindex.cs`（リポジトリには入れていない）

## 後続の候補（10-11、実装中に見つかったもの）

### #3848（`fix/restore-symlink-owner`、`15fe8fc5`）から

- **推奨 1**（推測、未検証）: リンクの拡張属性がリンク先に付く疑い。`SystemIOLinux.SetMetadata` は拡張属性を `PosixFile.SetExtendedAttribute`（Mono の `setxattr`、リンクをたどる）で書くが、`GetExtendedAttributes` は `llistxattr`/`lgetxattr` でリンク自身から読む。Linux では `user.*` をリンクに付けられないので、再現は root で `trusted.*`（例: `setfattr -h -n trusted.dup3848 -v x link`）。直すならリンクには `lsetxattr`。赤→緑は `RestoreSymlinkMetadataTests` の流儀（root でなければ skip）。同じテストファイルを触るなら `fix/restore-symlink-owner` のマージ待ち（積まない）
- **推奨 2**（検証済み）: legacy の restore でリンクだけを restore すると、警告 `NoFilesOrFoldersRestored`（「Restore completed without errors but no files or folders were restored」）。リンクは restore されている。新しいエンジンでは出ない。`RestoreHandler.cs` が restore した数にシンボリックリンクを数えていない見込み（推測）。再現: ファイルとそのリンクをバックアップし、`restore-legacy=true` で `RestoreAsync(new[] { linkPath })`
- 記録だけ 3: `--restore-symlink-metadata` の説明文（`Strings.cs` の `RestoresymlinkmetadataLong` と duplicati/documentation）の「リンク先が変わることが多い」は、修正後の Linux ではほぼ当てはまらない。#3848 の PR のマージ後に直す
- 記録だけ 4（設計の判断）: `lchown` はリンク先に影響しないので、`--restore-permissions` だけでもリンクの所有者を戻す案（Issue の利用者の期待はたぶんこれ）。オプションの意味が変わるので先にメンテナーに聞く。PR 本文で触れる程度。**→ 10-22 に利用者が B に決定: コードは変えず、メンテナーに聞く文の案（PR 本文か Issue のコメント）だけ作る、投稿はしない**。**10-22 に案を `issue-drafts/symlink-owner-restore-permissions.md` に作成し、利用者の指示で案 1 を #7524 として投稿**（置き場所は新しい Issue がお勧め、#3848 へのコメント・`fix/restore-symlink-metadata-help` の PR 本文の案も同じファイルにある）。macOS では restorePermissions の中で ACL と file flags もリンク自身に当たるので、A にするなら所有者だけか ACL/flags もかを決める必要あり。拡張属性は SetMetadata の先頭で restorePermissions に関係なく当たるので、A の実装は所有者だけの経路が要る（コード、未検証）
- 記録だけ 5: `SystemIOLinux.FileSetLastWriteTimeUtc` にデバッグの名残に見える `Console.Error.WriteLine($"DISS: ...")`（コードで確認）。小さな掃除の PR 向き
- 候補外: macOS では `lchmod` でリンク自身の権限を変えられるが、修正では飛ばした（実害はほぼない）
- WSL の注意: root で `dotnet test` を流すとテスト用フォルダーが root の持ち物になり、その後の非 root の実行が全件 `UnauthorizedAccessException`。Git Bash から `wsl -u root -- chown` を呼ぶときは `MSYS_NO_PATHCONV=1` が要る

### #4719（`fix/notifications-dismiss-all`、`8acad422`）から（10-11 に別セッションで着手）

- 同じバックアップの警告の通知が実行ごとに溜まる（`Runner.cs` 1387・1440 行付近の競合ハンドラ `(n, a) => n`、#4719 の根本の原因）: 方針を調べて提案するセッション
- 成功時の片付け（`Runner.cs` 1402–1414 行付近）が 1 件ずつ消す、登録・取得・削除が毎回全件を読む: 直すセッション（`fix/notification-queries`）

### Template レポート（`fix/report-template-output`、`0830b070`）から

- **1（マージ待ち）**: `default.hbs` の `{{#eachProperty Data}}` が結果オブジェクトを再帰的に全部出す。CLI で受けた本文は `Results:` に `TaskControl`・`WaitHandle`・Handle 番号・`BackendStatistics` の重複などが出て約 400 行（検証済み）。場所は `TemplateFormatSerializer.cs` の `eachProperty`（リフレクションで全公開プロパティ）と `Templates/default.hbs`。案: `email.hbs` のように主要な項目を明示的に並べる、または `eachProperty` をプリミティブだけ・深さ制限付きにする
- **2（マージ待ち）**: Handlebars の既定の HTML エスケープがテキストのレポートにかかる。同じ本文に `IEnumerableSkipTakeIterator&#x60;1`（検証済み）。マシン名やバックアップ名に `& < > \`` があると化ける。場所は `TemplateFormatSerializer` のコンストラクター（`Handlebars.Create`）。案: `html.hbs` 以外は NoEscape、またはテンプレート側で `{{{ }}}`
- 1 と 2 は、独自テンプレートのオプション（Template の件の 3）の前提条件。テンプレートが読み込まれるのは `fix/report-template-output` から なので、そのマージ後に master から作る（積まない）
- **3（独立）**: `ReportHelper.ReplaceTemplate` の `Regex.Replace(input, "\%RESULT\%", <結果>, ...)` が置換文字列の `$` をパターンとして解釈する（推測、未検証）。結果やログ行に `$1`・`$&` があると本文が壊れる。Template に限らず Duplicati 形式にも関係し、他の `%key%` の置換にも同じ形。案: `MatchEvaluator`（`_ => value`）で渡す。まず `$1` を含むログ行で赤になるテスト
- **ドキュメントの不足**（duplicati/documentation）: `*-result-output-format` の説明では値が「Duplicati, Json」だけで、Template がない（`community-docs/community-docs-advanced-options.md`、`sending-telegram-notifications.md`）。Handlebars の記述は 0 件（`gh search code` で確認）。テンプレートの変数一覧（OperationName / ParsedResult / BackupName / MachineName / MachineId / OperatingSystem / Data / LogLines / Exception）と同梱テンプレート名の説明は、`fix/report-template-output` のマージ後にドキュメント側の PR で出す。独自テンプレートのオプションを実装するなら、その説明も同じ PR に入れる

### 通知の全件読み込み（`fix/notification-queries`、`14ae6beb`）から

- 未確認のフラグ（`UnackedWarning` / `UnackedError`）を設定するたびに、値が変わらなくても `ServerSettings.SetAndSaveSetting` → `SaveSettings` が設定を全部書き直し、`SignalSettingsChanged` が `LastDataUpdateId` の加算・設定の更新の通知・スロットルと電源モードの更新を毎回出す（推測、未計測）。修正後も登録と削除に 1 件あたり約 40〜70ms 残るのはおそらくこれ。案: 値が同じなら保存も通知もしない

### legacy の restore の数え方（`fix/legacy-restore-counts-symlinks`、`bdc451c0`）から

- `IRestoreResults.RestoredSymlinks` は、どちらの restore エンジンでも増やされず常に 0（検証済み、全履歴で一度も増やされていない: 2013 年 `d69667059` で `SymlinksRestored` として追加、2018 年 `965bd6d76` で改名）。表示しているのは旧 UI ngax の restore-items.html だけ（ngclient とドキュメントは使っていない）。**見送り**（利用者に推奨）。直すなら A: ファイルとして数えたまま RestoredSymlinks にも足す（二重に数える）か、B: ファイルの数から移す（RestoredFiles と「何も restore されなかった」警告の条件が変わる）を利用者が決め、`fix/legacy-restore-counts-symlinks` のマージ後に始める
- 新しいエンジンの `FileProcessor` の TODO「legacy restore doesn't count metadata restore as a restored file」: **不具合ではない**（検証済み）。`WriteMetadata` が true を返すのはリンクを作ったときだけ（`FileRestoreDestinationProvider.cs:149/217/311`）なので、メタデータだけの restore はどちらのエンジンでも数えない。TODO は新しいエンジンを legacy に揃えた `eb64320a4` のメモで、`IssueTests.Issue5825RestoreNoOverwriteAsync` が両方で RestoredFiles=0 を確かめて通っている。`RestoreVolumeCacheDiskPressureAsync` のタイムアウトは、この環境だけの話として利用者の判断で不要

### `%RESULT%` の置換（`fix/report-replace-literal`、`d5d87eec`）から（どちらも検証済みのバグ、利用者は実装予定、Windows の再起動のため保留）

- **1（`fix/report-replace-literal` のマージ後）**: `ReportHelper.ReplaceTemplate` で、キー名がエスケープされずに正規表現のパターンに入る。`send-http-extra-parameters` のキーに `(` があると、既定の本文でもレポートが 1 件も届かない（`RegexParseException` の警告だけ）。`.` があると別のキーにも一致する。直すなら `Regex.Escape`。同じ行を触るので、マージ後に master から作る
- **2（`fix/report-template-output` との重なりを先に確かめる）**: `%RESULT%` を展開した後の `%key%` の置換と `%…%` の除去が、結果の中にもかかる。ログ行の `50%_a%b` の間が消え、`%backup-name%` が展開される（再現には `allow-paths-in-log-messages=true`）。「`%RESULT%` を最後に展開する」では直らない（Duplicati 形式のシリアライザーの見出しが、後で展開されるキーを含むため）
- どちらも upstream の Issue は未検索。詳細は別セッションの共有ノート `report-template-followups.md`

### #2171（`fix/wsl-symlink-policy`、`f912ec9a`）の追加の確認から

- Windows の通常のシンボリックリンク（NT、例: `sub\up -> ..\real.txt`）を Linux に復元すると、ターゲットがバックスラッシュのまま（`up -> ..\real.txt`、`--allow-restore-outside-target-directory` の true/false どちらでも）になり、Linux ではたどれないリンクになる（検証済み: Windows の CLI でバックアップし、WSL でビルドした Linux 版 CLI で ext4 に復元、`od -c` と `cat`）。#2171 とは関係ない以前からの挙動（LX リンクのターゲットはもともと `/` 区切り）。upstream でタイトルに symlink を含む Issue の範囲では該当なし。直す（復元時に区切り文字を変換する）かは利用者の判断
- 見送り（候補にしない）: `--symlink-policy=follow` では、WSL のリンクのターゲットが Linux パスなので警告が残る。`/mnt/c/...` を Windows パスに変換すればたどれるが、意味が変わるので勧めない。Issue のコメントにある「`MetadataPreProcess` で `GetSymlinkTarget` が try で囲まれていない」は、今のコードでは try/catch で囲まれていて解決済み
- マージ時の注意（`PENDING-BRANCHES.md` の行にも記載済み）: #7447（`fix/restore-junction-as-junction`）も `SystemIOWindows.Win32API` に `FILE_FLAG_OPEN_REPARSE_POINT`・`FILE_FLAG_BACKUP_SEMANTICS` を足しているので、後からマージする側で rebase して片方の定義を消す。`DeviceIoControl` は引数の型が違うオーバーロードなので両方残せる見込み（推測）

### 未確認フラグ（`fix/unacked-flag-save-on-change`、`76c130bd`）から（低負荷で計測し直して確定、前の見立ての 2 点は誤り）

- 計測（master / `76c130bd` / `76c130bd`+`14ae6beb` の dll を順番を入れ替えて交互に、CPU 13〜37%、未確認の通知 200 件・フラグは変わらない）: 登録 1 件 7.7〜9.6 → 4.7〜6.5 → 2.9〜3.3ms、削除 1 件 10.7〜13.1 → 4.4〜6.2 → 3.0〜3.5ms、400 回の操作あたりの設定の保存 600 → 0 回。2 つを合わせてもコンフリクトなし、両方のテスト 9 件緑
- 確定: 設定の保存 1 回は約 3〜4ms（前の 6〜7ms は CPU 100% の下の数字）。`76c130bd` の後に残る約 2ms は通知の全件読みで、`14ae6beb` で消える。値が変わるときの速さは前後で同じ
- **訂正（誤りだった）**: 「`SaveSettings` がロックの外で列挙する」→ 遅延評価の列挙は `OverwriteAndUpdateDb` の foreach（1585 行）で `SetSettings` の lock の中（6 スレッド × 300 回 × 3 回で例外 0）。「`UpdatedVersion`/`LastUpdateCheck` は頻繁に書かれる」→ 更新の確認 1 回につき数回、既定の間隔は 1W
- 候補 A（低）: 設定の保存で Option の全行を DELETE + INSERT（1 回 3〜4ms）。通知まわりは保存がほぼなくなったので、残る効果はまれな経路だけ
- 候補 B（判断）: ほかのプロパティにも広げる件。速さの得はほぼない（更新の通知を受けるのは `WebsocketAccessor` の 1 か所、電源モード・throttle・usage reporter は今の値から計算し直すだけ）。書き方を揃えるかの判断
- **→ 10-22 に利用者が候補 A・B とも見送りに決定**（効果が小さいわりに設定の保存という影響の大きい箇所を触るため。#7506 のレビューで要望が出たら考える）
- 未計測: 合わせた状態に残る約 3ms の内訳

### リンクの拡張属性（`fix/restore-symlink-xattr`、`9cb7c8ee`）から（master `f921ee53` を WSL の非 root で実測、どれも未修正）

- **バグ（検証済み）**: `--symlink-policy=follow` でバックアップすると、リンク先の拡張属性が restore で失われる。リンク先に `user.dupprobe` を付けて follow でバックアップし restore すると `after: plain=probe-value link=<none: ENODATA>`（対照の普通のファイルには戻る）。原因はコードで確認: `PosixFile.GetExtendedAttributes` が名前は `listxattr`（たどる）で取るのに、値は常に `lgetxattr`（リンク自身）で取る。非 root の `user.*` でテストが書け、`9cb7c8ee` とは独立して master から直せる
- **検証済み（直し方は判断が要る）**: 拡張属性を書けない FS（ramfs）へ restore すると、`setxattr` が `EOPNOTSUPP` で失敗しても `warnings=0 errors=0` で、属性は黙って落ちる（`SetExtendedAttribute` が戻り値を見ない）。直すと非対応の FS への restore で毎回警告が出るので、警告か Verbose かはメンテナーの判断
- **問題なし（コードで確認）**: macOS の flags・ACL の restore は、リンクのとき `lchflags`・`acl_set_link_np` を使いリンクをたどらない（`PosixFile.cs` 515–521 行、587–603 行）。実機では未実行

### OS をまたぐリンクの区切り（`fix/restore-symlink-target-separator`）の追加の確認から

- **バグ（検証済み、原因は推測）**: Windows のバックアップを Linux で元の場所に復元する（`--restore-path` なし）と、`/C/Users/...` ではなくカレントディレクトリの下の `C:/Users/...` に書かれる（両エンジン）。upstream に同じ報告はない。原因の見込みは `LocalRestoreDatabase.SetTargetPathsAsync` の UNC 用の UPDATE が `ELSE "Path"` で、直前の UPDATE が作った `\C\...` を上書きしていること（コードを読んだだけ）。詳細は共有ノートの `cross-os-original-location-restore.md`、子セッションが提案カード `task_3106b5da` を出した。**→ 10-11 に `fix/cross-os-original-location-restore`（`a72ec0a5`）で修正、原因は見込みどおり（`ELSE "Path"` → `ELSE "Targetpath"`）。`PENDING-BRANCHES.md` に記録**
- 同じ確認で、rebase 後（`3074dfea`）のテストは Windows 17 件緑・1 件 skip、WSL 16 件緑・2 件 skip、Windows→Linux の CLI の実地、元の場所への復元、ディレクトリへのリンクもすべて緑（検証済み）。macOS は対象外
- **バグ（検証済み、未修正）**: legacy エンジンは `--dry-run` でも復元したファイルの検証（`RestoreHandler.cs` の `PerformRestoredFileVerification` のループ）をするので、同じ OS で空の `--restore-path` に dry-run すると「Failed to restore file … Could not find file」のエラーが出る（新しいエンジンでは出ない）。upstream に該当なし。詳細は共有ノートの `cross-os-original-location-restore.md`。**→ 10-11 に `fix/legacy-dry-run-skip-verification`（`ac6f694f`）で修正、`PENDING-BRANCHES.md` に記録**
- **バグ（検証済み、未対応）**: legacy は、`--skip-restore-verification` を付けた通常の復元でも「Restored 0 files」と出す（新しいエンジンは 1）。原因は dry-run と同じで、件数を検証ループの中でしか数えていないため。`fix/legacy-dry-run-skip-verification` に足すか別にするかを、区切りのセッションが利用者に聞いている。**→ 10-12 に同じブランチ・同じコミット（`63acca3e`）に入れて修正**


## documentation リポジトリと 2.4.0.1 の照合で見つかった本体側の不具合（10-11、利用者から。未着手）

documentation リポジトリを 2.4.0.1（v2.4.0.1_stable_2026-10-07）の実装と照合した別の作業で見つかった 6 件。行番号は 2.4.0.1 のもの。**10-11 に master `85d15280` のソースにどれも残っていることを grep で確かめた（コードを読んだだけ、実行はしていない）**。upstream の Issue・PR は未検索。直すときはテーマごとにまとめる（1 件 1 PR に分けすぎない）。2 は既定値を変えるかの判断が要るので、方針を決める前に利用者に確認する。

| # | 内容 | 報告の根拠 | master `85d15280` で確かめたこと | 種類 |
|---|---|---|---|---|
| 1 | **`--s3-list-api-version` が AWS クライアントで効かない（実害あり）**。宣言しているオプション名は `s3-list-api-version`（`S3Backend.cs:43`・`:428`）なのに、`S3AwsClient.cs:121` は別のキー `list-api-version` を読む | 2.4.0.1 の CLI と、URL を記録するだけの偽 S3 サーバーで `duplicati-cli list "s3://bucket/pfx?...&s3-server-name=localhost:18099&use-ssl=false" --no-encryption --no-local-db=true`: オプションなしと `--s3-list-api-version=v2` はどちらも `GET /bucket/?delimiter=%2F&max-keys=1000&prefix=pfx%2F`（v1）、`--list-api-version=v2` だと `list-type=2` が付く | `S3AwsClient.cs:121` が `GetValueOrDefault("list-api-version", "v1")`、`S3Backend.cs:43` が `S3_LIST_API_VERSION_OPTION = "s3-list-api-version"` | コード。キー名の修正とテスト（送ったリクエストに `list-type=2` が付くことを確かめる） |
| 2 | **`help aes` の `--aes-version` の既定値の表示が 3、実際は 2**。表示は `SharpAESCrypt.EncryptionOptions.Default.FileVersion`（`AESEncryption.cs:232`）、実際は `:143-145` の「Until the next stable release, use version 2 by default」で `version = 2`。その「次の stable」の 2.4.0.0 はもう出ている | 作ったファイルのヘッダーが `AES` + バイト 2 | `AESEncryption.cs:143`・`:145`・`:232` に同じ行 | **判断が要る**: 既定値を 3 に切り替える予定だったのか、表示を 2 に直すのか。利用者に確認してから |
| 3 | **`--webservice-pre-auth-tokens` の help のヘッダー名が違う**。`RestAPI/Strings.cs:87` は `Authentication: PreAuth <token>`、実際に受け付けるのは `Authorization: PreAuth <token>` | 以前、プロキシ経由で `Authorization` を付けると 200、付けないと 401 | `Strings.cs:87` に `Authentication: PreAuth <token>`、`WebserverCore/Services/PreAuthTokenHandler.cs:65` は `Request.Headers["Authorization"]` を読む | ヘルプ文 |
| 4 | **RecoveryTool の help.txt が、存在しないトピック `help backends` を案内している**（`CommandLine/RecoveryTool/help.txt:45`）。宛先の一覧は `help` の "Targets:" 行、オプションは `help <宛先名>`（例: `help s3`） | 2.4.0.1 の Duplicati.CommandLine で `help backends` → `Topic not found: backends` | `help.txt:45` に同じ行 | ヘルプ文 |
| 5 | **`help smb` に「環境変数 AUTH_DOMAIN でも指定できる」とあるが、どこも読んでいない**（`SMB/Strings.cs:29`）。`SMBBackend` はオプション `auth-domain` を読むだけ。`AUTH_USERNAME`/`AUTH_PASSWORD` は CLI・BackendTool・BackendTester・RecoveryTool で読んでいる | リポジトリ全体の grep | `AUTH_DOMAIN` が出るのは `SMB/Strings.cs` と `SMBBackend.cs:96` の定数名 `AUTH_DOMAIN_OPTION = "auth-domain"` だけ。環境変数を読むコードはない | 判断が少し要る: ヘルプ文から消す（小）か、AUTH_USERNAME と同じ 4 か所で AUTH_DOMAIN も読む |
| 6 | （軽微）SMB の `--read-buffer-size`・`--write-buffer-size` の説明の綴りが "values bellow 10000 bytes"（正しくは below） | — | `SMB/Strings.cs:46`・`:48`（リポジトリの `.cs` で "bellow" はこの 2 か所だけ） | ヘルプ文。3〜5 と一緒に |

- PR のまとめ方の案（未決）: A = 1（S3 のキー名、テスト付き）、B = 3〜6（ヘルプ文の修正）、C = 2（利用者の判断の後。表示だけ直すなら B に入れてよい）
- ヘルプ文を直したら、duplicati/documentation 側に同じ記述がないかも確かめる

### 追加の 2 件（10-11、同じ照合から。利用者から、ソースを読んだだけで実行は未確認）

| # | 内容 | 報告の根拠 | master `85d15280` で確かめたこと | 種類 |
|---|---|---|---|---|
| 7 | **環境変数 `AUTOUPDATER_Duplicati_SKIP_UPDATE` が効かない**。値は `UpdaterManager.cs:69` で読まれて `DISABLE_UPDATE_CHECK` に入るが、どこからも参照されない。AutoUpdater のヘルプ（`AutoUpdater/Program.cs:115`）は「Disables updates completely」と案内。サーバーのオプション `--disable-update-check` は効く（`Server/Program.cs:303` で `updatePollThread.Init(...)` に渡す） | ソースの grep | `DISABLE_UPDATE_CHECK` が出るのは `UpdaterManager.cs:69` の定義だけ（`.cs` 全体を grep。`SKIPUPDATE_ENVNAME_TEMPLATE` は `:87` の定義とヘルプの `:115` だけ） | **判断が要る**: A = `DISABLE_UPDATE_CHECK` を UpdatePollThread・`UpdaterManager.CheckForUpdate`・AutoUpdater の `check`/`download` で尊重する、B = 環境変数とヘルプを消す。意図が読み取れなければ利用者に確認。直すなら「設定すると更新確認のリクエストが飛ばない」ことをテストかログで示す |
| 8 | **Agent の `--ping-pong-keepalive` が受け付けられるだけで使われない**。宣言は `Agent/Program.cs`、値は `CommandLineArguments.PingPongKeepalive` に入るが、ホストするサーバーへ渡す `EncodeOption` の一覧に入っていないので、サーバーの `ping-pong-keepalive`（`Server/Program.cs:53`・`:318`）に届かない。Windows サービスは `Service/Runner.cs:111-113` で `--ping-pong-keepalive=true` を必ず付ける | ソースの grep | `PingPongKeepalive` が出るのは `Agent/Program.cs` の宣言・レコード（`:92`）・代入（`:188`、`:303` は false の固定値）だけ。`EncodeOption("--…"` の一覧（`:640-652`）に無い | **判断が要る**: A = 一覧に `EncodeOption("--ping-pong-keepalive", …)` を足す、B = Agent のオプションから外す。Agent に要る機能か分からなければ利用者に確認 |

- **7 → 10-12 に利用者が A1（すべての確認を止める）に決め、`fix/skip-update-env`（`3dd89342`）で修正、`PENDING-BRANCHES.md` に記録**。後続（別セッションの報告）: documentation の `community-docs-other-commandline-utilities.md:242` にある `AUTOUPDATER_Duplicati_POLICY` はもう存在しない変数で、`autoupdater.md` には SKIP_UPDATE の記載がない（docs 側）。デバッグビルドの AutoUpdater は `installation.txt` がないと `CheckForUpdate` が `InvalidOperationException`（リリースは空文字で続行、影響はデバッグビルドだけ）。**さらに後続**: デバッグビルドの ID ファイルの件は `fix/update-check-install-id`（`80ddf34c`）で修正。documentation 側は文面の下書きだけ（共有ノートの `docs-draft-skip-update-env.md`）で、未マージの documentation#47 が autoupdater.md の同じ末尾を変えているので、#47 と本体の PR の両方がマージされてから作る。community-docs の POLICY の行は 2.0 の旧ドキュメントの写しなので 1 行だけは消さない。新しく見つけた件（**→ 10-12 に `fix/updater-user-agent`（`d8b8fb0a`）で修正。WEBDAV.cs・pCloudBackend.cs の同じ誤りは `fix/backend-user-agent` で作業中**）: 更新リクエストのヘッダー名が `HttpRequestHeader.UserAgent.ToString()` = `"UserAgent"` で、`User-Agent` が送られていない（偽サーバーで観測）
- **8 → 10-12 に利用者が A（サーバーに渡す）に決め、`fix/agent-ping-pong-keepalive`（`194275cb`）で修正、`PENDING-BRANCHES.md` に記録**。後続（推測、未検証、コードを読んだだけ）: (1) Agent は shutdown を受けても止まらない見込み **→ 10-12 に `fix/agent-stop-on-server-exit`（`51b6f6e0`）で修正（テストは代役で赤→緑）**。`PingPongMethod` は `SignalApplicationExit` を呼ぶだけで、Agent の `RunServerAsync` のループは `Server.Program.Main` が戻るとすぐサーバーを起動し直す。(2) Agent はログも標準出力に出すので pong と混ざる（Runner の `PingProcess` はどの行でも受け付けるので実害はたぶんない）。さらに後続 2 件（10-12 に別セッションが検証、利用者の判断でどちらも実装しない）: (1) サーバーが止まった後も `KeepRemoteConnection` が残る → **実害なし**（検証済み: 本物の `KeepRemoteConnection.StartAsync` のプローブで、接続が終わっていなくても Main が戻ってから約 1.6 秒でプロセスが exit=0 で終わる。Windows サービスも Agent が戻ると `base.Stop()` で終わる）。(2) **Windows サービスの停止が in-process の Server/Agent に伝わらない**（事実は検証済み: `Runner.Stop` の in-process 側は空のブロックで、ProcessExit などほかの仕組みもない）。由来は `b264e52a`（2026-06、kenkendk、MSI の再起動を直すための in-process 化）。Server のサービスにも当てはまり、停止時に後始末なしで終わるはず（推測、サービスを登録しないと確かめられない）。メンテナーが意図して入れた変更が絡み、影響が Server のサービス全体に及ぶので、**利用者は「実装しない（報告のみ）」を選んだ。Issue にするかは未決**。詳細は共有ノートの `agent-shutdown-followups.md`
- **1 → 10-12 に `fix/s3-list-api-version-option`（`e1e467ed`）で修正、`PENDING-BRANCHES.md` に記録**。古いキー `list-api-version` は利用者の指示で fallback＋非推奨の警告にした（`b49b6bc0`）。後続（別セッションの報告）: Minio クライアントはこのオプションを一切読まない（`S3MinioClient.cs:95` が `WithListObjectsV1` を呼ばない。SDK 6.0.0 に API があることは確認済み）ので、`s3-client=minio` では SDK の既定の v2 になり、ヘルプの既定 v1 と食い違う見込み（推測、未検証）。揃えると Minio の既定の挙動が変わるので別 PR。**→ 10-12 に検証（master で v1 を指定しても `list-type=2`）して `fix/s3-minio-list-api-version`（`71f736ea`）で修正。未指定は v2 のまま（利用者の判断）、利用者の指示で AWS 側のブランチの上に積んである**
- **2〜6 → 10-12 に `fix/help-text-corrections`（`0951c786`）でまとめて修正、`PENDING-BRANCHES.md` に記録**。2 は表示を 2 に直す（既定値の切り替えはしない）、5 はヘルプから AUTH_DOMAIN を消す（どちらも利用者が決定）。documentation で該当するのは encryption-algorithms.md:17 の「help aes は 3 と出るが実際は 2」という注記だけ（リリース後に外す候補）。新しい候補（別セッションの報告、検証済み）: Windows の master で `help backends` などオプションを探すトピックを引くと、Topic not found ではなく `FormatException` で落ちる。`Main/Strings.cs:132` の `VssprovideridLong` にある `{GUID}` を `LC.L` から `string.Format` に通しているため。`29207056`（2026-09-16）で入り、canary 2.4.0.102 以降（stable には未収録の見込み）。upstream に Issue なし。詳細は共有ノートの `help-text-followups.md`。**→ 10-12 に `fix/vss-provider-help-format`（`2d9ac996`）で修正、`PENDING-BRANCHES.md` に記録**

- まとめ方の案（未決）: 7 と 8 は別のテーマ（更新確認と Agent）なので別の PR。7 を A にするなら、更新確認の経路が複数（UpdatePollThread・CheckForUpdate・AutoUpdater の CLI）あるので、どこで止めるかを先に決める

### 追加の 1 件（10-12、同じ照合から。利用者は 2.4.0.1 の Windows x64 で `help snapshot-provider` を実行して確認）

| # | 内容 | 報告の根拠（2.4.0.1） | master `85d15280` で確かめたこと | 種類 |
|---|---|---|---|---|
| 9 | **`--snapshot-provider` のヘルプが「Vanara が既定」と書くが、実際の既定値は違う**。説明文は `Main/Strings.cs` の `SnapshotproviderLong`（「The Vanara version is the default and supports all features … The AlphaVSS is the legacy provider and requires VC++ Redist installed.」）。`Options.cs` が値の行に出す既定値は `WindowsSnapshot.DEFAULT_WINDOWS_SNAPSHOT_PROVIDER` で、コードと一致 | 2.4.0.1 の既定値は x64/x86 が `AlphaVSS`、Arm 系が `Wmic`。`help snapshot-provider` は同じ出力で説明文が「Vanara が既定」、値の行が `default value: AlphaVSS` | **master では既定値がさらに変わっている**: `WindowsSnapshot.cs:50` が `DEFAULT_WINDOWS_SNAPSHOT_PROVIDER = WindowsSnapshotProvider.Native`（アーキテクチャの分岐なし、`DEFAULT_WINDOWS_SNAPSHOT_QUERY_PROVIDER` も Native）。入ったのは `4941a13e`「Add native VSS provider」（2026-09-01、`v2.4.0.100_canary` 以降の canary に入っている、`git log -S` と `git tag --contains`）。列挙は AlphaVSS（legacy）・Wmi・Vanara（「Experimental」）・Native（「VSS requestor COM API via pure C# interop」）。説明文（`Strings.cs:130`）は Vanara が既定のままで、Native に触れていない | ヘルプ文。master では「既定値を Vanara にする」案は当てはまらない（既定は Native と決まっている）ので、説明文を Native が既定・Vanara は実験的・AlphaVSS は legacy に合わせる。2.4.0.1（stable）のドキュメントの既定値は AlphaVSS/Wmic なので、documentation 側は版ごとに書き分けが要るかもしれない |

### 追加の 1 件（10-12、同じ照合から。利用者はソースを読んだだけで、実行は未確認）

| # | 内容 | master `85d15280` で確かめたこと | 種類 |
|---|---|---|---|
| 10 | **DatabaseTool と SourceTool が preload 設定の `serverutil` セクションを読む**。どちらも `ConfigurePreloadSettings(ref args, …NamedExecutable.ServerUtil)` を渡すので、preload.json の `serverutil` の `env`/`args`（例: ServerUtil 用の `--hosturl`）がこの 2 つにも適用される。`PackageHelper.NamedExecutable` には `DatabaseTool`・`SourceTool` がある。ほかのツールは自分の値を渡す（SecretTool は `NamedExecutable.SecretTool`） | grep（実行はしていない）: `DatabaseTool/Program.cs:40`・`SourceTool/Program.cs:39` が `NamedExecutable.ServerUtil`、`SecretTool/Program.cs:39` は `NamedExecutable.SecretTool`。`PackageHelper.cs:99`・`:103`（列挙）、`:138`・`:139`（実行ファイル名）。`PreloadSettingsLoader.MapExecutableName`（`:420-436`）は tray・cli・autoupdater・server・winservice・backendtool・recoverytool・backendtester・aescrypt・snapshots・serverutil・service・agent・configuretool だけで、**databasetool・sourcetool に加えて secrettool の分岐もない**（SecretTool は自分の値を渡しても `*` 扱い、新しい事実）。入ったのは SourceTool が `5a4fcaa6`（2025-02、「Added tool to work with remote sources」）、DatabaseTool が `a0ecc5e0`（2025-04、「Added a database downgrade tool」）で、どちらも最初から ServerUtil（`git log -S`） | **判断が要る**: A = 各ツールに自分の `NamedExecutable` を渡し、`MapExecutableName` に `databasetool`・`sourcetool`（と `secrettool`）を足す、B = `serverutil` の共有が意図ならコメントに残す。意図が読み取れなければ利用者に確認。キーを足すなら documentation の preload-settings.md の表（documentation#50 で現在の動作を記載済み）の更新が要るので、利用者に伝える。確認の手順の例: `DUPLICATI_PRELOAD_SETTINGS` に `{ "args": { "serverutil": ["--some-option=x"] } }`、`DUPLICATI_PRELOAD_SETTINGS_DEBUG=1` で DatabaseTool を起動 |

- **9 → 10-12 に利用者が A に決定**: 説明文をコードに合わせる（Native が既定、Vanara（実験的）と AlphaVSS（legacy）は VC++ Redist が要る（`VCREDIST_PROVIDERS`）、Arm 版の Windows で使えるのは Native と WMI だけ（`SUPPORTED_PROVIDERS`））。`fix/help-text-corrections` の同じコミットに入れる。**→ 10-12 に `55e39f6c` で修正**。documentation（upstream/main `1e008f8c`）で関係するのは `community-docs/community-docs-installation.md:44` の「AlphaVSS を使い、VC++ ランタイム（VS2015）が要る」だけで、2.4.0.1 stable には合うが master/canary の Native 既定とは合わない（Vanara を既定とする記述はない）
- **10 → 10-12 に利用者が A に決定（secrettool も含める）**: **→ 10-12 に `fix/preload-tool-executable-names`（`64d70911`）で修正、`PENDING-BRANCHES.md` に記録**（documentation#50 の表の差分案もそこに）。後続の候補: 全 `NamedExecutable` が `*` 以外のキーに対応することを確かめるテスト（aescrypt などの既存キーとの整理が要るので別件）。SyncTool・AutoTuneTool が preload をまったく読まない件は範囲外（後続の候補）。**→ 10-12 に利用者の依頼で `fix/preload-sync-autotune-tools`（`c83fd6e6`）で修正**

### follow の所有者・パーミッション（`fix/follow-symlink-owner-perm`）の追加の確認から

- **推測、未検証**: `SystemIOLinux.HasPermissionUserRWOnly`・`GetOwnerAndGroup` も `lstat` のまま。設定やデータベースの置き場所がシンボリックリンクだと、権限の検査がリンクの 0777 を見て誤判定するかもしれない。再現から始める。詳細は共有ノートの `xattr-follow-followups.md`
- **→ 10-12 に検証済み、利用者の指示で Issue [#7472](https://github.com/duplicati/duplicati/issues/7472) を作った**（WSL、master `85d15280`、非 root）。データフォルダーや preload.json のあるフォルダーがシンボリックリンクだと、`HasPermissionUserRWOnly` が `lstat` でリンク自身の 0777 を読み、リンク先が 0700 でも「permissions allow group or other access (777)」で起動を拒否する。`DirectorySetPermissionUserRWOnly` でリンク先を設定し直しても通らない。v2.4.0.104 canary と master で関係する 4 ファイルは同一。`secure-datafolder` コマンド自体は未実行（本文にも明記）。#7030 で意図的に厳しくした検査なので PR は出さず、(1) リンクをたどる、(2) リンクを明示的に拒否する、の 2 案でメンテナーの判断を待つ。本文の写しは共有ノートの `issue-7472-datafolder-symlink.md`

### `--restore-symlink-metadata` の説明文（`fix/restore-symlink-metadata-help`）の調査から（10-22）

- **バグ（検証済み、#3848 と同じ種類）**: Linux・macOS でリンクのメタデータを復元すると、読み取り専用属性（`CoreAttributes` の ReadOnly）がリンク先に chmod される（WSL ext4 で 644→444 を観測）。直すならリンクのときは ReadOnly の適用を飛ばす（Linux ではリンク自身のパーミッションは持てない）。**→ 10-22 に `fix/restore-symlink-readonly-on-link`（`cf1496af`）で修正、`PENDING-BRANCHES.md` に記録**。詳細は共有ノートの `restore-symlink-metadata-help-followups.md`
- **観測のみ（未確認）**: Linux で `CoreCreatetime` を当てると mtime が上書きされた。リンク以外のファイルでも起きるかは未確認


## Issue とフォーラムの調査（2026-10-22、サブエージェント、どれも master `98067e41` のコードを読んだだけで未実行）

open の Issue は 2025 年以降の未着手のバグ報告がほぼ triage で扱い済みだった（triage に一度も出てこないのは #7454・#7470・#7474・#7476・#7517 だけ）。フォーラムはほぼ手付かずだったので `latest.json` の 180 トピック（2026-05〜10-21）からバグらしい約 40 件を読んだ。open な PR とは重ならない（`gh pr list --state open` とキーワード検索で確認）。

| # | 出典 | 不具合（一文） | コードの場所（読んで確認） | 規模・決めること |
|---|---|---|---|---|
| 1 | [forum 22760](https://forum.duplicati.com/t/22760) | RecoveryTool `recompress --reupload` で、圧縮形式と暗号化が元と同じだと、上げ直したファイルを直後に自分で消し、**宛先が空になる**（データ消失） | `CommandLine/RecoveryTool/Recompress.cs:280-284` が `PutAsync(新しい名前)` の直後に `DeleteAsync(元の名前)`。zip→zip で暗号化なし、または `--reencrypt` のとき 2 つの名前が同じ（:152-156・:273）。既存の `RecoveryToolTests.Recompress`（#5628）は `--reupload` を使っていない | 小。名前が同じなら Delete しない。Put の途中失敗まで考えるなら別名で上げて rename するかが判断。**→ 10-22 に `fix/recompress-reupload-keeps-same-name`（`5102928d`）で修正** |
| 2 | [#7454](https://github.com/duplicati/duplicati/issues/7454) | HTTP レポートの送り先が複数あると、1 つ目の失敗で残りに送らない | `Modules/Builtin/SendHttpMessage.cs:430` の `ex ??= SendMessage(...).Await();` | 小。全部に送ってから失敗をまとめる（最初の例外か AggregateException か）。**→ 10-22 に `fix/http-report-all-destinations`（`b9b79b27`）で修正（最初の例外を投げ直す）。同じ「1 つ目の失敗で残りに送らない」形が `HttpReportStatus.PostAsync`（URL のループ全体が 1 つの try）と `SendJabberMessage.SendMessage`（受信者のループ全体が 1 つの try）にもある（コードを読んだだけ）。後続の第一候補は HttpReportStatus（既存の SendAsync の override で赤のテストが作れる）。詳細は共有ノートの `http-report-all-destinations-followups.md`**。**→ 10-22 に HttpReportStatus と Jabber の両方を `fix/report-status-xmpp-all-targets`（`1df14446`）で修正** |
| 3 | [forum 22440](https://forum.duplicati.com/t/22440)・[22616](https://forum.duplicati.com/t/22616)・[20926](https://forum.duplicati.com/t/20926)（kenkendk が 22616 で「ログに出るべき」と認めた） | 終わった後の報告（HTTP・メール・コンソール）の失敗が警告として結果に載り UI は Warnings と出すのに、ジョブのログに残らない | `Main/Controller.cs:714` で先に `WriteResultsAndCommitAsync`、そのあと :752 の `OperationCompleteAsync`（:948-949 の `OnFinish`）でレポートのモジュールが動く。`ReportSubmitError`（`ReportHelper.cs:721`）は保存済みのログに入らない | 中。後からのメッセージを LogData に追記するか別の行にするかが**設計の判断**。**→ 10-22 に利用者が A に決定: レポートを送り終わったあと、その間に出たメッセージ（ReportSubmitError など）を同じジョブのログに追記する（DB をもう一度開いてコミット）。結果の JSON は 1 回目のままなので件数とログが食い違う点は PR 本文で触れ、直すなら続きで** **→ 10-22 に ngclient の JSON.parse のため利用者が方針を 1（結果の JSON を書き直す）に変更し、`fix/report-failures-in-job-log`（`a4afed7a`）で修正** |
| 4 | [forum 22816](https://forum.duplicati.com/t/22816)（2.4.0.1） | `--store-task-config=self` のジョブで restore などをすると `UnsupportedOption: --store-task-config` の警告 | `RestAPI/Runner.cs:887-889`: `StoreTaskConfigAndGetTempFolder`（:1160 で `options.Remove`）を通るのは `BackupOrSync` だけ。`Controller.cs:1342` で警告。サーバーだけのオプション（`DuplicatiWebserver.cs:110-121`） | 小。Runner で操作にかかわらずサーバーだけのオプションを除く（全体かこのキーだけか）。**→ 10-22 に `fix/store-task-config-not-passed`（`cb7eec5d`）で修正（`ServerOnlyOptions` はこのキーだけだった）** |
| 5 | [forum 22796](https://forum.duplicati.com/t/22796)（2.4.0.1、毎回 `SlowQueryDetected` でトレイが橙） | ただの `SELECT "ID" FROM "Fileset"` が「3493 秒実行中」。監視の範囲が `yield` をまたぎ、呼び出し元が行ごとにする処理まで数える | `Main/Database/ExtensionMethods.cs:342-346` の `SlowQueryMonitor.StartQuery` の `using` が `yield return rd` を包む。呼び出し元 `LocalDatabase.cs:2268-2274`（`VerifyConsistencyAsync`）、`BackupHandler.cs:284` から既定で有効。`308e8428c`（2026-05）で入った | 小〜中。`ReadAsync` の間だけ数える（全呼び出し元に効く）か、呼び出し元で先に List にするか。**→ 10-22 に `fix/slow-query-excludes-caller-time`（`bdfbf6aa`）で修正（前者）。後続の候補（未調査）: フォーラムで 2.3→2.4 で検証が 30〜45 分から 60〜90 分に遅くなったという話があり、`VerifyConsistencyAsync` が fileset ごとに COUNT を 2 本流すことが関係するかも** |
| 6 | [forum 22694](https://forum.duplicati.com/t/22694)（2.4.0.0、v12 なのに列がなくサーバーが起動しない、スタートアップの登録が 2 つ） | サーバー DB の更新が単一インスタンスの確認より先に、トランザクションなしで走り、失敗すると WAL の DB の上にファイルをコピーして戻す。同時に 2 つ起動すると壊れうる | `Server/Program.cs:260`（:1167 で `UpgradeDatabase`）が :279 の `CreateApplicationInstance` より先。`SQLiteHelper/DatabaseUpgrader.cs` は文ごとに自動コミット、:318 で版を更新、:325 で `File.Copy`。構造は確認、報告の状態になる経路は推測 | 中。`BEGIN IMMEDIATE` の中で版を読み直す、単一インスタンスの確認を先に。**メンテナーとの相談が要る**（ローカル DB も同じ upgrader） |
| 7 | [forum 22782](https://forum.duplicati.com/t/22782) の 2 番目（2.4.0.1） | Sync ジョブが restore の一覧に出て、選ぶと SQL のエラー | `OperationType.Sync` を見るのは `Runner.cs:949` と `Connection.cs:746` だけ（grep）。エラーの仕組みは推測 | 小〜中。サーバーで断るか ngclient で隠すか、どこまでやるか。**→ 10-22 に利用者が C（両方）に決定: サーバーで Sync ジョブへの restore・list・find などを分かりやすいエラーで断る PR と、ngclient の restore の一覧から Sync ジョブを外す PR（ngclient のセッションに依頼）** **→ 10-22 にサーバー側を `fix/sync-job-rejects-backup-operations`（`f80a81a1`）で修正、ngclient 側は ngclient のセッションに依頼** |
| 8 | [forum 22594](https://forum.duplicati.com/t/22594)（2.2.0.3） | SMB で約 2 万ファイルのフォルダーの list が `Not enough credits` で失敗 | `Backend/SMB/SMBShareConnection.cs:263` の `QueryDirectory` 1 回だけ。原因は推測、SMBLibrary が報告の版より新しい（1.5.8.1）ので直っている可能性 | 不明。まず再現（Samba の Docker か fork CI の CIFS）。**→ 10-22 に利用者が A に決定: まず今の master で再現を試し、再現したら原因を調べて直す。再現しなければ直っている見込みとしてフォーラムへの返事の案だけ作る** **→ 10-22 に再現（1Mbit/s に絞った Samba で 2 万件）して `fix/smb-list-large-folder`（`ad91b55b`）で修正** |

- 外したもの（理由つき）: forum 22675（Jottacloud のアカウントが要る）、22704・22782 の 1 番目・22601・22627・22561・22605（修正済み）、22782 の 3 番目（仕様の範囲、機能要望）、22567・22720・22618・22797（意図した変更か beta で修正済み）、22369（シェル拡張の作り直し）、22409・22791（ngclient の #469・#579・#580）、22497（原因不明で報告者も閉じた）、22617・22528・22539（回避策・追加予定・仕様）、21874（#6767 と同じ）、22798（MS のアカウント、直っている見込み）、22647（Google の OAuth の scope）、22612・22505（情報不足か環境）、#7517（OAuth サーバー側）、#7470・#7474・#7476（情報不足、Drime のアカウント、クラッシュログ待ち）
- 1・2・4・5 と「リンクの ReadOnly がリンク先にかかる」（上の節）は 10-22 にすべて子セッションで実装して push（`PENDING-BRANCHES.md` に記録）。3・6・7・8 は判断か再現の確認が要るので保留。**10-31 の確認**: 3 は自分の #7549（10-25 マージ、ジョブのログに報告の失敗を載せる）、7 は自分の #7548（サーバー）と ngclient#587（restore の一覧から外す）で修正済み。8 は `fix/smb-list-large-folder`。残るのは 6（サーバー DB の更新順）だけ

### `Runner` の通知の片付け（`fix/runner-dismisses-backup-notifications-once`）の調査から（10-22、子セッションが使い捨てのテストで観測、コミットなし）

- **観測（検証済み）**: 同じバックアップについて `UpdateMetadataBase` に Verify の結果を順に渡すと、警告 3 回で通知 3 件（同じ文面が重複）、問題なしの Verify の後も 3 件、エラーの Verify で 4 件、問題なしのバックアップで 0 件。つまり (1) Verify・Compact・Repair などは通知を足すだけで、同じ操作が後で成功しても消えない、(2) 成功したバックアップは、まだ解決していないかもしれない Verify のエラーも含めてそのバックアップの通知を全部消す。(2) は #6421 以来の挙動で、今回のブランチの回帰ではない（前のループも同じ条件、コードで確認）
- 範囲（コード根拠）: スケジューラーが走らせるのは BackupOrSync だけ（`Scheduler.cs:337`・`:377`）で、ほかの操作は API からしか起動されないので、(1) が #4719 ほどの件数になるのは考えにくい（推測）。#6420 の要望もバックアップだけが対象
- 直す場合: 通知にはどの操作から出たかの情報がない（Action は全部 `backup:show-log`）ので、操作ごとに置き換えるにはスキーマか conflicthandler の変更が要る（推測、未検証）。upstream の Issue のタイトルには該当なし。**先に Issue で方針を聞くのがよさそう（推測）**。詳細は共有ノートの `runner-dismiss-followups.md`
- **→ 10-22 に利用者が「Issue の案だけ」を選んだ**（ほかの選択肢は、同じ通知の重複だけ直す／操作ごとに置き換える）。英語の本文の案は `triage/issue-drafts/non-backup-operation-notifications.md`（未投稿）。補足（コード根拠）: ngclient の通知まわりは `MessageID`・`MessageLogTag` を使っていない（spec で null を入れているだけ）ので、操作ごとに置き換える案で既存の列を流用する余地がある
- 起動時の `Program.cs` のループ（`update:new`・`config:issue:*` の通知を 1 件ずつ消す、`Program.cs:725-775`・`:870`）は直す必要なし（コード根拠、未実行）: 登録時の conflicthandler が同じ Action の既存の通知を返すので Action ごとに最大 1 件（`Program.cs:789-863`・`:1520-1546`・`UpdatePollThread.cs:197`）。`DismissNotification` をループで呼ぶのは Runner と Program.cs だけ（grep）

### リンクの ReadOnly（`fix/restore-symlink-readonly-on-link`）の後続の調査から（10-22、子セッション、ブランチなし）

- **Linux で作成時刻を当てると更新時刻が上書きされる件は直す必要あり → 10-22 に `fix/restore-keep-mtime-on-linux`（`16a6d3c2`）で修正**（害が出るのは mtime が ctime より後のときだけ）。原因（ドキュメント根拠）: .NET 10 の `FileStatus.SetTimes.OtherUnix.cs` では `SetCreationTime` が `SetLastWriteTime` を呼ぶだけ。Duplicati は `CoreCreatetime` を常に保存し、`WriteMetadata` は更新時刻→作成時刻の順に当てるので、Linux ではリンクに限らず普通のファイルでも、復元後の mtime が作成時刻（btime か min(mtime, ctime)）になる見込み（推測、実測はそちらのセッション）。upstream に既存の Issue はなし
- **macOS のリンクの Hidden 属性（小さな後退、直していない）**: .NET の `SetAttributes` は Hidden を `LChflags`（リンク自身）で当てるので、`cf1496af` より前はリンク自身に Hidden が付いていた（同時に ReadOnly はリンク先に chmod されていた）。`--restore-permissions` ありなら `macos:flags`（UF_HIDDEN を含む）が lchflags でリンク自身に付くので問題なし。なしの場合だけ、macOS のリンクの Hidden が復元されなくなる。macOS で検証できず、場面もまれなので、PR 本文に「macOS で `--restore-permissions` なしだとリンクの Hidden は復元しない」と書く程度でよいという判断（直すなら `cf1496af` を amend し、macOS では UF_HIDDEN だけ `PosixFile.SetFileFlags` で当てる）。**→ 10-22 に利用者が A（PR 本文に書くだけ）に決定、`pr-drafts/restore-symlink-readonly-on-link.md` に追記**
- ほかにリンク先を変える経路は残っていない（拡張属性は `fix/restore-symlink-xattr` が対象）。時刻は .NET の `UTimensat` が `utimensat(..., AT_SYMLINK_NOFOLLOW)`、macOS の作成時刻は `setattrlist(FSOPT_NOFOLLOW)`（`pal_time.c`・`FileStatus.SetTimes.OSX.cs`、ドキュメント根拠）。所有者は lchown、macOS の ACL・flags は follow なし（コード）
- おまけ（未検証、優先度低）: macOS で `setattrlist` が ENOTSUP を返すボリューム（FAT など）でも、作成時刻の設定が更新時刻の設定に切り替わる（`FileStatus.SetTimes.OSX.cs`）。Linux だけを除外する修正だとこれは残る
- 文言だけの後続（直していない）: `FileRestoreDestinationProvider` に古いコメント「that writes the symlink target」が残っている

### recompress（`fix/recompress-reupload-keeps-same-name`）の後続の調査から（10-22、子セッション、ブランチなし）

- **`--reencrypt --new-passphrase --reupload`（検証済み、`5102928d` の上の push しない実験用 workspace でプローブ）**: zip→zip では同じ 3 つの名前が残り、zip→tzstd では `.tzstd.aes` に置き換わる。どちらも古いパスフレーズでの Repair は CryptographicException で失敗し、新しいパスフレーズでは Repair・Restore・TestAsync（全件）がすべて errors=0・warnings=0。**修正後は併用しても正しく動き、追加の修正は不要**。master で zip→zip を流すと宛先が空になるのは推測（前回赤だった `--reencrypt` と同じコードを通るため）。このケースのテストを `fix/recompress-reupload-keeps-same-name` に足すと守りが強くなる（足すかの指示はなく、今回は足さない）
- **新しい問題（検証済み）**: 暗号化なしのバックアップに `--reencrypt --reupload` を付けても exit 0 で終わり、宛先は暗号化されないまま（.zip のまま）で警告も出ない。原因は `Recompress.cs` の `reencrypt && remoteFile.EncryptionModule != null`。forum 22760 の利用者がやりたかったのはこれで、kenkendk は「できる」と答えていた。**利用者の判断待ち**: A = 警告を出す（小）、B = 暗号化を追加する機能（新機能、dindex の中の名前に .aes を足す処理も要る）、C = docs に明記するだけ。**→ 10-22 に利用者が A に決め、`fix/recompress-reupload-keeps-same-name` の同じコミットに入れるよう子セッションに指示 → `f8073493` で実装済み**
- **docs（duplicati/documentation の recoverytool.md）で合わなくなる箇所**（docs は触っていない）: 80 行目「`--new-passphrase` なら `--reupload` を使うな」の警告（2026-07-06 に理由なしで追加、修正が入れば理由がなくなる）、78 行目 step 4「files with old compression are deleted」（同じ形式のときは上書き）、77 行目 step 3（暗号化なしのファイルは暗号化されないことの明記がない）。コード側の `RecoveryTool/help.txt:95` にも 78 行目と同じ文言（未変更）。詳細は共有ノートの `recompress-reupload-followups.md`

### 検証が 2.3→2.4 で遅くなった件（forum 22796 の後続、10-22、子セッション、コードは変えていない）

- **原因（検証済み、`git show` で抜き出して diff）**: fileset ごとに COUNT を 2 本流す構造は 2.3.0.4 にもあり、2.3.0.4 と 2.4.0.1 でクエリ文・呼び出し箇所・既定値はすべて同じ。間の 1164 コミットで効きうるのは、SQLite エンジンの更新（3.46.1→3.53.4、`1a6794f45`・`ab9972e29`、#7159）と、cherry-pick された #7181 の統計の更新だけ
- **計測**（2 万ファイル × 30 版、本番の pragma・トランザクション・統計で、旧と新のエンジンを同じ SQL で交互に 5 回ずつ）: 中央値は旧 20.8 秒・新 23.0 秒で、**2 倍の悪化は再現しない**。ただし並行で dotnet が 14〜23 個動いていて数値は 2 倍近くぶれる（無負荷で測り直す余地あり）。利用者の DB が大きくなった影響かは確かめられない
- 小さな直し（BlocklistHash の LEFT JOIN と ORDER BY を外して件数だけ数える）は結果が一致したが改善は 1 割未満でノイズの範囲なので入れていない。内訳: パスだけを数える形でも master の約 1/4、残りの約 3/4 は版ごとに同じファイルの確認（BlocksetEntry の Index 0 など）を繰り返す結合
- **選択肢（10-22 に利用者が ③（何もしない）に決定）**: ① FileLookup ごとの確認を 1 回だけにして集合で一度に数える（3〜4 倍の見込み、推測。整合性検査の書き直しなのでメンテナーとの相談が要る） ② 前回の後に増えた fileset だけを確かめる（古い版の破損を見逃す） ③ 何もしない（`--disable-filelist-consistency-checks` で切れる、トレイが橙になる件は `bdfbf6aa` で解消済み）。詳細は共有ノートの `verify-filelist-slowdown.md`

### documentation 側の対応（10-22、documentation のセッション local_66f61554、利用者の依頼）

本体の修正が stable に入るまで docs の PR は出さない方針（利用者の決定 2026-10-20。stable は 2.4.0.1、canary は 2.4.0.104 で、今回の修正はどれもまだリリースに入っていない）。どれも documentation の main `a8f66025` の上で fork に push 済み、PR は未作成:
- `docs/preload-executable-names`（`610ac8fe`、3 コミット）: preload-settings.md の表と下の文（「The SharpAESCrypt program does not read the preload settings.」）。前の 3 本をまとめた
- `docs/autoupdater-skip-update`（`69b7b91c`）: autoupdater.md に `AUTOUPDATER_Duplicati_SKIP_UPDATE` と Debug ビルドの既定。「available from Duplicati <VERSION>」はリリース時に置き換える。community-docs/ は documentation#51 で消えたので POLICY の件は対象なし
- `docs/snapshot-provider-and-aes-help`（`e684605c`、2 コミット）: Windows の README に「From Duplicati <VERSION>」（Native/Wmi/Vanara/AlphaVSS）と「Before」を書き分け、encryption-algorithms.md の aes の注記を「before Duplicati <VERSION>」に限定。`4941a13e` は 2.4.0.1 に入っておらず canary 2.4.0.100 以降に入っている（compare で確認）
- recoverytool.md は変えず、本体の `fix/recompress-reupload-keeps-same-name` と `fix/recoverytool-help-and-symlink-comment` のマージ後に直すものとして記録
- 10-22 追記: small-text-fixes のセッション（local_94f02375）が後続として `docs/recoverytool-recompress-steps`（`a5957b5e`、main `a8f66025` から、PR 未作成）を push。recoverytool.md の step 3/4 を本体の help.txt（`fix/recoverytool-help-and-symlink-comment`）と同じ内容に（アップロードしてから元を削除、暗号化されていないファイルは --reencrypt でも暗号化されない。根拠は master の `Recompress.cs:265`・`:283-284`、コード読み）。`fix/recompress-reupload-keeps-same-name` のマージ後は step 4 と 80 行目の警告をまた直す必要あり。本文は `pr-drafts/docs-recoverytool-recompress-steps.md`
- 10-22 依存の監査（同セッション、検証済み）: master の NuGet の脆弱な依存は MessagePack と Pkcs だけで、#7525・#7526 で全部解消。npm はルートの package-lock.json（開発ツールだけ、配布物に入らない）に 15 件（high 13）、ngclient は 0 件。直し方は利用者の判断待ち（A: npm audit fix で nanoid・colord・yaml だけ / B: A＋postcss-cli 12 / C: 何もしない。braces は修正版なし）
- **本体の新しい候補（推測、未検証）**: master では列挙の `Wmic` が `Wmi` に変わっている（`203694ca`「Switch to VMI」）。`--snapshot-provider=Wmic` を保存した既存の設定が新しい版でどう扱われるか（エラーか既定値に戻るか）は確かめていない
- 補足: リリース後に docs の PR を出す毎日のスケジュールタスク `duplicati-docs-release-wait-prs` が 10-22 時点で一覧から消えていた→ **作り直さない**（利用者の決定）。リリースが出たかは利用者が確かめて documentation のセッションに連絡し、その時点で docs のブランチを PR にする
