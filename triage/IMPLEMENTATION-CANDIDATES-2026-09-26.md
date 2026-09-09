# 実装候補の洗い出し（2026-09-26）

メンテナが PR をまとめてマージするのに備えて、次に直すものを先に決めておくための一覧。
前回の候補（`ISSUE-TRIAGE-REPORT.md` の 2026-09-26, 3）で残っていた #5573 に加えて、
最近（2025〜2026 年）の OPEN のバグ報告と、古い `reproduced`（再現済み）の Issue を洗い直した。

## 調べ方と、根拠の強さ

- OPEN の Issue から、コードで直せそうなものを選び、7 つの調査エージェント（読むだけ、ファイルは変更しない）に分けて並行して調べた。
  - A〜D: 最近のバグ報告など
  - E・F: 古い Web UI（AngularJS、`Duplicati/Server/webroot/ngax`）の再現済みバグ。新しい UI（隣の `ngclient` リポジトリ）も合わせて確認する
  - G: 「database is locked」系
- 1 件ごとに確認したこと: 本文とコメント全部、関連 PR の有無（PR 検索と Issue のタイムラインの相互参照）、master のコードでまだ起きるか（file:line）、分類、直す場所と規模、赤→緑の示し方。
- **根拠はエージェントがコードを読んだ結果で、実際に動かしての確認はまだ**。着手するときは、必ず再現（赤）から始める。
- 分類: **(a)** 明確なバグで今も残っていて、直す場所が分かっている／**(b)** master ではたぶん直っている／**(c)** 再現が必要・不明／**(d)** 設計判断・機能要望／**(e)** コードの外（ドキュメント、配布、外部サービス）。
- 古い UI について: 今も同梱されていて使える。`http://localhost:8200/ngax/index.html` を開くか、cookie を `default-client=ngax` にする（`Duplicati/Server/webroot/index.html` の振り分け処理を読んで確認）。

## おすすめの着手順（A〜G すべての結果を反映）

