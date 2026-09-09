# バックエンドの URL 復号・符号化

- **対象**: [duplicati/duplicati](https://github.com/duplicati/duplicati)
- **調査日**: 2026-08-22 〜 2026-08-27
- **発端**: [#4880](https://github.com/duplicati/duplicati/issues/4880)「WebDAV の保存先パスの `+` が空白になる」

> **要点**: 保存先 URL からフォルダ名を取り出す処理に、**同じ誤りが複数のバックエンドに散っている**。
> `RelaxedUri` は**構築時にホストもパスも復号する**ので、その結果をもう一度復号すると
> 名前に `%` を含むフォルダに到達できなくなる。
> URL に**戻す**側の符号化が抜けているものもある。

---

## `RelaxedUri` の性質（すべての出発点）

```csharp
// RelaxedUri.cs のコンストラクタ
var h = UrlEncoding.UrlDecode(m.Groups["hostname"]...);   // ホストを復号
var p = UrlEncoding.UrlDecode(m.Groups["path"]...);       // パスを復号
```

つまり `RelaxedUri.Host` / `.Path` / `.HostAndPath` は**すべて復号済み**。
**ここにもう一度 `UrlDecode` を掛けると二重復号になる。**

さらに `UrlDecode` は `+` を空白に変える。これは
`application/x-www-form-urlencoded`（クエリ文字列）の規則で、**パスでは誤り**。
パス用の対（`UrlPathDecode`）は [#7197](https://github.com/duplicati/duplicati/pull/7197) で追加した。

---

## バックエンド別の状況（2026-09-04 時点で全件マージ済み）

| バックエンド | 症状 | 対処 | 状態 |
|---|---|---|---|
| **WebDAV** | `+` が空白 / 二重復号 | `System.Uri` で解析（[#7200](https://github.com/duplicati/duplicati/pull/7200)） | **マージ済み 2026-09-04** |
| **SharePoint** | 同上 | `System.Uri` で解析（[#7201](https://github.com/duplicati/duplicati/pull/7201)） | **マージ済み 2026-08-28** |
| **Dropbox** | 二重復号。`%` を含むフォルダに到達不能 | 2回目の復号を削除（[#7202](https://github.com/duplicati/duplicati/pull/7202)） | **マージ済み 2026-08-27** |
| **OneDrive / Graph** | 二重復号 **＋** URL 組み立て時の符号化欠落 | 両方（[#7204](https://github.com/duplicati/duplicati/pull/7204)） | **マージ済み 2026-08-28**（下記のとおり統合版） |
| SSHv2 / SMB / FTP / pCloud / Tahoe | — | `System.Uri` へ移行済み（#7145 ほか） | 完了 |

**[#4880](https://github.com/duplicati/duplicati/issues/4880) は 2026-09-04 にようやく直りました。**
Issue 自体は 2026-08-22 に COMPLETED で閉じられていますが、**閉じた根拠だった #7197 は誤り**で
（[ISSUE-TRIAGE-REPORT.md](ISSUE-TRIAGE-REPORT.md) の 2026-08-27 の項）、
本当の修正は #7200 でした。**Issue が閉じたまま、中身が6週間後に直った**形です。
「COMPLETED で閉じている」ことは直っている証拠になりません。

`System.Uri` に移せるかは **authority がサーバ名かフォルダ名か**で決まる
（`System.Uri` は authority を小文字化する）。詳細は #7145 の分類。
Dropbox と OneDrive は authority がフォルダ名なので**移せない**。

### 生の `+` はまだ直っていない

`dropbox://My+Folder` のように**生の `+` を手書きした場合**は、
`RelaxedUri` のパース内で空白になり、上記のどの修正でも直らない。
`System.Uri` に移せた WebDAV / SharePoint だけが例外（SharePoint は 2026-08-28、
WebDAV は 2026-09-04 に入った）。
**共有パーサーを変える話になるので、メンテナの判断が要る。**

---

## OneDrive はメンテナの実装と統合された（2026-08-28）

kenkendk が同じ8箇所を [#7219](https://github.com/duplicati/duplicati/pull/7219)
「Fix OneDrive browsing」で別目的から集約していた（`BuildRootUrl` — パスが空のとき
`/root:` ではなく `/root` にする、ドライブ直下の参照修正）。#7219 が先にマージされ、
その後 master が #7204 に取り込まれ、**符号化が `BuildRootUrl` の中に置かれた**。

```csharp
: $"{drivePrefix}/root:{ToUrlPath(fullPath)}";
```

**こちらの方が元の実装より良い。** `BuildRootUrl` は `ListAsync(path)` /
`GetEntryAsync` / `CreateFolderAsync` からも直接呼ばれるので、
当初の `RootItemUrl` 版では個別に `ToUrlPath` を掛ける必要があった3箇所も
自動で符号化される。フォルダ参照 UI を含めて漏れがない。

設計上の要（`RootPath` は復号済みのまま、URL に載せる時だけ符号化）は保たれている。
`CreateFolderAsync` は今も `RootPath.Split('/')` の生の名前を `DriveItem.Name` に使う。
`OneDriveUrlTests` 12件は統合後も緑。

---

## OneDrive は二段構え（実機で確認済み）

`RootPath` は**復号済みのまま URL に文字列連結**されていた。
Graph のアドレス構文 `/root:{path}:/children` の `{path}` は URL の一部なので、
**パーセント符号化されていなければならない**。

### 実測1 — 資格情報なし

```
onedrivev2://a%20b     -> root [a b]
onedrivev2://a%2520b   -> root [a b]     ← 別フォルダなのに同一
組み立て [.../root:/a#b:/children]  →  送信時 fragment [#b:/children]（切り捨て）
```

### 実測2 — 実アカウント（`temp` に `a%20b` と `a#b` を作成）

| 送った綴り | 結果 | 到達先 |
|---|---|---|
| `a%2520b` | **200** | `"name":"a%20b"` |
| `a%20b` | **404** | `a b`（存在しない） |
| `a%23b` | **200** | `"name":"a#b"` |
| `a#b`（生） | **404** | fragment で切れる |

**Graph はパスセグメントを1回復号する。**
よって二重復号を外すだけでは不十分で、組み立て時の符号化が要る。

### 設計上の注意

`RootPath` は**復号済みのままにしなければならない**。
`CreateFolderAsync` がこれを `Split('/')` して `DriveItem.Name`（フォルダ名）に使うため、
符号化済みにすると `a%2520b` という名前のフォルダを作ってしまう。
**URL に載せる時だけ符号化する。**

---

## 検証の作法（ここで学んだこと）

**シームは実際の呼び出し元が渡す値を受け取らなければ、赤→緑は何も証明しない。**

#7197 は `WEBDAV.NormalizePath` を直し、`NormalizePath("My+Folder")` で赤→緑を確認した。
しかしコンストラクタが渡すのは `RelaxedUri(url).Path`（**復号済み**）で、
`+` はその時点で既に消えていた。**#4880 は直っていなかった。**

- シームは**利用者が与える入力そのもの**（URL 全体）を受け取ること
- 外部へのリクエストで終わる修正は、**送信されるリクエスト**を検証すること
  （`HttpMessageHandler` を注入する。`BoxBackend` / `TahoeBackend` に前例）
- **赤の内容が報告された症状と一致するか**まで見ること
- 「同じことを名前で言い換えただけ」の変更を混ぜないこと。本当の修正が見えなくなる

### 長さで判定しない

WebDAV の調査で一度誤読した。新旧のメタデータがどちらも 137 バイトで、
**長さでは区別できなかった**。判定は必ずハッシュなど内容で行う。

---

## 未着手

- **生の `+`** — `RelaxedUri` のパース内。共有パーサーの変更になる
- **`RelaxedUri` の削除** — authority にフォルダ名を持つ約24箇所と、
  任意の URL を round-trip する約30箇所があるため、呼び出し側の変換だけでは消せない
  （#7145 の分類）。URL の規約自体を変える話で、メンテナの判断が要る
