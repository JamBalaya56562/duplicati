# 実装候補 2026-10-03（Issue の再調査）

`ISSUE-TRIAGE-REPORT.md` で深掘りしておらず、`IMPLEMENTATION-CANDIDATES-2026-09-26.md`・`PENDING-BRANCHES.md` でも触れていない open Issue 536 件から、機能要望・質問を除き、2024 年以降に作られたか 2026-06 以降に動きのあるもの 132 件を出した。そこからタイトルと本文でバグの報告らしい 28 件を選び、4 つのサブエージェントで Issue・コメント・今のコード（master `943e345e`）を読んだ。**どれもコードと履歴を読んだだけで、ビルド・実行はしていない（未検証）**。再現と修正の前に、必ず手元で確かめる。

## 順位（手元で再現でき、小さく直せるもの）

| 順 | Issue | 一文にすると | 判定 | 再現 | 規模・場所 |
|---|---|---|---|---|---|
| 1 | [#6252](https://github.com/duplicati/duplicati/issues/6252) | `--disable-file-scanner` だと進捗が `TotalFileCount=0, TotalFileSize=-1` になり「-N files to go」と出る | 残っている（サーバー側）。`BackupHandler.cs:700-719` が新しい空の fileset を作った後に `GetLastBackupFileCountAndSizeAsync`（`LocalBackupDatabase.cs:1347-1352`、`ORDER BY Timestamp DESC LIMIT 1`）を呼ぶので、数えるのは今作った空の fileset。正しい前回の id は `BackupHandler.cs:684` の `lastfilesetid` にある | 単体テストで可（2 回バックアップして進捗を見る）。**10-03 に直して `fix/disable-file-scanner-previous-totals` を push した**（PR はまだ、PENDING の 10-03, 4） | 小。`LocalBackupDatabase.cs`・`BackupHandler.cs`。新しい UI は利用者が別セッションで直す。古い UI の `StateController.js` は対象外 |
| 2 | [#7005](https://github.com/duplicati/duplicati/issues/7005)・[#6866](https://github.com/duplicati/duplicati/issues/6866) | スナップショットが `StartSnapshotSet` の後で失敗すると、プロセスが終わるまで以後のスナップショットが 0x80042316 で失敗する | 残っている。Vanara は `AbortBackup` も COM の解放もしない。Native（今の既定）は解放するが `AbortBackup` を呼ばない。さらに [`29207056`](https://github.com/duplicati/duplicati/commit/2920705699fc7f78ccb6170385f31064891e0f8f)（#7329、2.4.0.102 canary〜）で `CreateSnapshotManagerCore` が失敗時に manager を破棄しなくなった（`WindowsSnapshot.cs:213-228`） | **管理者権限が要る**（VSS）。**10-03 に利用者の管理者のシェルで再現し、直して `fix/vss-failed-snapshot-releases-set` を push した**（PR はまだ、PENDING の 10-03, 3） | 小。`WindowsSnapshot.cs`・`VanaraVssBackup.cs`（Native は変更不要と実測） |
| 3 | [#5853](https://github.com/duplicati/duplicati/issues/5853)（kenkendk が立てた） | 一部だけ復元すると、復元の対象にない親フォルダを作るたびに「Creating missing folder」の警告が出る | 残っている。`Restore/FileProcessor.cs:332,408`、旧エンジン `RestoreHandler.cs:583,709,1398,1508` | 単体テストで容易。**10-03 に直して `fix/restore-missing-folder-not-a-warning` を push した**（PR はまだ、PENDING の 10-03, 6） | 小。対象のフォルダは先に作られるので、後から作るものを Verbose に |
| 4 | [#5093](https://github.com/duplicati/duplicati/issues/5093) | 空のファイルを処理中、ファイルごとの進捗が 0/0 になり、古い UI は「%」だけ、新しい UI は「NaN%」 | 残っている。古い UI `ngax/templates/home.html:118-119`、新しい UI `status-bar.state.ts:281`（別リポ） | 0 バイトのファイルを大量にバックアップすれば見える。**10-03 に古い UI 側を直して `fix/empty-file-progress-percent` を push した**（PR はまだ、PENDING の 10-03, 7）。新しい UI は利用者が別セッションで | 極小。2 リポで別 PR |
| 5 | [#6759](https://github.com/duplicati/duplicati/issues/6759) | スリープで一時停止した後、復帰の前に再起動すると、期限なしの一時停止として残り、以後スケジュールが動かない | 残っている見込み。`OnSuspend` の `SetPauseMode()` は期限 0 で通知し、`Program.LiveControl_StateChanged` が `PausedUntil` に 0 を保存、次の起動の `Init()`（`LiveControls.cs:203-208`）は 0 を「無期限の一時停止」と読む。`m_pausedForSuspend` はメモリにしかない | `SuspendResumeStateTests` の仕組みで単体テスト可 | 小。**`LiveControls.cs` は #7407 と同じファイル**（#7407 のマージ後に出す） |
| 6 | [#5175](https://github.com/duplicati/duplicati/issues/5175) | USN と属性の除外を使い、ソースがファイル 1 つのとき、2 回目以降のバックアップでそのファイルが黙って抜ける | 残っている見込み。`UsnJournalService.cs:287-294,365-373,445-473` の祖先のたどりがソースの境目で止まらず `C:\` の S/H 属性で除外。USN の経路はソースを root として作らない（`SnapshotBase.cs:85`） | 本物は管理者権限が要る。祖先のたどりは偽の `ISnapshotService` で単体テスト可。**10-03 に直して `fix/usn-source-file-not-excluded` を push した**（PR はまだ、PENDING の 10-03, 8。管理者のシェルでも赤→緑） | 小。`UsnJournalService.cs` |
| 7 | [#6042](https://github.com/duplicati/duplicati/issues/6042) | Host を保たないリバースプロキシの後ろだと、リフレッシュの cookie が `Domain=127.0.0.1` になってブラウザに拒まれ、ログインがループする | 残っている。`WebserverCore/Endpoints/V1/Auth.cs:180-190,215-219` が `Domain = Request.Host.Host`、`Path` は固定 | nginx のコンテナで可。**10-03 に直して `fix/refresh-cookie-host-only` を push した**（PR はまだ、PENDING の 10-03, 9。Python の中継とブラウザで前後を確認） | 小（Domain だけ）。サブパスは対象外 |
| 8 | [#6308](https://github.com/duplicati/duplicati/issues/6308) | 本体は [`7f6b212d`](https://github.com/duplicati/duplicati/commit/7f6b212df) で直った。残り: `=0` でもデバッグが有効（`PreloadSettingsLoader.cs:55`）、トレイではデバッグ出力がコンソールを付ける前なので出ない | 一部残っている。**10-03 に残り 2 つを直して `fix/preload-debug-output` を push した**（PR はまだ、PENDING の 10-03, 10） | 本物のコンソールで確認 | 極小 |

## 閉じてよさそうなもの（コメントの案は未作成）

- [#5398](https://github.com/duplicati/duplicati/issues/5398) FTP の 550 で止まる → [`5712264e`](https://github.com/duplicati/duplicati/commit/5712264e6)（550 を `FileMissingException` に）と削除の書き直しで直っている
- [#5113](https://github.com/duplicati/duplicati/issues/5113) FTP がログインを拒むと止まる → 古い FTP のバックエンドごと消えた（[`a4482a4d`](https://github.com/duplicati/duplicati/commit/a4482a4d03d5f1324d855b4985959138c8defff9)）
- [#5087](https://github.com/duplicati/duplicati/issues/5087) Windows で Ctrl-C が効かない → 子プロセスで起動する仕組みが消えた（[`115e8878`](https://github.com/duplicati/duplicati/commit/115e8878029e9f0bba364cc49fd764a716d387e8)）、報告者も同意
- [#6744](https://github.com/duplicati/duplicati/issues/6744) 復元で TEMP に書き続ける → #6785 で既定のキャッシュ上限がなくなった（2.3.0.4 に入っている）
- [#6535](https://github.com/duplicati/duplicati/issues/6535) 一般ユーザーで DB が開けない → Windows の入れ直しで解決、Duplicati の原因なし
- [#7298](https://github.com/duplicati/duplicati/issues/7298) Unraid の RAM → 第三者のイメージの tmpfs の設定

## 判断できないもの・ほかのリポ

- [#6683](https://github.com/duplicati/duplicati/issues/6683) WebDAV で全ファイルが不明扱い：2.2.0.1 の新しい PROPFIND の解析（[`d02d7feb`](https://github.com/duplicati/duplicati/commit/d02d7feb6)）が疑わしいが、失敗する href がないと判断できない
- [#6639](https://github.com/duplicati/duplicati/issues/6639) FTPS で「Status is Failed」：FluentFTP と TLS 1.3 の見込み
- [#6840](https://github.com/duplicati/duplicati/issues/6840) 画面オフでトレイの CPU：Avalonia の描画ループの見込み
- [#6251](https://github.com/duplicati/duplicati/issues/6251) ZIP の中央ディレクトリの警告：古い dblock を読むときの見た目だけ。警告を残すかはメンテナの判断
- [#5248](https://github.com/duplicati/duplicati/issues/5248) トレイの Quit で残る：前景スレッドの潜在的な経路は残るが、#6461 と重なる
- [#7289](https://github.com/duplicati/duplicati/issues/7289)・[#7251](https://github.com/duplicati/duplicati/issues/7251)・[#7103](https://github.com/duplicati/duplicati/issues/7103)・[#5139](https://github.com/duplicati/duplicati/issues/5139)・[#6073](https://github.com/duplicati/duplicati/issues/6073)：情報不足・管理者権限やサービスが要る
- [#6865](https://github.com/duplicati/duplicati/issues/6865)：新しい UI（ngclient）の UNC の入力の要望
- [#5590](https://github.com/duplicati/duplicati/issues/5590)：WSL の隠しファイル（機能要望）
- [#5268](https://github.com/duplicati/duplicati/issues/5268)：Docker と NFS の環境
