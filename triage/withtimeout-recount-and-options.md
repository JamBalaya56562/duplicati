# WithTimeout: 同期版の数え直しと、判断が要る 2 点

master 7cdde158。数え方（検証済み）: 同期版の 2 つに一時的に `[Obsolete("SYNCWT")]` を付け、`Duplicati.slnx` を `--no-incremental` でビルドし、ファイルロガーで CS0618 を拾った。C の調査の「11 か所」は数え漏れで、**28 か所**ある。

| 箇所 | 中身 | C（smb-timeout-aborts）の後の動き | 害 |
|---|---|---|---|
| SMB ×10 | SMBLibrary の同期の呼び出し | 打ち切ったら切断して作り直す（C で対応済み） | なし |
| File 256/330/481/524 | 同期の IO（列挙、削除、フォルダー作成） | 待つのをやめ、IO は裏で続く | 小: 状態を共有しない。止まった共有ドライブではスレッドが 1 本残る |
| Mega 96/156/194 | `GetNodes()`、`Download(node)` | 待つのをやめ、裏で続く | 中: MegaApiClient を共有。ただし BackendManager は失敗したバックエンドを捨てる |
| SSHv2 180 | `GetAttributes` | 同上 | 小: SSH.NET は 1 つのセッションで要求を並行に扱える |
| SSHv2 592/676 | `ListDirectoryAsync` は IAsyncEnumerable を作るだけ | 影響なし（すぐ返る） | **別の不具合: 一覧そのものに list-timeout が掛かっていない**（Minio と同じ形） |
| SSHv2 335 | `RenameFileAsync(...).ConfigureAwait(false)` は Task ではなく ConfiguredTaskAwaitable を返す | ― | **別の不具合: rename が await されず投げっぱなし。失敗しても気づかない** |
| TencentCOS 225/253/367 | SDK の同期の HTTP（削除、HEAD、コピー） | 待つのをやめ、裏で続く | 小 |
| B2AuthHelper 196 | 応答のストリームを同期で読む | 同上 | 小 |
| Filejump 552 | `HttpClient.Send(request, ct)` | token が効くので、もともと打ち切られる | なし |
| S3MinioClient 115 | observable を作るだけ | 影響なし | `fix/s3-minio-list-timeout` で解消 |
| Utility 2133（WithPerItemTimeout） | `GetAsyncEnumerator` を作るだけ | 影響なし | `fix/with-per-item-timeout` で解消 |

前提: BackendManager は、失敗した操作のバックエンドを `PreventReuse()` で捨てて作り直す（BackendManager.Handler.cs:431, 631）。そのため通常のバックアップでは、裏に残った呼び出しが新しいバックエンドとクライアントを共有することはない。共有が起きるのは、BackendTool、接続テスト、バックアップ元（`ListAsync(path)`）のように同じインスタンスを使い回す場合。

## 判断 1: C の変更（同期版が待つのをやめる）が File、Mega、COS、SSH、B2 にも効く件

- **X（推奨）**: このまま全体に効かせる。理由: 各 timeout がやっと効くようになる。害は小さく、通常のバックアップでは失敗したバックエンドは捨てられる。Mega だけは、判断 2 の PR で「timeout になったらクライアントを捨ててログインし直す」を足す。
- Y: C の打ち切りを SMB だけに絞る（同期版の WithTimeout は元に戻し、SMB に自前の helper を持たせる）。ほかのバックエンドは今までどおり timeout が効かない。
- Z: 全体に効かせ、Mega の対策もしない。

## 判断 2: async 版で、渡す処理が token を見ないため打ち切られない件（`_ =>` の 18 か所など）

ライブラリが token を受け取るか（PowerShell のリフレクションで検証済み）:
- Mega: `GetNodes(Async)`、`DeleteAsync`、`RenameAsync` は token を受け取らない。`Download(node, ct)` は受け取るが、token はストリームの読み込みにしか使わず、そのストリームは呼び出し側の token を使う `CopyStreamAsync` が読むので、渡しても打ち切りには効かない。
- Storj（uplink.NET 2.14）: `EnsureBucketAsync`、`DeleteObjectAsync`、`DownloadObjectAsync`、`ListObjectsAsync`、`UploadObjectAsync`、`CopyObjectAsync` のどれも token を受け取らない。
- SharePoint（CSOM）: `ExecuteQueryAsync()` は token を受け取らない。
- File: 同期の IO（上の表のとおり、実は同期版に解決されている）。

→ token を渡して直せる箇所はない。直すなら「待つのをやめる」しかない。

- **A（推奨）**: async 版の WithTimeout も `await func(cts.Token).WaitAsync(cts.Token)` で待つのをやめる（約 220 か所のうち、token を見る処理には変化なし）。打ち切った処理が裏に残る害への対策を、バックエンドごとに 1 つの PR に入れる。
  - SharePoint: timeout になったら `GetSpClientContextAsync(forceNewContext: true)` 相当で context を作り直す（ClientContext はスレッドセーフでない）。
  - Mega: timeout になったらクライアントを捨てる（判断 1 の X と共通）。
  - Storj: uplink（Go）は並行に使えるので対策なし。
- B: バックエンドごとに、その呼び出しだけ `.WaitAsync` で包む（汎用の WithTimeout は変えない）。影響範囲は狭いが、同じ問題の箇所が今後増えても気づけない。
- C: 直さず、token を見ない呼び出しには timeout が効かないことを記録するだけ。

## すぐ直すもの（判断不要、作業中）

- SSHv2 335 の rename の投げっぱなし: `fix/ssh-rename-awaited`（Docker の SFTP サーバーで赤→緑を示す）
- SSHv2 592/676 の一覧に list-timeout が効かない: `fix/ssh-list-timeout`（docker pause で赤→緑）