| 順 | Issue | 内容 | 分類 | 規模 | 理由 |
|---|---|---|---|---|---|
| 1 | [#7330](https://github.com/duplicati/duplicati/issues/7330) | Windows の除外ポート範囲に 8200 が入っていると、次のポート（8300 …）に移らずに落ちる | **対応済み** | 小 | **09-26 に直した → `fix/server-port-refused-tries-next`（push のみ、`Fixes #7330`）**。実際の Windows 除外範囲のポートを使い、実サーバーで Issue と同じ例外を再現した（Linux は特権ポート） |
| 2 | Issue なし（G で発見） | `RepairHandler` が、修復用 DB を開く際のあらゆるエラーを「DB がない」とみなし、**健全かもしれない DB をリネームして作り直す** | **対応済み** | 小 | **09-26 に再現して直した → `fix/repair-abort-keeps-database`（push のみ）**。起きるのは busy ではなく**中断**のとき。busy は Controller の `RestoreOptionsFromExistingDatabase` が先に失敗するので届かなかった（実測）。中断は、Controller での実測で 30 回中 9 回リネームを試み、Linux では実際に DB が `.backup` に移った |
| 3 | Issue なし（G で発見、#7366 の続き） | `LocalBackupDatabase.CreateAsync` など派生クラスの初期化が失敗すると接続を閉じない（#7366 は基底クラスの部分だけ） | **対応済み** | 小 | **09-26 に直した → `fix/local-database-derived-setup-closes-connection`（#7366 の上、push のみ）**。該当は `LocalBackupDatabase` と `LocalDeleteDatabase` の 2 つ。準備に失敗する DB で、Controller から再現した。中断での発生は 25 回試して 0 回（窓が狭く再現せず） |
| 4 | [#6837](https://github.com/duplicati/duplicati/issues/6837) | バックアップが終わっても Windows がスリープしない | **対応済み** | 小 | **09-26 に再現して直した → `fix/sleep-prevention-dedicated-thread`（push のみ、`Fixes #6837`）**。`CallNtPowerInformation(SystemExecutionState)`（管理者不要）で、Dispose の 20 秒後も `0x1` が残ることを実測。専用スレッドで設定・解除 |
| 5 | [#3483](https://github.com/duplicati/duplicati/issues/3483) | 古い UI の restore で、ルートが複数あると、展開前の最上位のチェックボックスが選べない | **対応済み** | 極小 | **09-26 に再現して直した → `fix/restore-picker-unexpanded-root`（push のみ、`Fixes #3483`）**。`subst` の 2 ドライブ＋ブラウザで赤→緑、復元まで確認。**再現中に別件（下の 5b）を発見** |
| 5b | Issue なし（#3483 の再現中に発見） | 複数ドライブ（または UNC）のバックアップで、restore のルートの一覧（`prefix-only=true`）に**1 ドライブ約 30 秒**かかる。さらに**空のルートが 1 つ余計に**出る | **対応済み** | 小 | **09-26 に直した → `fix/list-prefix-multiple-roots`（push のみ）**。179d1ceb の退行。**新しい UI は既定では影響なし**（v2 の `list-folder` を使う、実測 319 ms）。v2 を無効にしたときだけ v1 に戻って影響を受ける（実測 62.2 秒・空のルートあり） |
| 6 | [#4405](https://github.com/duplicati/duplicati/issues/4405) | 古い UI で、S3 のクライアント（aws/minio）の設定が aws に戻る・保存されない | **対応済み** | 極小 | **09-27 に再現して直した → `fix/s3-client-kept-on-edit`（push のみ、`Fixes #4405`）**。タイミングしだいではなく、既存のジョブを開くたびに起きていた。新しい UI は影響なし（ブラウザで確認） |
| 7 | [#3750](https://github.com/duplicati/duplicati/issues/3750) | 古い UI で、S3 の独自のストレージクラスが保存されない | **対応済み** | 極小 | **09-27 に再現して直した → `fix/s3-custom-storage-class`（push のみ、`Fixes #3750`）**。新しい UI は影響なし（ブラウザで確認） |
| 8 | [#4001](https://github.com/duplicati/duplicati/issues/4001) | 古い UI でジョブを編集すると、ローカルフォルダの保存先が表示されない | **対応済み** | 小 | **09-27 に再現して直した → `fix/local-folder-shown-on-edit`（push のみ、`Fixes #4001`）**。ホーム→編集で 3/3 回再現。新しい UI は影響なし（ブラウザで確認） |
| 9 | [#6867](https://github.com/duplicati/duplicati/issues/6867) | スリープ復帰後、トレイアイコンが「一時停止」のまま | (c) | 小 | 直し方の見当はあるが、再現が先 |
| 10 | [#6575](https://github.com/duplicati/duplicati/issues/6575) | バックアップで `FilesetEntry` の一意制約違反 | (c) | 小（防御的な修正） | 引き金は不明。同じパスが二度来ると挿入で落ちる作り。再現が先 |
| 11 | [#6626](https://github.com/duplicati/duplicati/issues/6626) | dblock のアップロード失敗後、dlist がそのブロックを参照したままになり、restore が失敗する | (c) | 大 | データの整合性に関わる重要な件。障害を注入して再現してから |
| — | [#5832](https://github.com/duplicati/duplicati/issues/5832) | 古い UI の restore 画面の「This month」の見出しが誤解を招く | (a) | 極小 | 古い UI だけ。表示の文言を変えるだけ |
| — | [#2604](https://github.com/duplicati/duplicati/issues/2604) | 古い UI のコマンドライン画面で値と項目がずれる | (c) | 極小 | 今のブラウザでは起きないはず。不要な `orderBy` を消す 1 行の補強だけ |

close を勧められるもの（コードは不要、コメントするだけ）: #7351（カナリアで修正済み）、#2663、#4714、#4631、#6603、#6597、#6460、#3027、#4927（`--abort-if-source-missing` で対応済み）。

古い UI の 4 件（#3483、#4405、#3750、#4001）は、どれも数行の修正で、duplicati リポジトリ（`Duplicati/Server/webroot/ngax`）の中で完結する。古い JS にはテストの仕組みがないので、赤→緑は手動の手順で示すことになる。

## A: 最近のバグ報告

### [#7351](https://github.com/duplicati/duplicati/issues/7351) ログアウト時の例外が捕まえられずログに残る — (b) master では修正済み、安定版にはまだない
- スタックは `LoginProvider.PerformLogoutWithRefreshTokenAsync`。2.4.0.0 安定版の `Auth.cs:194` では `await` していないので、try/catch をすり抜けて「未観測の例外」として後から出る。
- master の `Duplicati/WebserverCore/Endpoints/V1/Auth.cs:198-208` は try/catch の中で `await` している（`290ee8800`、2026-07-22、カナリア 2.3.0.109 以降）。
- やること: コードは不要。「カナリアで修正済み、次の安定版に入る」と Issue に書く程度。

### [#7330](https://github.com/duplicati/duplicati/issues/7330) ポート 8200 が Windows の除外範囲にあると、サーバーやトレイが落ちる — **(a)**
- 原因: `Duplicati/Server/WebServerLoader.cs:343-346` で「次のポートを試す」条件に当てはまるのは、次の 3 つの形だけ。
  - `SocketException`（AccessDenied または AddressAlreadyInUse）
  - `IOException` で、中身が `AddressInUseException`
- 既定の localhost の待ち受け（`DuplicatiWebserver.cs:185` の `ListenLocalhost`）は IPv4 と IPv6 の両方を試す。両方失敗すると `IOException(inner: AggregateException(SocketException 10013 ×2))` になり、上の条件に当てはまらない。
- そのため、トレイのポート一覧（8200, 8300, …、`HostedInstanceKeeper.cs:51`）を最初のポートで打ち切ってしまう。#6321 の修正（#6323）は、`SocketException` の AccessDenied 単体しか足していない。
- 直し方: 中身の `AggregateException` が AccessDenied または AddressAlreadyInUse の `SocketException` だけなら、次のポートへ進む。判定を小さな関数に切り出す。規模は小。
- テスト: `TryRunServerAsync` は `createServer` を引数で受け取れる。ポート A では Kestrel と同じ形の例外を投げ、ポート B では成功させて、B が使われることを確かめる（`Connection` などを用意できるかは未確認）。より簡単なのは、切り出した判定関数の単体テスト。

### [#7236](https://github.com/duplicati/duplicati/issues/7236) B2 へのアップロードを永遠に再試行する — (c)
- 元ファイルの名前はバックエンドには届かない（リモートは `duplicati-*` の名前）。ログがなく、メンテナの依頼にも返事がない。今は手の付けようがない。

### [#7123](https://github.com/duplicati/duplicati/issues/7123) CLI が知らない引数を受けても動き続ける — (d)
- 今は意図した動作。`Controller.cs:1303-1309` で `UnsupportedOption` の警告を出して続ける。
- 厳格モードを足すなら規模は小〜中。ただし既定を「失敗」にすると、保存済みのジョブや、読み込まれていないモジュールのオプションが壊れる。メンテナの合意が要る。

### [#7105](https://github.com/duplicati/duplicati/issues/7105) 停止や中断をしてもジョブが止まらない — (c)
- ログも詳しい情報もない。まとめ役の Issue は #6461（OPEN）。
- 関係しそうな修正は #7325（キャンセルを無視するバックエンド呼び出しを待たないようにした、マージ済み）。最新のカナリアで試してもらう段階。

## B: 最近のバグ報告

### [#6837](https://github.com/duplicati/duplicati/issues/6837) バックアップが終わっても Windows がスリープしない — **(a)**
- 原因: `SetThreadExecutionState` の設定はスレッドごと。
  - `StartSleepPrevention`（`Duplicati/Library/Main/ProcessController.cs:145-161`）は `Task.Run` のループで 10 秒ごとに `ES_CONTINUOUS|ES_SYSTEM_REQUIRED` を設定する。`await Task.Delay` の後は別のスレッドプールのスレッドで再開するので、生き残った複数のスレッドに設定が残る。
  - `StopSleepPrevention` は、`Dispose` を実行しているスレッドでしか解除しない（`:549`）。
- もう 1 点: 停止時に CTS を `Cancel()` せずに `Dispose` している（`:546`）。すぐ次の操作が始まると、古いループが新しい CTS を拾って続く可能性がある。
- 直し方: 専用の 1 スレッドで設定と解除をするか、ループをやめて同じスレッドで設定・解除する。`Dispose` の前に `Cancel()` する。規模は小。
- テスト: 単体テストは工夫が要る（設定する関数を差し替えられるようにして、スレッド ID を記録するなど）。実機なら、バックアップを 2 回走らせたあと `powercfg /requests` が空になるかを見る。**Win32 の挙動は理解に基づくもので、未再現**。
- **09-26 追記（検証済み）**: 再現した。`powercfg /requests` は管理者が要るので、代わりに `CallNtPowerInformation(SystemExecutionState=16)` で全プロセスの要求を読んだ。操作前 `0x0` → 操作中 `0x1` → Dispose の 20 秒後も `0x1`（3 周とも）。専用スレッドが 1 回設定し、停止の合図（スレッドごとの `ManualResetEventSlim`）で解除してから終わる形に直した。合図はスレッドごとなので、古いループが新しい合図を拾う懸念もなくなる → `fix/sleep-prevention-dedicated-thread`（`b4374c2c`）。`SleepPreventionTests`（新規、2 周）直す前 赤 → 直した後 緑。

### [#6872](https://github.com/duplicati/duplicati/issues/6872) HTTPS でロングポーリングや WebSocket が 30 秒ほどで切れる — (c)／一部 (d)
- サーバーには 30 秒で切る設定が見当たらない。報告者の環境（Caddy、セキュリティソフト）の影響の可能性がある。メンテナは 3 つの OS で再現しなかった。
- WebSocket の KeepAlive などを設定できるようにする案は機能追加扱い。

### [#6867](https://github.com/duplicati/duplicati/issues/6867) スリープ復帰後、トレイアイコンが「一時停止」のまま — (c)
- サーバー側の通知は正しく出ているように見える（`PowerManagementModule.cs:103-117` → `LiveControls` → `Program.LiveControl_StateChanged`）。
- トレイの `LongPollRunnerAsync`（`GUI/Duplicati.GUI.TrayIcon/HttpServerConnection.cs:301-314`）は、エラーの後、再接続すると古い `lastEventId` で最長 5 分のロングポーリングをする（`:216`）。そのため、次のイベントが来るまで「一時停止」のままになりうる。
- 直し方の案（未検証）: エラーの後の 1 回目は、待たずにすぐ状態を取得する。規模は小。テストは、偽の HTTP ハンドラーで 2 回失敗させてから成功させる。

### [#6863](https://github.com/duplicati/duplicati/issues/6863) restore で作られた親フォルダの所有者が元と違う — (d)
- フォルダのメタデータは、バックアップにフォルダとして入っているものしか戻さない（`LocalRestoreDatabase.cs:2461-2483`）。ファイル 1 つだけをバックアップした場合は、親フォルダのメタデータを持っていない（推測）。直すなら、バックアップ時に親のメタデータも取る機能追加になる。

### [#6829](https://github.com/duplicati/duplicati/issues/6829) USB からの restore で既定のダウンロード数が多すぎる — (d)
- 既定値は CPU 数の半分（`Options.cs:189`）で、設計どおり。メンテナは AutoTune ツール（#6925、マージ済み）で対応している。既定値を変えるかどうかは設計の話。

## C: 最近のバグ報告

### [#6621](https://github.com/duplicati/duplicati/issues/6621) UTF-8 でないバイト列のファイル名（Linux、WebDAV） — (e)、一部 (d)
- .NET は Unix のファイル名を UTF-8 として読むので、不正なバイトは U+FFFD に化け、`File.Open` が FileNotFoundException になる（推測）。.NET の制約。
- 本格的に直すと、ソースプロバイダー全体を生のバイトで扱う大きな変更になる。現実的なのは「UTF-8 でない名前なので飛ばした」と分かりやすく警告すること（小）。メンテナの判断が先。

### [#6603](https://github.com/duplicati/duplicati/issues/6603) リバースプロキシ越しで無期限トークンを使うと、新しい UI が「バックアップがない」と表示する — (b)
- 両側とも修正済み。ngclient の `94b107f`（2025-12-16）と、サーバーの `7f11f9db2`（2025-12-19、`WebsocketAccessor.cs:329-331`、カナリア 2.2.0.103 以降）。報告者が確認できれば close 可。

### [#6597](https://github.com/duplicati/duplicati/issues/6597) ファイルからの restore で「fileset がない」になる競合 — (b)
- 関連の修正はマージ済み: #7323、#7342、ngclient の `9c0d675`。DB のロックの仕組みで修復と一覧が順番に処理されるようになった（`f690297d1`）。やることはない。

### [#6575](https://github.com/duplicati/duplicati/issues/6575) `FilesetEntry` の一意制約違反 — (c)
- 報告者は、別のフォルダソースの中にあるファイルソースを外すと直ったと書いている。
- ただし master（と 2.2.0.0）の `Controller.ExpandInputSources` は、そういう重複をすでに取り除いている（`Controller.cs:1543-1591`）。本当の引き金は不明。候補（未検証）:
  - ジャンクションや OneDrive のリダイレクトで、比較をすり抜けるパスの違い
  - USN ジャーナルを使った列挙で、同じパスが二度出る（`FileEnumerationProcess.cs:130-160`）
- 列挙は重複を取り除かず（`FileEnumerationProcess.cs:173-174` の `DistinctBy` はコメントアウト）、挿入もただの INSERT（`LocalBackupDatabase.cs:260-271`）なので、同じパスが二度来ると `FileBlockProcessor.cs:146` で落ちる。
- 防御的に直すなら、挿入の前に重複を飛ばしてログに出す（小）。再現が先。

### [#6460](https://github.com/duplicati/duplicati/issues/6460) B2 へのアップロードが完了したように見えてファイルがない — (b)（未確認）
- `15db2198a`／#6543（2025-10-10）で、`B2.PutAsync` が `EnsureSuccessStatusCode()` を呼ぶようになった（`B2.cs:362`）。報告者の確認を待って close。

## D: 最近・古いバグ報告

### [#5832](https://github.com/duplicati/duplicati/issues/5832) restore 画面の「This month」という見出しが誤解を招く — (a)、古い UI だけ
- 古い UI の `Duplicati/Server/webroot/ngax/scripts/controllers/RestoreController.js:23-48` だけにある。
  - 「This month」の境目は「1 か月前の日付」（`:30`）、「Last month」は「2 か月前」（`:31`）。
  - つまり「This month」の中身は「8 日前〜1 か月前」。
- 新しい UI（ngclient）は版をまとめて見せないので、影響しない。
- 直し方: `:36-38` の文言（と翻訳カタログ）を変える。極小。古い UI の JS にはテストの仕組みがない（未確認）。

### [#5677](https://github.com/duplicati/duplicati/issues/5677) OpenStack の接続テストがフォルダの存在を確かめない — (d)、一部 (b)
- コンテナがない場合は、すでに `FolderMissingException` になり、作成もできる（`OpenStackStorage.cs:386-397`、`:481-488`）。
- コンテナ内のパスは名前の前置きにすぎないので、存在しない前置きでも一覧は成功する（設計どおり）。末尾の「/」も正規化済み。

### [#4714](https://github.com/duplicati/duplicati/issues/4714) 独自の OAuth サーバーだと、接続テストでのフォルダ作成が失敗する — (b)
- 今は、テストと作成が同じバックエンドのインスタンスを同じオプションで使う（`RemoteOperation.cs:75-93`、`DestinationVerify.cs:76-95`）。
- 別の論点: ジョブ単位の詳細オプション（`oauth-url` など）がテストに届くかどうかは、UI が URL に入れるか次第（未確認）。

### [#2663](https://github.com/duplicati/duplicati/issues/2663) 削除操作が一時ファイルを消すときに警告が出る — (b)
- `FilelistProcessor.cs:384-421` は、リモートの一覧に実際にある場合にだけ削除する。同じファイルを二度消す経路は見当たらない。close 候補。

### [#6626](https://github.com/duplicati/duplicati/issues/6626) dblock のアップロード失敗後、dlist がそのブロックを参照したまま restore が失敗する — (c)、規模は大、重要
- 再試行時にリネームする経路が関係していそう。
  - `BackendManager.PutOperation.cs:243-246` と `RenameFileAfterError`（`:419-449`）
  - `LocalDatabase.RenameRemoteFileAsync`（`:2980-3018`）は、ID とブロックの結び付けを保ったまま行をリネームし、古い名前を `Deleting` として登録する
- 「`Deleting` の dblock が有効なものとして扱われる」という症状は、リネーム後のボリュームと fileset や index の食い違いと合う（未検証）。
- 赤→緑にするには、バックアップの途中で dblock の PUT を失敗させる障害注入が要る。そのあと recreate と restore をして確かめる（既存のテスト用バックエンドで可能）。

### [#7225](https://github.com/duplicati/duplicati/issues/7225) restore で版が表示されない — (c)／(e)
- メンテナが古い UI でのクラッシュと特定し、利用者は新しい UI では動くことを確認済み。古い UI の原因は、ブラウザのコンソールの内容がないと分からない。優先度は低い。

## E・F: 古い Web UI の再現済みバグ（新しい UI も確認）

E・F の Issue には、古い UI と新しい UI のどちらでも関連する PR はない（#3027 に、閉じた #2024 からの参照があるだけ）。古い JS（ngax）にはテストの仕組みがないので、直すなら手動で確かめることになる。

### [#3483](https://github.com/duplicati/duplicati/issues/3483) restore で、展開前の最上位のチェックボックスが選べない（ルートが複数あるときだけ） — 古い UI **(a)**、新しい UI (b)
- 古い UI: `ngax/scripts/directives/restoreFilePicker.js:185` の `toggleCheck` で、`findParent(root)` が null を返すので `p = node` になる。`:208` のループが `p.children.length` を読むが、`children` は展開したときにしか読み込まれない。
  - ルートが 1 つなら `:341` で自動的に展開されるので、問題が隠れる。
  - ルートが複数（A:\ と B:\ など）だと `TypeError ... reading 'length'` で止まる。
  - 2023 年の Jojo-1000 のコメントも同じ場所を指している。
- 直し方: `:208` で `p == node` か `p.children` が null ならループを飛ばす（`:214` で、その場合はノード自体を追加するので結果は変わらない）。1〜2 行。
- 確かめ方: Windows で別のドライブ（ts678 は `subst` で A: と B: を作った）の 2 つのフォルダをバックアップし、restore で展開前のルートにチェックを付ける。選ばれて、コンソールにエラーが出ないこと。
- 新しい UI: `ngclient/.../core/components/file-tree/file-tree.component.ts:1053-1112` の `toggleSelectedNode` はパスの文字列だけで処理し、`children` を読まないので起きない（コードからの推測、動かしてはいない）。
- **09-26 追記（検証済み）**: 再現して直した → `fix/restore-picker-unexpanded-root`（`c19f74c3`）。`subst` で Q: と R: を作って 2 ドライブのバックアップをし、`--webservice-webroot` をソースに向けたサーバーで、古い UI の restore を操作した。直す前は `TypeError`（`:208:49`）が出て選択は `[]`。直した後は `["Q:\srcA\"]` が選ばれ、2 ルートを別フォルダに復元できた。
- **別件（検証済み、未修正）**: 複数ドライブのバックアップでは、ルートの一覧（`/backup/{id}/files?prefix-only=true`）に **60 秒**かかった（2 ドライブ、curl の `time` で 60.4 秒。上限 60 秒では打ち切られた）。
  - ダンプで見た経路: `LocalListDatabase.FileSets.GetLargestPrefixAsync`（`LocalListDatabase.cs:452-480`）の複数ドライブの分岐は、`SELECT "Path"` の読み取り（遅延の列挙）を開いたまま、ドライブごとに自分を再帰で呼ぶ。内側の呼び出しは終わるときに一時テーブルを `DROP` するが、同じ接続で外側の読み取りが開いているので、SQLite の既定のコマンドのタイムアウト（30 秒）まで `SqliteDataReader.NextResult` で待つ。失敗は `FilteredFilenameTable.DisposeAsync` の `catch { }` で捨てられる。つまり 1 ドライブにつき 30 秒。
  - その後、複数ドライブの結果を返した後に処理が続き、`""` も返すので、**空のルートが 1 つ余計に**ツリーに出る（古い UI の画面で確認）。
  - 待っている間はデータベースのロックを持ったままなので、画面を再読み込みすると「データベースは別の処理で使用中」のエラーになる（実際に出た）。
  - 2019 年の同期版（`65e79a276`）は `.ToArray()` で読み取りを閉じてから再帰し、`return` していた。179d1ceb（2026-05-13「Make controller Async」）で async にしたときに、この 2 点が落ちた。
  - 新しい UI も同じ API を呼ぶ（`select-files.component.ts:213`）。画面での表示はまだ確かめていない。
  - 同じ症状の Issue は見当たらない。
- **09-26 追記 2（検証済み）**: 5b を直した → `fix/list-prefix-multiple-roots`（`3ab6a0e5`）。
  - 新しい UI への影響: `select-files.component.ts` は、サーバーが `v2:backup:list-folder` を提供していれば `POST /api/v2/backup/list-folder`（`Paths: null` → `ListFolderHandler` の `GetMinimalUniquePrefixEntriesAsync`）を使う。`prefix-only` は v2 がないときの予備の経路にすぎない。
  - v2 の list-folder は 2025-04（`2f0a5af4`）からあり、今回の退行（2026-05）より古い。Agent が無効にするのは websocket と subscribe だけ。したがって退行のあるサーバーでは、新しい UI は既定で影響を受けない。
  - ブラウザでの実測（直す前のサーバー）: 既定では list-folder が 319 ms で、空のルートなし。`--webservice-disable-api-extensions=v2:backup:list-folder,v2:backup:list-filesets` では `prefix-only` が 62.2 秒かかり、空のルート（名前のない項目）が表示された。直した後のサーバーでは同じ条件で 407 ms、ルートは 2 つだけ。

### [#2604](https://github.com/duplicati/duplicati/issues/2604) コマンドライン画面で、テキストから一覧に切り替えると値と項目がずれる（Chrome、オプション 11 個以上） — 古い UI (c)、新しい UI (b)
- 古い UI: `ngax/templates/advancedoptionseditor.html:2` の `orderBy: item` は意味のない並べ替えのキーで、全部が同じと比べられる。AngularJS 1.4.3 は同順位を元の順で保たないので、`Array.sort` が安定かどうかで並びが変わる。
  - Chrome 70 より前は、11 個以上の要素で不安定なクイックソートを使っていた。症状（Chrome だけ、11 個以上）と一致する。
  - 今の Chrome は安定なソート（TimSort）なので、たぶん起きない（未確認）。
- 補強として `| orderBy: item as nn` を消すのは 1 行。
- 新しい UI: 並べ替えをしておらず、順番も重複も保つ（`options-list.component.html:84`、`.ts:151-174`）。

### [#3011](https://github.com/duplicati/duplicati/issues/3011) 「About」で「Show log」を押すとタブのボタンが消える — 古い UI (a)（ただし UX の話）、新しい UI (b)
- 古い UI: 「Show log」は About の外の別ルート（`#/log`）へ移る（`about.html:8`、`app.js:59`）。ログ画面を About の中に置くか、元のメニューに戻すかで、メンテナの意見が分かれたまま。設計を決めるのが先。
- 新しい UI: About の中のタブとしてログがある（`about.component.html:5-11`）。

### [#3027](https://github.com/duplicati/duplicati/issues/3027) 詳細オプションでメールのパスワードがそのまま見える — 古い UI (b)、新しい UI (b)
- 両方とも `type="password"` で表示される（古い UI は `advancedOptionsEditor.js:100-101`、新しい UI は `options-list.component.html:205-233`）。「テキストで編集」だと見えるのは設計どおり。close 可。

### [#4001](https://github.com/duplicati/duplicati/issues/4001) ジョブを編集すると、ローカルフォルダの保存先が表示・選択されない — 古い UI **(a)**、新しい UI (b)
- 古い UI の原因:
  - `ngax/templates/backends/file.html:3` の `ng-init="HideFolderBrowser = ($parent.Path||'') != ''"` は、テンプレートを読み込んだときに 1 回しか走らない。
  - 既定のバックエンドは `file`（`EditUriBackendConfig.js:23`）。ジョブの URI より先に SystemInfo が届くと、`reparseuri`（`backupEditUri.js:250-301`）が、Path が空のまま `file.html` を読み込む。
  - その後 URI が届いても、バックエンドが変わらないのでテンプレートは作り直されず、空のツリー表示のまま残る。スレッドの Jojo-1000 のコメントとも合う。
  - もう 1 点、`targetFolderPicker.js` は `ngModel` を監視していないので、読み込んだパスをツリーで展開・強調しない。
- 直し方: `ng-init` をやめて `$parent.Path` を監視する（10 行ほど）。ツリーの強調は任意で、もっと大きい。
- 確かめ方: 既存のローカルフォルダのジョブを編集し、「次へ」と再読み込みを何度か繰り返す。設定したパスがテキストで毎回表示されること。
- 新しい UI: `[startingPath]` でパスを渡し、ツリーをそこまで展開する（`single-destination.component.html:152-156`、`file-tree.component.ts:1005-1010`）。データが遅れて届く場合は動かして確かめていない。
- **09-27 追記（検証済み）**: 再現して直した → `fix/local-folder-shown-on-edit`（`4ed8daeb`）。
  - 再現条件: ページを直接開くと正しく表示される。ホームから編集へ移る（テンプレートがキャッシュ済み）と、3/3 回ツリーが表示され、`Path` はあるのに `HideFolderBrowser` は false だった。
  - 直し方は当初案（`$parent.Path` を監視）から変えた。監視にすると、ツリーでフォルダを選ぶだけで文字入力に切り替わってしまう。代わりに `file` のパーサー（保存先を読んだときだけ走る）で判断し、フラグは `Path` と同じエディタのスコープに置いた。`ng-init` は新規・種類の切り替え用に残した。
  - 直した後: ホーム→編集で 4/4 回パスの文字入力を表示。切り替えボタン、ツリーでの選択、変更なしの保存、新規ジョブも確認した。ツリーで保存先を強調する機能は元々なく、今回も対象外。
  - 新しい UI: 直接開いても、ホームからアプリ内で移っても、保存先のパスが入力欄に出た（影響なし）。

### [#4405](https://github.com/duplicati/duplicati/issues/4405) S3 のクライアント（aws/minio）の設定が保存されない・違う値が表示される — 古い UI **(a)**、新しい UI (b)
- 古い UI の原因: S3 の読み込み処理の最後が、無条件に `scope.s3_client = s3_client_options[0];`（`ngax/scripts/services/EditUriBuiltins.js:162`）。
  - URI を読む処理（`:431-436`）は保存済みの値を正しく入れる。しかし読み込み処理は `$watch('Backend')`（`backupEditUri.js:213-248`）から呼ばれ、その後に走ると aws に戻してしまう。タイミングしだいで起きる、という報告と合う。
  - その状態で保存すると、URL を組み立てる処理（`:667`）が `s3-client=aws` を書く。
- 直し方: `if (!scope.s3_client) scope.s3_client = s3_client_options[0];`（1〜2 行）。
- 確かめ方: `s3-client=minio` のジョブを、DevTools の通信制限をかけながら何度も編集・再読み込みし、「保存先 URL をコピー」の値を見る。
- 新しい UI: `s3-client` は URL から入る選択肢の項目で、上書きする処理はない（`destination.config.ts:431-446`、動かしてはいない）。
- **09-27 追記（検証済み）**: 再現して直した → `fix/s3-client-kept-on-edit`（`0b3af04c`）。
  - 順序は確定的: `reparseuri` は `Backend` を設定してすぐパーサーを呼び、`$watch('Backend')` のローダーは次の digest で後から走る。なので「タイミングしだい」ではなく、既存のジョブを開くたびに aws に戻る（ブラウザで 2 回とも再現）。
  - 直す前: 編集画面で aws と表示され、変更せずに保存すると `s3-client=minio` → `aws` に書き換わった（API で確認）。
  - 直した後: minio と表示され、保存しても `minio` のまま。新規ジョブの既定は aws のまま、編集で aws に切り替えた保存も反映された。
  - 新しい UI: 同じ形のジョブを編集すると「MinIO Library (minio)」と表示され、変更なしで保存しても `minio` のまま（ブラウザで確認、影響なし）。

### [#3750](https://github.com/duplicati/duplicati/issues/3750) S3 の独自のストレージクラスが、保存後に既定に戻る — 古い UI **(a)**、新しい UI (b)
- 古い UI の原因:
  - 「Custom storage class」（`ngax/templates/backends/s3.html:50`、`value=""`）を選ぶと、`s3_storageclass` が null になる。
  - URL を組み立てる処理は `if (scope.s3_storageclass != null)` のときしかクラスを書かない（`EditUriBuiltins.js:664-665`）ので、入力した独自の値が捨てられる。
  - すぐ上のリージョンの組み立て（`:654-658`）には、独自の値用の `else if (custom != null)` の分岐がある。
- 直し方: `else if (scope.s3_storageclass_custom != null) opts['s3-storage-class'] = scope.s3_storageclass_custom;` を足す（2 行）。
- 確かめ方: Custom を選んで `GLACIER_IR` と入力して保存し、エクスポートか再編集で URL に `s3-storage-class=GLACIER_IR` が入っていること。
- 重複の #4882 は、メンテナが「新しい UI で修正済み」として閉じている。新しい UI は自由入力できる選択肢（`destination.config.ts:448-451`）。
- **09-27 追記（検証済み）**: 再現して直した → `fix/s3-custom-storage-class`（`261b64cf`）。
  - `GLACIER_IR` は今のサーバーの一覧にあるので、一覧にない `CUSTOM_TEST_CLASS` で確認した。
  - 直す前: Custom を選んで入力し保存すると、URL に `s3-storage-class` がなかった。直した後: `s3-storage-class=CUSTOM_TEST_CLASS` が入り、開き直しても表示・保持される。一覧から選んだ値（`STANDARD`）は従来どおり。
  - 新しい UI: 高度な設定で `s3-storage-class` を追加して自由入力し保存すると、URL に入った（ブラウザで確認、影響なし）。

### [#4927](https://github.com/duplicati/duplicati/issues/4927) リムーバブルドライブがないとき「0 Versions」と表示される — (b)、残りは (d)
- 「0 Versions」の表示は #4829 として `71eb03130` で修正済み（`Runner.cs:1283-1291` が、中断された結果ではメタデータを更新しない）。
- 「元がないときに版を作らない」という要望は、新しいオプション `--abort-if-source-missing`（`Options.cs:443`、`bfcc2247b`、2026-06）で対応済み。
- `--allow-missing-source` で全部の元がないときに空の版ができるかどうかは未確認で、変えるならバックエンドの設計の話。close 候補。

## G: 「database is locked」系

3 件とも、master では #7366 の漏れそのものではない。ただし、同じ種類の問題が 2 か所残っていそう（下の「G で見つかった新しい候補」）。

### [#3445](https://github.com/duplicati/duplicati/issues/3445) 強制停止の後にバックアップすると「database is locked」 — (b)、続きの (c) あり
- 当時の原因は `Thread.Abort`。中断されたバックアップの `finally`（ロックの解除を含む）が、アップロードが返る約 50 秒後まで走らなかった。master にはこの仕組み自体がない（.NET 8、停止は `TaskControl.Terminate` と `ProgressToken`、DB は `await using` で閉じる）。
- `AbortedBackupTests.cs:129` は、アップロードが止まった状態での中断を試しているが、その後に 2 回目のバックアップは走らせていない。

### [#4631](https://github.com/duplicati/duplicati/issues/4631) 自動クリーンアップ中に「database is locked」、その後 DB ファイルの移動で IOException — (b) 修正済み
- #5552（2024-09）で修正され、`RepairHandlerTests.AutoCleanupRepairDoesNotLockDatabaseAsync`（`RepairHandlerTests.cs:334`）という回帰テストもある。close 可。

### [#3040](https://github.com/duplicati/duplicati/issues/3040) バックアップ中にログを見られない（「database is locked」） — (d)
- 今は `databaseLockTracker` が意図して断り、分かりやすいメッセージ（「実行中の操作が終わるのを待って」）を返す（`BackupGet.cs:196-197`、`:217-218`）。
- WAL なら読み取り専用で並行して読める可能性はあるが、ロックの仕組みを意図して入れているので、機能追加としてメンテナの合意が要る。

### G で見つかった新しい候補（Issue なし、推測・未検証）
1. **`RepairHandler` が健全かもしれない DB をリネームする**
   - `RepairHandler.cs:71-101` は、修復用 DB を開くときのあらゆるエラーを「DB がない」とみなし、`:101` で DB をリネームしてから、作り直し（recreate）をする。
   - 一時的な busy エラーや、#7366 の接続漏れでも、この経路に入りうる。Windows では、#4631 と同じ IOException になる。
   - 直し方: DB がない・空のときだけ作り直しに進み、`SqliteException` の busy は投げ直す（15 行ほど）。
   - テスト: 別の接続で DB に書き込みロックを持ったまま修復を走らせ、ファイルがリネームされないことを確かめる。
2. **派生クラスの初期化での接続漏れ（#7366 の続き）**
   - `LocalBackupDatabase.CreateAsync`（`LocalBackupDatabase.cs:177`）などは、基底の作成の後にも初期化をする（進捗トークンを使う）。そこで失敗すると（停止でトークンが取り消されたときなど）、接続を閉じない。#7366 は基底の部分（`LocalDatabase.cs:234`）だけを直している。
   - WAL で書き込みトランザクションを持ったまま漏れると、再起動まで後続の書き込みを全部止める（「再起動すると直る」という報告と合う）。
   - 直し方: 派生クラスの作成でも try/catch で閉じる（10 行ほど）。
   - テスト: #7366 の `IsOpenInThisProcess` で、基底の作成の後にトークンを取り消して、ファイルが開いたまま残らないことを確かめる。**#7366 の上に積む**。

## 前回の候補の残り

- [#5573](https://github.com/duplicati/duplicati/issues/5573) VSS でバックアップしたファイルの restore で「ロック中」の警告が出る — `--restore-with-local-blocks` で元のファイルを読みに行って失敗する。動作自体は壊れていない（restore はバックアップ先から取って成功する）。警告の段階の好みの問題に近いので、優先度は低い。
