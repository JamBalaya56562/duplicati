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
- `Localizations/duplicati/extract.sh` が全 `.cs` を `tr -d "\r"` で書き換える（改行が混在するリポジトリで破壊的）
- recreate が、孤立した dindex の指す dblock を Temporary として登録しブロックを残す（`RecreateDatabaseHandler.cs:494-523`、#5136 のコメントから）

## 後続の候補（10-11、実装中に見つかったもの）

### #3848（`fix/restore-symlink-owner`、`15fe8fc5`）から

- **推奨 1**（推測、未検証）: リンクの拡張属性がリンク先に付く疑い。`SystemIOLinux.SetMetadata` は拡張属性を `PosixFile.SetExtendedAttribute`（Mono の `setxattr`、リンクをたどる）で書くが、`GetExtendedAttributes` は `llistxattr`/`lgetxattr` でリンク自身から読む。Linux では `user.*` をリンクに付けられないので、再現は root で `trusted.*`（例: `setfattr -h -n trusted.dup3848 -v x link`）。直すならリンクには `lsetxattr`。赤→緑は `RestoreSymlinkMetadataTests` の流儀（root でなければ skip）。同じテストファイルを触るなら `fix/restore-symlink-owner` のマージ待ち（積まない）
- **推奨 2**（検証済み）: legacy の restore でリンクだけを restore すると、警告 `NoFilesOrFoldersRestored`（「Restore completed without errors but no files or folders were restored」）。リンクは restore されている。新しいエンジンでは出ない。`RestoreHandler.cs` が restore した数にシンボリックリンクを数えていない見込み（推測）。再現: ファイルとそのリンクをバックアップし、`restore-legacy=true` で `RestoreAsync(new[] { linkPath })`
- 記録だけ 3: `--restore-symlink-metadata` の説明文（`Strings.cs` の `RestoresymlinkmetadataLong` と duplicati/documentation）の「リンク先が変わることが多い」は、修正後の Linux ではほぼ当てはまらない。#3848 の PR のマージ後に直す
- 記録だけ 4（設計の判断）: `lchown` はリンク先に影響しないので、`--restore-permissions` だけでもリンクの所有者を戻す案（Issue の利用者の期待はたぶんこれ）。オプションの意味が変わるので先にメンテナーに聞く。PR 本文で触れる程度
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
