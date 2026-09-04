# 削除の「もう無い」を `FileMissingException` に写しているか — 未掃討

- **調査日**: 2026-09-01
- **状態 2026-09-04**: **完了。** 確かめられた2つ（OpenStack / GCS）は入り、残る2つは
  API の挙動を確定できないので着手しません。再開の条件は末尾に書きました
- **発端**: 2026-08-31、無関係な3つのブランチで GCS Tests が3 OS すべて同じ形で落ちた

## 族の全体像

「削除の答えが返らず、リトライが**もう無い**を受け取る」という一つの族に、
**独立した半分が2つ**あります。

| 半分 | 中身 | 状態 |
|---|---|---|
| (a) キャッシュ | 失敗したら名前→id のキャッシュを捨てる | **掃討済み** — Box / GoogleDrive / Mega は元から、Drime [#7221](https://github.com/duplicati/duplicati/pull/7221)、Filejump [#7240](https://github.com/duplicati/duplicati/pull/7240)、Filen [#7241](https://github.com/duplicati/duplicati/pull/7241) |
| (b) マッピング | 「もう無い」を `FileMissingException` として上げる | **未掃討** — このファイル |

**(a) の掃討は「キャッシュを持つか」で絞った**ので、キャッシュを持たないバックエンドは
最初から範囲外でした。GCS がまさにそれです。

## 受け皿は既にある

`BackendExtensions` の自己診断は、`FileMissingException` なら3箇所で先へ進みます
（[#7108](https://github.com/duplicati/duplicati/pull/7108) /
[#7109](https://github.com/duplicati/duplicati/pull/7109) で入れたもの）。

- `TestReadWritePermissionsAsync` の一覧後の削除（`BackendExtensions.cs:91`）
- 同じくクリーンアップの削除（`:167`）
- `TestReadPermissionsAsync` 側

**乗らないのはバックエンドが `FileMissingException` を上げないときだけ**です。
GCS の実例（2026-08-31、3 OS）:

```
[12:52:49 675] Operation failed with exception, 2 retries left
[12:52:50 800] Operation failed with exception, 1 retries left
[12:52:52 913] Error on deleting file: duplicati-access-privileges-test.txt,
               error: ... 404 (Not Found).
```

`GoogleCloudStorage.DeleteAsync` は `EnsureSuccessStatusCode` の
`HttpRequestException` をそのまま上げるので、`catch (FileMissingException)` に届きません。
kenkendk の [#7245](https://github.com/duplicati/duplicati/pull/7245) が 404 を写す1箇所を足しています。

**GCS は「一部だけ直っている」の実例です。**同じファイルの
`GetObjectLockUntilAsync` / `SetObjectLockUntilAsync` / `GetAsync` の**3箇所**は
404 → `FileMissingException` を持ち、`DeleteAsync` と `RenameAsync` だけが持ちません。

## 素朴な grep は使えない — メソッド単位で数え直した

**ファイル内に `FileMissingException` があるか、では判定できません。**
GCS はその見方だと「有り」と出ますが、3箇所とも別のメソッドです。

**2026-09-01、`DeleteAsync` の本体をブレース対応で切り出して数え直しました。**
`Duplicati/Library/Backend` 配下に `DeleteAsync` は **30実装**あり、
本体に `FileMissingException` が出てこないのは **18** です。

**ただし18がそのまま候補ではありません。**内訳を読むと3種類に割れます。

| 種別 | 例 | 扱い |
|---|---|---|
| 委譲しているだけ | `SMBBackend` → `SMBShareConnection`、`Dropbox.cs` → `DropboxHelper`、`Idrivee2` → `con.DeleteObjectAsync`、`AzureBlob` → `WrapWithExceptionHandler` | **委譲先を見る**。ここで数えても意味がない |
| ヘルパーで投げている | `Drime` / `Filejump`（`EnsureSuccessStatusCode` が `entryIds` を見て投げる）、`Box`（`_fileCache.Clear()` のみ） | 既に対応済み、または対象外 |
| **素通し** | ~~`OpenStack`~~（[#7260](https://github.com/duplicati/duplicati/pull/7260) で解決）、~~`GoogleCloudStorage`~~（[#7249](https://github.com/duplicati/duplicati/pull/7249) で解決）、`Duplicati/DuplicatiBackend.cs`、`Jottacloud/Jottacloud.cs` | 残り2つは **API の挙動を確かめられないので着手しない** |

**種類の違う1件も見つけました。**`TahoeLAFS/TahoeBackend.cs` の `DeleteAsync`（220行付近）は
ファイルの削除で 404 を受けると **`FolderMissingException`**（フォルダが無い）を投げます。
欠けているのではなく**種類が違う**。ただし Tahoe の WAPI では 404 が
「dircap が不明」と「子が無い」の両方を意味し得るので、**現状が誤りだと断定できませんでした。**

**それでも「その API が消えたファイルの削除に 404 を返すか」は測れていません。**
ドキュメントで確定できる API に絞るのでなければ、#7241 で見送ったのと同じ壁に当たります。

## 測れるものと測れないもの

[#7241](https://github.com/duplicati/duplicati/pull/7241)（Filen）では
マッピングを「エラー本文を測れていない」として**意図的に落としました**。
その判断自体は Filen については正しかったのですが、**区別が粗すぎました**。

- **HTTP 404 は測る必要がない。** 契約が決まっている
- **測れないのは API 独自のエラー本文だけ**（Drime / Filejump の `entryIds` のような）

次に同じ判断をするときは、この2つを分けること。

## 訂正 — 2段目の失敗の原因は、私の見立てとは違いました

**2026-09-01 追記。**当初この節には「`PutAsync` の直後に読めない＝書いた直後のファイルが
すぐ参照できるとは限らない」と書いていました。**それは誤りでした。**

観測した症状はこれです。

```
Error reading file: duplicati-access-privileges-test.txt,
error: The requested file does not exist
  at GoogleCloudStorage.GetAsync ... :407
  at BackendExtensions.TestReadWritePermissionsAsync ... :140
```

実際の原因は [#7249](https://github.com/duplicati/duplicati/pull/7249)（"Fix broken GCS"）が
説明しています — **`RelaxedUri` によるパスの二重符号化**です。GCS には `folder/file` を
`folder%2Ffile` として送る必要がありますが、再符号化で `folder%252Ffile` になり、
**リテラルの `%2F` を含む名前で書かれていました。**書いた直後に読めなかったのは
**タイミングではなく、別の名前で書かれていたから**です。

**教訓 — 測れないものを「たぶんこう」で埋めないこと。**
「私には測る手段がありません」と正しく書いた上で、そのすぐ隣に既知の現象
（[#7109](https://github.com/duplicati/duplicati/pull/7109) で書いたコメント）を根拠として
並べてしまい、**測っていない推測が測った事実のように読める形**になっていました。
並べるなら、どちらが測定でどちらが推測かを行単位で分けること。

なお `BackendExtensions.cs:140` の読み戻しが遅延を許さない件は、
**それ自体としては今も事実**です（クリーンアップ側の `:169` は許している）。
ただし GCS の失敗の原因ではなく、**症状を観測した場所**にすぎませんでした。
直すとしても、読み戻しは書き込み権限を確かめる診断の目的そのものなので、
`catch` で握り潰すのは中身を空にする改変になります。**待って再試行する形**でなければ
意味がありません。今のところ**それを必要とする実例はありません。**

**GCS には触らないこと** — [#7245](https://github.com/duplicati/duplicati/pull/7245) はクローズされ、
[#7249](https://github.com/duplicati/duplicati/pull/7249) が動いています。
404 → `FileMissingException` のマッピングもそちらに含まれています。

## 次にやるなら

**この掃討は終わりです。**確かめられるものは全部やりました。

- **OpenStack** — [公式リファレンス](https://docs.openstack.org/api-ref/object-store/index.html)が
  delete-object を `204` / `404` と明記しており、**同じファイルの `GetAsync` が既に 404 を写していた**。
  [#7260](https://github.com/duplicati/duplicati/pull/7260) でマージ済み（2026-09-04）
- **GCS** — メンテナが [#7249](https://github.com/duplicati/duplicati/pull/7249) で対応済み
- **`Jottacloud` / `DuplicatiBackend`** — **着手しない。**
  Jottacloud は API のドキュメントが無く、`DuplicatiBackend` は Duplicati 自身のサービスで
  こちらから挙動を確かめられない。**推測でマッピングを足さない**（#7241 と同じ判断）

**再開する条件**は、その API が消えたオブジェクトの削除に何を返すかを
**ドキュメントか実測で確定できたとき**だけです。
