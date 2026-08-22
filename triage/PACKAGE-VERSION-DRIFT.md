# パッケージバージョン不一致 ── **完了**

- **対象**: [duplicati/duplicati](https://github.com/duplicati/duplicati) `Duplicati.slnx`（出荷対象 104 プロジェクト）
- **測定日**: 2026-08-22
- **測定基準**: `66cfb242da3b`（master, "Merge pull request #7197 ..."）
- **発端**: 「特に理由もなくバージョンが異なっているなら最新に統一したい」

> **結論: 意図しない不一致はゼロになりました。** 289 パッケージ中、複数の版に分裂しているのは
> **1件（`System.IO.Hashing`）だけ**で、それは Minio 6.0.0 固定に伴う**意図的なもの**です。
> **この課題に残作業はありません。** 新たに調べ直す必要が出るのは、パッケージを追加・更新したときだけです。

> **重要**: この不一致に**実害は確認できていませんでした**。.NET は最終出力時に最も高い版を選ぶため、
> 多くは公開時に自動解決されます。目的は一貫性であって、バグ修正ではありませんでした。

---

## 経緯：12件 → 1件

| 時点 | 分裂件数 | 何が起きたか |
|---|---|---|
| 2026-08-15（初回測定） | 12 | `pkgdrift.py` で全件測定 |
| 2026-08-17 | 8 | [#7179](https://github.com/duplicati/duplicati/pull/7179) マージ（Microsoft.Extensions 系 4件） |
| 2026-08-18 | 7 | [#7176](https://github.com/duplicati/duplicati/pull/7176) マージ（SharpAESCrypt） |
| 2026-08-22 | 4 | [#7175](https://github.com/duplicati/duplicati/pull/7175) マージ（Google.Apis 系 3件） |
| 2026-08-22 | **1** | [#7198](https://github.com/duplicati/duplicati/pull/7198) マージ（AWSSDK.Core / Azure.Core / System.ClientModel） |

### 解消した内訳

| パッケージ | PR |
|---|---|
| Microsoft.Extensions.Primitives / Options / Configuration.Abstractions / Diagnostics.Abstractions | [#7179](https://github.com/duplicati/duplicati/pull/7179) |
| SharpAESCrypt | [#7176](https://github.com/duplicati/duplicati/pull/7176) |
| Google.Apis / Google.Apis.Auth / Google.Apis.Core | [#7175](https://github.com/duplicati/duplicati/pull/7175) |
| AWSSDK.Core / Azure.Core / System.ClientModel | [#7198](https://github.com/duplicati/duplicati/pull/7198) |

---

## 残る1件：System.IO.Hashing（7.0.0 / 10.0.3）── **意図的**

**Minio 6.0.0 固定が原因。** `Minio 6.0.0` が `System.IO.Hashing 7.0.0` を要求し、
`Duplicati.Library.Backend.S3` 系3プロジェクトだけが 7.0.0 に留まる。

理由は [MINIO-VERSION-PIN.md](MINIO-VERSION-PIN.md)。**意図的に払っているコスト**であり、
直すべき欠陥ではない。**触らないこと。**

---

## 通用した論法（次に同じ作業をするとき）

**「最新版に上げる」ではなく「出荷アプリが既に解決している版に合わせる」** と、
議論の余地がほぼ無くなる。#7198 がその形。

`Duplicati.GUI.TrayIcon` と `Duplicati.Server` の `project.assets.json` を読むと、
アプリはとうに揃った側の版を解決している。ずれているのはライブラリ単体でコンパイルしたときだけ。
つまり**そのライブラリは自分が実行されない版に対してコンパイルされている**。

- 版を選んでいるのではなく、**既に動いている値を書き写している**だけなので、出荷物は何も動かない
- 「変更前後で TrayIcon / Server の解決版が同一」を示せば、それが無害の証拠になる
- 最新版まで上げるのは**別の PR**。出荷版そのものを動かす変更で、検証範囲が一気に広がる

#7176（SharpAESCrypt）も同じ論法。

---

## 測定方法（再現手順）

推移的依存まで含めた解決後のバージョンを見る必要があるため、`obj/project.assets.json` を読む。

```bash
mise exec dotnet -- dotnet restore Duplicati.slnx     # 必ず先に restore する
mise exec python  -- python -u triage/pkgdrift.py     # 分裂しているパッケージ一覧
mise exec python  -- python -u triage/pkgdrift-root.py Azure.Core 1.54.0   # 誰が要求しているか
```

- **restore を省くと古い assets を読んで誤った結論が出る。**
- `PackageReference` の直接参照だけを見るのも**不十分** — 分裂の大半は推移的依存で起きる。
- どちらのスクリプトも `__file__` からリポジトリ位置を求める。`sl cat` でパイプして流すときは
  先頭に `__file__ = r"...\triage\pkgdrift.py"` を足すこと。また `PYTHONIOENCODING=utf-8` が無いと
  cp932 で落ちる。

NuGet 上の最新版と依存関係は API から直接読める（`gh` も認証も不要）。

```bash
curl -s https://api.nuget.org/v3-flatcontainer/azure.core/index.json
curl -s https://api.nuget.org/v3-flatcontainer/azure.core/1.55.0/azure.core.nuspec
```

---

## 見つけたが直していないこと（#7198 の本文で報告済み）

メンテナの判断が要るため、事実として挙げるに留めたもの。

| 内容 | 詳細 |
|---|---|
| `AWSSDK.SecretsManager.Caching 2.0.0` が**未使用** | `SecretsManagerCache` も `Amazon.SecretsManager.Extensions.Caching` 名前空間も、ツリー内の `.cs` に**1件も出現しない**。実質 `AWSSDK.SecretsManager` を引き込むためだけに存在している。最新は 3.0.0（メジャー更新） |
| `AWSSDK.SecretsManager` が 4.0.100.3（最新 4.0.100.10） | 上げると `AWSSDK.Core >= 4.0.102` を要求し、**今度は SecretProvider だけが高くなる**。S3 の明示参照も動かす必要があり、整合ではなくパッケージ更新の作業になる |
| `Azure.Core` が 1.55.0（最新 1.62.0） | 同上。`Azure.Identity` も `Azure.Security.KeyVault.Secrets` も**既に最新**なので、上げるには明示参照を AzureBlob 側にも足すことになる |

---

## 対象外：ソリューション外のテストプロジェクト

`Duplicati.slnx` に**含まれない**2プロジェクトにも古いテスト用ツールが残っているが、出荷物に影響しない。

| プロジェクト | パッケージ | 版 | CI |
|---|---|---|---|
| `Duplicati/Duplicati.Browser.Test` | nunit / NUnit3TestAdapter / Microsoft.NET.Test.Sdk | 3.13.1 / 3.17.0 / 16.5.0 | **どのワークフローからも参照されていない** |
| `LiveTests/Duplicati.Backend.Tests` | Microsoft.NET.Test.Sdk | 17.3.2 | `backendtests.yml` で稼働中 |

`Browser.Test` は SpecFlow/Selenium 構成。NUnit 3→4 は破壊的変更を含むため、単なる版上げでは済まない。
**着手するなら独立した判断が要る。**

`ReleaseBuilder` も slnx 外だが、`AWSSDK.Core 4.0.100.5` を明示していて出荷側と一致している。
