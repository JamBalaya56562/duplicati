# ngax の AngularJS 1.4.3 をどこまで上げられるか（調査だけ。実装もダウンロードもしていない）

調べた時点: master `71981c36`。対象は `Duplicati/Server/webroot/ngax`。

## 上げられる版
- 上限は **1.8.3**。AngularJS の最後の版で、サポートは 2022 年 1 月に終わっている（ドキュメント根拠: npm の `angular@1.8.3` に deprecated の表示、docs.angularjs.org にサポート終了の告知）
- 1.8.3 にも、直っていない既知の脆弱性が残っている（推測: 記憶による。ReDoS や srcset 系）。上げれば 1.4.3 より古い問題は減るが、ゼロにはならない。ゼロにするには ngax をやめるか、有償の延長サポート版を使うしかない

## 使っているモジュール
- `backupApp` が依存しているもの（検証済み: `scripts/app.js`）: `ngRoute`、`ngCookies`、`ngSanitize`、`gettext`、`ngclipboard`、`dotjem.angular.tree`（同梱の dxTree.js、82 行）
- `index.html` は、`angular-loader`・`animate`・`resource`・`touch` も読んでいる。しかしどのモジュールも依存していない（検証済み: grep）。上げるときは消すのがよい（読むのをやめるだけ。動きは変わらないはず。**推測**）
- `scripts/angular/` には、読み込みさえされていない `aria`・`messages`・`message-format` もある

## 壊れうる所（migration guide を根拠に、ngax の該当箇所を grep で数えた）
| 変更 | 版 | ngax への影響 | 根拠 |
|---|---|---|---|
| `$location` の hashPrefix の既定が `'!'` に | 1.6 | `href="#/…"` が 9 か所。そのままだと URL が `#!/` になり、リンクやブックマークが壊れる。`$locationProvider.hashPrefix('')` を 1 行足せば今のままの URL になる | ドキュメント根拠 + grep |
| `$http.jsonp` で `JSON_CALLBACK` が使えなくなり、URL を trusted resource として登録する必要がある | 1.6 | `EditUriBuiltins.js:262` の OAuth の完了待ち（`servicelink + 'fetch?callback=JSON_CALLBACK'`）。直さないと OAuth を使う宛先（Google Drive、OneDrive など）で AuthID が取れなくなる。`jsonpCallbackParam: 'callback'` と `$sceDelegateProvider` での許可が要る | ドキュメント根拠 + grep |
| 拒否の処理がない promise を `$exceptionHandler` に送る（"Possibly unhandled rejection"） | 1.6 | `.then(` が 120 か所。そのうち、拒否の処理を渡していない形が多い（成功の関数だけのものが 78 か所程度。数は正規表現での概数）。HTTP の失敗のたびにコンソールにエラーが出るおそれがある。Playwright の「コンソールのエラーなし」のテストが落ちる。`$qProvider.errorOnUnhandledRejections(false)` で今の動きのままにできる | ドキュメント根拠 + grep。実際に何件出るかは**未検証** |
| `$http` の `.success()`/`.error()` の削除 | 1.6 | 0 件 | grep |
| `preAssignBindingsEnabled` の削除 | 1.6/1.7 | `bindToController`・`controllerAs` は 0 件。影響はないはず | grep + 推測 |
| `$cookieStore` の削除 | 1.7 | 0 件（`$cookies.get/put` だけ。1.8 にもある） | grep |
| ngTouch の `ngClick` の削除 | 1.7 | ngTouch は依存されていない | grep |
| `$sanitize` で SVG が既定で外される | 1.5 | `ng-bind-html` は 1 か所（restorefilepicker の検索のハイライト）。中身は文字列と `<span>`。影響はないはず | grep + 推測 |
| jqLite が `<div />` のような自己終了タグを兄弟の要素として扱わなくなる | 1.8 | JS の中で `angular.element(` を呼んでいる所は 0 件。テンプレートには自己終了タグが 4 か所あるが、これはブラウザーが解釈するので関係ないはず | ドキュメント根拠 + grep。テンプレートの所は**推測** |
| 同梱のプラグイン | — | angular-gettext（版の表記なし）、ngclipboard 1.1.1、dxTree（自前）。1.8 で動くかは**未検証**。angular-gettext は 1.8 に対応した版がある（推測） | — |

jQuery の削除（`chore/ngax-remove-jquery`）がマージされたあとは、jqLite だけで動くことになる。上げる作業はその後にするのが安全（同時にやると、壊れたときにどちらの原因か分からない）。

## テストの計画
1. 既存の Playwright: `ngaxAuthRefresh`・`ngaxWithoutJquery`・`ngaxSourcePicker`、未マージの `ngaxPages` を、上げる前と後で流す
2. 足すテスト:
   - `#/` の URL（ホーム・`#/log`・`#/about`・`#/add`）が、上げた後もそのまま開けること（hashPrefix）
   - OAuth の宛先で「AuthID」を押したとき、`fetch?callback=…` を Playwright の route で受けて `{"authid":"x"}` を返し、欄に入ること（jsonp）
   - 主な画面を回って、"Possibly unhandled rejection" を含むコンソールのエラーが 0 件であること。サーバーの API をわざと 500 にした場合も含める
   - 翻訳の切り替え（gettext）、クリップボードのボタン（ngclipboard）、ソースのツリー（dxTree）の動き
3. スクリーンショットを前後で比べる（jQuery の削除のときと同じ 16 画面）

## 要るダウンロード（利用者の許可が要る。まだ何も取っていない）
| パッケージ | 取得元 | 大きさ（展開後） |
|---|---|---|
| `angular@1.8.3` | https://registry.npmjs.org/angular/-/angular-1.8.3.tgz | 2,089,792 バイト（10 ファイル） |
| `angular-route@1.8.3` | https://registry.npmjs.org/angular-route/-/angular-route-1.8.3.tgz | 71,369 バイト（8 ファイル） |
| `angular-cookies@1.8.3` | https://registry.npmjs.org/angular-cookies/-/angular-cookies-1.8.3.tgz | 17,077 バイト（8 ファイル） |
| `angular-sanitize@1.8.3` | https://registry.npmjs.org/angular-sanitize/-/angular-sanitize-1.8.3.tgz | 56,281 バイト（8 ファイル） |

大きさは npm の registry の情報から（ドキュメント根拠）。tgz そのものの大きさは見ていない。angular-gettext を上げる必要があるかは、1.8.3 で試してから決める（その場合は `angular-gettext` を 1 つ追加でダウンロードする）。
使わないモジュール（loader・animate・resource・touch・aria・messages・message-format）は上げずに消す案。`thirdparty/AngularJS` の版の表記も更新が要る。
