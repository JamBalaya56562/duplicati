# open の Issue の見直し（2026-11-28）

11-25 の再調査で「open のまま」とした Issue のうち、今も open の 133 件を、canary 2.4.1.104（upstream master `258d71ce` まで、ngclient 0.0.253）と stable 2.4.1.1（ngclient 0.0.251）で見直した。subagent 4 体が本文・全コメント・コードを読み、close の提案は私がタグの中身で確かめ直した。判断には必ず理由を書く（利用者の指示 11-28）。

## close を提案したもの（11-28 に投稿、利用者の承認）

直した PR が回帰テストも足しているので、新しいテストの PR では閉じず、コメントにした（利用者の方針 11-28: 回帰テストが無いものだけテストで閉じる）。
- [#4711](https://github.com/duplicati/duplicati/issues/4711#issuecomment-7240435894)（#8045、`S3LeadingSlashFolderTests`）
- [#2207](https://github.com/duplicati/duplicati/issues/2207#issuecomment-7240436779)（ngclient の Compare versions、`compare-versions.component.spec.ts` と e2e）
- [#2234](https://github.com/duplicati/duplicati/issues/2234#issuecomment-7240437647)（#6237・#7234、`EmptyMetadataTests`・`ZeroLengthMetadataTests`）
- [#2764](https://github.com/duplicati/duplicati/issues/2764#issuecomment-7240438482)（ngclient #755、`last-run.pipe.spec.ts` と e2e の `home-backup-state.spec.ts`）

## テストで閉じるもの（ブランチを作った、PR 未）

- #3246（ログの書き出し）: Download の 4 ページのうちリモートログだけテストが無かった。ngclient の `test/remote-log-download`（6b8ce335、Fixes duplicati/duplicati#3246、ngclient triage の NGT-129）。
- #2556（WebDAV の角括弧のフォルダー）: `test/webdav-bracket-folder`（fee0fb6b、Closes #2556）。今のコードで直っていた。

## 一部だけ満たすので、利用者の判断（今は出さない）

- #191（シャットダウン前にバックアップ）: canary 104 の「すべて開始し、キューが空になったらシャットダウン」（#7883）。OS のシャットダウンに割り込む形ではない。
- #2769（選択肢のひな形）: canary 104 の「Configure email reports」ダイアログ（ngclient #843）はメールだけで、汎用のひな形は無い。

## 今も残る不具合・直す候補

- #3041（進捗の件数の桁区切り）: ngclient は区切る（d2b600734、両方）が、ngax の `StateController.js:55`・`:82` は区切らない。小さな ngax の直しの候補。
- #4101（フィンランド語の「hibernate」の訳）: `localization_webroot-fi.po:1648` と ngclient の `messages.fi.json:128` が「lepotila」のまま。翻訳は Transifex で直すもので、コードの PR ではない。
- #6621（UTF-8 でないファイル名、Linux）: kenkendk が 2026-10-27 に確認。.NET が文字列で扱うための制約で、直すにはパスの扱いを全体で変える必要がある（大きい）。#4753 も同じ原因（推測）。

## open のまま（理由）

要望で未実装（コードに無いことを grep で確認）:
#72（全バージョンのツリー表示、API はあるが UI が使っていない）・#519（スリープからの復帰）・#520（アイドル時だけ実行）・#525（友人間のバックアップ）・#611（時間帯で一時停止、`--max-backup-runtime` は一部だけ）・#616（ownCloud のプリセット）・#866（ネットワークごとの速度制限）・#996（リムーバブルディスクを促す UI）・#1032（tempdir を初回に選ばせる）・#1152（ログが分かれている）・#1417（syslog）・#1586（復元を一時名で書く）・#1673（無人の自動更新、クリックでの更新は canary 104 から）・#1724（Web UI から再起動）・#1739（サービスのユーザー）・#1740（汎用コマンドのバックエンド）・#1775・#3255（可変長ブロック）・#1845（復元のハッシュ不一致の再試行）・#1918（Yandex のプリセット）・#1922（openSUSE のパッケージ）・#1966（既存ファイルを無視する復元）・#1969（詳細オプションの別ページ）・#1970（型付きの選択肢）・#2012（鍵ファイル）・#3081（バックアップをフォルダーとしてマウント、FUSE・WinFsp の実装なし。subagent の報告から抜けていたので私が読んだ）・#2030（容量で古い版を消す）・#2072（AuthID のフォームでの送信）・#2149（他人の共有フォルダー、Google 側の仕様）・#2189（MD5・SHA1 の出力）・#2238（グループ化、順次実行は canary 104 の run-after で一部）・#2267（macOS の /Volumes）・#2317（アーカイブの中身で重複排除）・#2346（dlist に結果の要約）・#2365（ログを別 DB に）・#2466（推奨値の提示）・#2467（拡張子ごとの集計）・#2583（スパースファイル）・#2633（ローテーションするドライブ、スクリプトの引数は `--run-script-with-arguments` で可）・#2653（トレイからの二重タブ、kenkendk が確実な検出が無いと 2017 年）・#2667（モバイル）・#2669（ソースに無いファイルだけ表示）・#2689（snap、代わりに AppImage）・#2816（Jojo-1000 の試作は 2024-01 に延期）・#2885（取り込みで DBPath を捨てる）・#2901（権限レベル）・#2921（時間帯の帯域制限）・#2991（鍵ラップでのパスワード変更）・#3040（バックアップ中にログを見る、今は分かりやすいロックのエラーになるだけ）・#3150（言語と日付の書式の分離、en-GB で dd/mm は可）・#3179（全部停止）・#3211（ログの一元化）・#3362（Prometheus、kenkendk は 2024-05 に組み込めると）・#3450（レポートの JSON の形式）・#3478（メモリ基準の並列数）・#3533（GPG の DB 修復でパスフレーズを聞く）・#3539（locking_mode=EXCLUSIVE、設計判断）・#3551（バックアップ前の OS 通知）・#3583（ADLS Gen2）・#3671（LVM 外の /boot を外した部分スナップショット）・#3688（mail.ru）・#3689（xz、tar+gzip・tar+zstd はある）・#3710・#5942（キューの並べ替え）・#3819（帯域に応じた自動設定）・#3862（ZFS）・#3949（flatpak）・#4032（MySQL のソース）・#4199（S3 の WebIdentity）・#4389（Linq2Db 等の導入）・#4494（WD MyCloud のパッケージ）・#4622（TOTP）・#4710（Google Drive API v3）・#4734（DSCP）・#5092（ジョブ削除で OAuth を失効、共有と衝突）・#5166（Nullable、112 中 57）・#5205（use-ssl の廃止）・#5242（dindex から直接復元、#7985 は脇の部分だけ）・#5421（System.CommandLine）・#5440（RTL）・#5457（画面の比較テスト）・#5553（ネットワーク・待機の検出）・#5590（WSL の dotfile を隠しとして扱う）・#5594（Passkey）・#5599（インストールスクリプト）・#5649（FreeBSD）・#5662（Agent のインストールスクリプト、register は済み）・#5663（パッケージ ID の osx→macos）・#5675（macOS の Agent の権限昇格）・#5759（トークンの family）・#5912（API での再起動）・#5915（LIST をメモリにまとめる）・#5934（gitignore 風のファイル）・#5992（Docker で自分を除く）・#6058（Oracle、S3 互換で可能かは推測）・#6182（ディストリのリポジトリ）・#6304（ドライブ接続でバックアップ、kenkendk が可能と 2025-06）・#6305（dindex の生成を backend manager へ）・#6365（Terabox）・#6376（壊れたリモートファイルを消す）・#7627（N 時間成功していない警告、kenkendk は Console を案内したが却下はしていない）。

外部の都合・設計:
#1996（DB と一時フォルダーを置くディスクの勧め、ドキュメント側。the-local-database のページに無い）・#5605（OneDrive の WebDAV は認証が非標準で、どのクライアントでも失敗）・#6557（Docker Hub の署名方式の文書待ち、kenkendk が 2025-10-31 に保留）・#2895（修正先の usage-reporter は archived、閉じるかはメンテナーの判断）・#4125（性能計測の記録用）。

報告者の情報・確認待ち（再現できず、原因と修正の関係は推測でしかない）:
#1442・#2049（2015〜2016 年のハング）・#2272（OneDrive の速度、Graph に置き換わった）・#2468（一覧のクエリの形は残る、速度は未計測）・#3683（Jottacloud のハング）・#4169（ngax の表示、2020 年）・#4216（Google Drive の待ち、DB を外して直ったという回答のみ）・#4832（Storj の初回の失敗）・#4845（S3 の SigV4 の速度）・#4908（dindex を消して解決、原因不明。stale の候補）・#5670（Server 2025 の Hyper-V、mnaiman の質問に返事なし）・#5944（Storj、報告者の再確認なし）・#6051（kenkendk がバグ報告の DB を頼んで返事なし）・#7664（kenkendk の質問に返事待ち）。

PR で閉じるもの: #6835（#8059）。
