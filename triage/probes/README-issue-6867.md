# #6867 実機スリープ試験の手順（未実施）

`fix/resume-waits-for-suspend-handling` は「スリープ処理が終わる前に復帰が来ると、復帰が失われて一時停止のまま」になる経路を直した。これが Issue の報告者と同じ経路かどうかは、まだ実機で確かめていない。確かめるための手順。

## 用意するもの

- `issue-6867-sleep-probe.patch`: 診断用のプローブ（**コミットしない**）。
  - サーバー側（`LiveControls` の OnSuspend/OnResume の入口と出口、`Program.LiveControl_StateChanged`、ロングポーリングの待機）は、サーバーのログファイルに `PROBE6867` のタグで出る。
  - トレイ側（受け取った状態、UI スレッドで反映した状態、ポーリングのエラー）は、環境変数 `PROBE6867_FILE` のファイルに直接書く。サーバーのログのスコープの外なので。
- このマシンはモダンスタンバイ（`powercfg /a` で「スタンバイ (S0 低電力アイドル) ネットワークに接続されています」）。報告者の Windows 11 と同じ種類。

## 手順

1. master（直す前）の作業コピーに当てる: `patch -p1 < triage/probes/issue-6867-sleep-probe.patch`
2. `Executables/Duplicati.GUI.TrayIcon` をビルドする（mise の dotnet）。
3. 別のデータフォルダーとポートで起動する（本物の Duplicati と混ざらないように）。apphost はシステムの .NET 8 を拾うので、mise の `dotnet.exe` で dll を起動する。
   ```bash
   export PROBE6867_FILE='<scratch>\tray-probe.log'
   dotnet Executables/Duplicati.GUI.TrayIcon/bin/Debug/net10.0/Duplicati.GUI.TrayIcon.dll \
     --server-datafolder='<scratch>\data' --webservice-port=8298 --webservice-password=<test> \
     --disable-db-encryption=true --log-file='<scratch>\tray.log' --log-level=Information
   ```
   - ログの 1 行目付近に `Power mode provider Default: Duplicati.Library.WindowsModules.PowerManagementModule` が出ることを確認する（Debug の Server 単体ではこのモジュールの読み込みに失敗するが、トレイでは読める）。
4. 利用者に、スタート → 電源 → スリープ で 6〜10 分眠らせてから復帰してもらう。アイコンの見た目と、右クリックのメニューが「Pause」か「Resume」かを聞く（クリックはしない）。
5. `tray.log` の `PROBE6867` と `tray-probe.log` を突き合わせる。
   - `OnResume enter: ... pausedForSuspend=False` が `OnSuspend exit` より前に出ていれば、今回直した経路。
   - サーバーは Running なのにトレイが Paused のままなら、別の経路（トレイ側）。最後に「Tray received」「applied」した状態と LastEventID を見る。
6. 再現しなければ、スリープを何回か繰り返す（モダンスタンバイは眠っている間に短い復帰を挟むことがある）。

## 片付け

- トレイのプロセスを止める。`jj restore` でプローブを外す。
