# Minio を 6.0.0 に固定している理由と、上げてよい条件

- **調査日**: 2026-08-15
- **対象**: [Duplicati.Library.Backend.S3.csproj](../Duplicati/Library/Backend/S3/Duplicati.Library.Backend.S3.csproj) の `<PackageReference Include="Minio" Version="6.0.0" />`
- **結論**: **上げない。** ただし理由は「壊れたままだから」ではなく、変質している。

---

## 何があったか

Minio > 6.0.0 は**エラーコードを無視し、失敗したアップロードを成功として扱った**。バックアップソフトにとって最悪の壊れ方。

- 報告: [duplicati#6489](https://github.com/duplicati/duplicati/issues/6489)「S3 Minio client upload failure status code is treated as success」
- 対処: [duplicati#6495](https://github.com/duplicati/duplicati/pull/6495)「Revert MinIO to version 6.0.0」（2025-09-10 マージ）

kenkendk の説明：

> The issue with Minio > 6.0.0 is that it is using a new async system that ignores all error codes,
> making it appear as if all operations succeed, even when they fail.

**Duplicati の使い方の問題ではない。** 修正 PR が触ったのは `MinioClient.cs` / `ObjectOperations.cs` / `RequestExtensions.cs` / `DefaultErrorHandler.cs` ですべてライブラリ内部。

---

## 上流では既に直っている

| 出来事 | 日付 |
|---|---|
| Duplicati が 6.0.0 へ差し戻し | 2025-09-10 |
| **minio-dotnet が修正（[PR #1320](https://github.com/minio/minio-dotnet/pull/1320)）** | **2025-10-11** |
| 7.0.0 リリース | 2025-11-05 |

根拠にされた [#1204](https://github.com/minio/minio-dotnet/issues/1204) / [#1318](https://github.com/minio/minio-dotnet/issues/1318) は**両方 CLOSED**（2025-10-23）。

---

## それでも上げない理由（2つ）

### ① 6.0.5 は罠

修正コミット `5b55b0a28272` との前後関係を機械的に確認した。

```bash
gh api repos/minio/minio-dotnet/compare/5b55b0a28272...7.0.0   # status=ahead   → 修正を含む
gh api repos/minio/minio-dotnet/compare/5b55b0a28272...6.0.5   # status=behind  → 修正を含まない
```

**6.0.5 は 2025-06-24 で修正（10月）より前。**「6.x の最新に上げる」という一見安全な操作が、**元のデータ欠損級のバグをそのまま連れ戻す。**

### ② 7.0.0 は自分の回帰を抱えたままリリースが止まっている

7.0.0 は別の回帰 [#1342](https://github.com/minio/minio-dotnet/issues/1342) を持ち込み、その修正は master にあるだけ。

> [#1381](https://github.com/minio/minio-dotnet/issues/1381) (OPEN, 2026-07-22):
> Currently there's **no release** which includes the fix for #1342

**7.0.0 以降リリースが一度も出ていない。**

---

## 7.0.0 の既知問題が Duplicati に当たるか（確認済み・再調査不要）

| 問題 | 判定 | 根拠 |
|---|---|---|
| #1342 部分ダウンロード破壊 | **当たらない** | [S3MinioClient.cs](../Duplicati/Library/Backend/S3/S3MinioClient.cs) は `WithOffsetAndLength` を使わない。7.0.0 の `PartialContentException` は HTTP 206 でのみ発火 |
| #1369 `HttpClient` 破棄エラー | **当たらない** | `S3MinioClient.Dispose()` は空で、破棄しない |
| #1379 `PutObjectAsync` の `ObjectDisposedException` | **未確定** | 報告は .NET Framework 4.8。Duplicati は net10.0 なのでおそらく当たらないが、確証なし |

つまり **7.0.0 を選ぶこと自体は技術的には可能**。しかし9ヶ月リリースが止まっているライブラリに、バックアップの生命線であるアップロード経路を預ける判断にはならない。

---

## MinIO プロジェクト自体の状態（2026-08-15 時点）

```
minio/minio        (サーバ本体)  archived=true   最終リリース 2025-10-15 (CVE対応)
minio/minio-dotnet (SDK)        archived=false  最終リリース 2025-11-05
```

**サーバ本体はアーカイブ済み＝開発終了。** SDK はまだアーカイブされていないが、親プロジェクトが終了しリリースも9ヶ月止まっている。

---

## Minio クライアントは Duplicati に必要か

`--s3-client=minio` は **AWS が既定**で、Minio は opt-in（[S3Backend.cs:310-323](../Duplicati/Library/Backend/S3/S3Backend.cs:310)）。
`IS3Client` の9メソッドは**両実装で完全に同一**で、Minio 側だけの機能はない。

公式ドキュメント（`s3-compatible-destination.md`）の位置づけ：

> Generally, **both libraries will work with most providers**, but the AWS library has some defaults
> that may not be compatible with other providers. While you can configure the settings,
> **it may be simpler to use Minio with the default settings**.

> you often need to set either `--s3-disable-chunk-encoding` **or** use the Minio client
> with `--s3-client=minio` **(but not both)**

**「Minio でなければならない」ケースは文書上ない。** 利便性の逃げ道であり、AWS クライアント側は `--s3-disable-chunk-encoding` / `--s3-disable-payload-signing` で同じ範囲を覆う。

### それでも削除は簡単ではない

1. **既存ユーザの設定が壊れる。** `--s3-client=minio` を保存している人は `UnknownS3ClientError` に落ちてバックアップが止まる
2. **メンテナは現役で保守している** — `Add support for remote locks`(2025-12-14) / `Fixed Minio locking implementation`(2025-12-17) / `Add support for an authentication region`(2026-01-06)。廃止予定として扱っていない

**注**: RustFS 等は S3 互換**サーバ**であって、クライアント SDK の代替ではない。Duplicati から見れば接続先の一つで、`--s3-client` の選択とは独立。

---

## 上げてよくなる条件

**minio-dotnet が 7.0.0 より後の新リリースを出したとき。** そのとき見るべきは 6.0.5 ではなく **7.x 以降**。ここを間違えると①の罠を踏む。

副次的な効果として、[PACKAGE-VERSION-DRIFT.md](PACKAGE-VERSION-DRIFT.md) の `System.IO.Hashing`（7.0.0 / 10.0.3）の分裂も解消する。Minio 6.0.0 が `System.IO.Hashing 7.0.0` を要求していることが唯一の原因。
