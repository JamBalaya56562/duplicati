# 閉じてよさそうな Issue へのコメント（2026-10-03、利用者の承認を得て同日投稿）

`IMPLEMENTATION-CANDIDATES-2026-10-03.md` の「閉じてよさそうなもの」6 件。サブエージェントの見立てを 1 件ずつ確かめ直した（Issue とコメント、今のコード、どのリリースに入っているかを `git tag --contains` で）。**見立てと違った点**: #5398 の 550 の変換は `5712264e` ではなく `a4482a4d` で入った（`5712264e` は別の変更）。#6744 の修正 `e7b998f9` は 2.3.0.4 stable には**入っておらず**、2.3.1.0 beta と 2.4.0.0 stable から。どのコメントも根拠はコードと履歴で、動かして確かめたものではない（#6535 と #7298 は Issue・フォーラムのやりとりが根拠）。

## #5398 Backup fails because file can't be found（FTP の 550）（[投稿](https://github.com/duplicati/duplicati/issues/5398#issuecomment-5970133212)）

根拠: 2.0.8.1 の `AlternativeFTPBackend.Delete` は `DeleteFile` の例外をそのまま投げていた（タグで確認、550 の変換は 578 行目の一覧だけ）。今の `FTPBackend.DeleteAsync` は `TranslateException` で 550/450 を `FileMissingException` にし（`FTPBackend.cs:771-775`、`a4482a4d`、2.1.0.4 stable から）、`BackendManager.DeleteOperation` は `FileMissingException` なら一覧を取り直して消えていれば成功とする（`d99f74ed`、2.2.0.0 stable から）。

> In the current code this no longer stops the backup. In 2.0.8.1 the "FTP (Alternative)" backend passed the 550 from a delete straight up. Since [a4482a4d](https://github.com/duplicati/duplicati/commit/a4482a4d03d5f1324d855b4985959138c8defff9) (2.1.0.4 stable), the FTP backend reports a 550 or 450 on a delete as a missing file, and since [d99f74ed](https://github.com/duplicati/duplicati/commit/d99f74ed945ae9cac259c042807092df04fc319d) (2.2.0.0 stable), a delete that reports a missing file lists the destination and counts as done when the file is gone. The file name one second later is from a dlist upload that failed and was retried, as ts678 explained. I think this can be closed; please reopen if it happens on 2.2.0.0 or later.

## #5113 sometimes hangs when FTP destination refuses login（[投稿](https://github.com/duplicati/duplicati/issues/5113#issuecomment-5970133589)）

根拠: 止まったのは古い「FTP」バックエンド（本文に「FTP (Alternative) wouldn't break with this test ... then dlist gave an error」）。古いバックエンドは `a4482a4d`（2.1.0.4 stable から）で消え、今の「FTP」は FluentFTP（元の Alternative と同じ）を使う（`FTPBackend.cs` の `using FluentFTP`、`AlternativeFTP` のフォルダはない）。

> The backend this was reported against, the original "FTP" one, was removed in [a4482a4d](https://github.com/duplicati/duplicati/commit/a4482a4d03d5f1324d855b4985959138c8defff9) (2.1.0.4 stable). "FTP" now uses the FluentFTP code of "FTP (Alternative)", which in your test gave an error on the dlist instead of hanging. I think this can be closed; please reopen if the hang shows up on 2.1.0.4 or later.

## #5087 Ctrl-C on Windows doesn't interrupt, though it gives that appearance（[投稿](https://github.com/duplicati/duplicati/issues/5087#issuecomment-5970133908)）

根拠: 子プロセスで起動する仕組み（`RunFromMostRecent`）は `115e8878`（2.1.0.4 stable から）で消え、今のコードに 1 か所もない。kenkendk の「直ったのでは」に ts678 が「技術的にはこの Issue はなくなった」と答え、トレイの Ctrl-C の件は本人が「別の問題」としている。

> As discussed above, the launcher that ran the work in a child process was removed with the updater rework in [115e8878](https://github.com/duplicati/duplicati/commit/115e8878029e9f0bba364cc49fd764a716d387e8) (2.1.0.4 stable), and the current code has no `RunFromMostRecent` any more, so no hidden child is left running after Ctrl-C. The tray icon behaviour after Ctrl-C is a separate case, as you said. I think this can be closed.

## #6744 RESTORE causes constant writes to the TEMP directory（[投稿](https://github.com/duplicati/duplicati/issues/6744#issuecomment-5970134390)）

根拠: 2.2.0.3 の既定は「volume のサイズ × 100」（タグで確認、100MB なら 10GB）。`e7b998f9`（#6785、2.3.1.0 beta・2.4.0.0 stable から）で既定は上限なし、一時フォルダのディスクの空きが `--restore-volume-cache-min-free`（既定 1GB）を切ったときだけ追い出し、そのとき `CachePressure` の警告（`Options.cs:2042-2060`、`VolumeManager.cs:288`）。キャッシュの場所は `options.TempDir`（`VolumeManager.cs:122`）。空きが足りなければ今も追い出すので「閉じてよい」ではなく「2.4.0.0 で試してほしい」。

> In 2.2.0.3 the restore volume cache was limited to 100 times the remote volume size by default (10 GB with 100 MB volumes), so a restore that needs more volumes than that kept evicting them and downloading them again. Since [e7b998f9](https://github.com/duplicati/duplicati/commit/e7b998f909988b34392b2d6f0cc78fecbb7d07ee) (#6785, in 2.3.1.0 beta and 2.4.0.0 stable) the cache has no limit by default, and only evicts when the disk of the temp folder gets below `--restore-volume-cache-min-free` (1 GB by default), with a "CachePressure" warning when it does. Could you try the restore on 2.4.0.0? If the disk of the temp folder is small, `--tempdir` can move it to a larger one.

## #6535 Backup as User - SQLiteException: unable to open database file（[投稿](https://github.com/duplicati/duplicati/issues/6535#issuecomment-5970134929)）

根拠: フォーラム（[21367](https://forum.duplicati.com/t/backup-as-user-sqliteexception-unable-to-open-database-file/21367)）で報告者（tag）が 10-23 に「Windows の更新にも問題があったので Windows 11 を入れ直し、それ以来 Duplicati に問題はない」。その前に「自分の誤りなら GH の Issue は閉じる」とも書いている。Duplicati 側の原因は見つかっていない。

> Following up from the forum thread: you reinstalled Windows 11, which was also having trouble with its updates, and have had no problems with Duplicati since. As nothing pointed at Duplicati, I think this can be closed.

## #7298 [Bug fix/solution] RAM usage keeps increasing until 100% on Unraid（[投稿](https://github.com/duplicati/duplicati/issues/7298#issuecomment-5970135504)）

根拠: 報告者自身が「#7289 に返信できないので解決策をここに書く」として立てた。`/run/duplicati-temp` はこのリポジトリにない（grep で 0 件、linuxserver.io のイメージの設定）。kenkendk が `--tempdir` と `--asynchronous-upload-folder` を説明済み。lambolighting は「対応づけても RAM が増え続ける」としているので、その件は #7289 で追う。

> Thanks for writing this up. The path `/run/duplicati-temp` is set by the linuxserver.io image, not by Duplicati, and @kenkendk explained above how `--tempdir` and `--asynchronous-upload-folder` move the temporary files to disk. As @lambolighting still sees the RAM grow with the folder mapped, that part is tracked in #7289. I think this one can be closed in favour of #7289.
