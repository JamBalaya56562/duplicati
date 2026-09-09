# macOS の dmg テストの赤（#8047、11-28）

`DmgInstallerSwapsTheBundleAndRollsBack` が `update.dmg ... being used by another process` で落ちる（`WaitUntilReadable` が 60 秒待って諦める）。PR の差分とは無関係。

## プローブの結果（検証済み、fork の macos-latest、macOS 26.7.2、[run 46123355932](https://github.com/JamBalaya56562/duplicati/actions/runs/46123355932)）
- `hdiutil create` を 200 回ずつ（負荷なし・CPU と IO の負荷あり）。負荷なしの 169 回目だけ、作った直後から共有の `flock` が `Resource temporarily unavailable` で取れず、90 秒たっても取れなかった。
- そのときの `lsof`: `diskimages-helper`（PID 21511、`-post-exec 4`、`hdiutil` の後ろの helper）が `update.dmg` を `5u`（読み書き）で開いたままだった。90 秒後も同じ。
- Spotlight・XProtect・syspolicyd は開いていなかった。負荷ありの 200 回はロック 0 件、dmg テストの 40 回ループ（80 個）と CI と同じ全体テスト 2 回（各 2 個）はすべて「すぐ読めた」。つまり頻度は低く（1/400）、負荷との関係は見えない。
- ジョブの「failure」は Report の `grep` が 0 件で exit 1 になっただけで、テストは全部通っている。

## 直した（[#8058](https://github.com/duplicati/duplicati/pull/8058)、`fix/dmg-test-copy-image`）
- テストは別名で作った dmg を `/bin/cp` で写して使う。写しは新しいファイルなのでロックが付かず、`cp` は読むときにロックを取らない。`WaitUntilReadable` は消した。
- 確かめた結果（[run 46132207537](https://github.com/JamBalaya56562/duplicati/actions/runs/46132207537)）: perl で排他ロックした dmg は共有ロックが取れず、写しは取れた。写しは `cmp` で同じ、`hdiutil verify` が VALID、マウントして印のファイルも合う。6 ジョブ × 300 回の作成で自然に残ったロックは 1 件（loop 5 の 19 回目）、その写しも同じく問題なし。`UpdateInstallTests` を CPU 負荷の下で 40 回、失敗 0。
- fork の `probe/dmg-lock` は残してある（消すのは利用者の指示があってから）。
