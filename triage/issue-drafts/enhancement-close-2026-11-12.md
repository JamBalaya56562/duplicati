# 実装済みの enhancement を閉じる依頼の下書き（2026-11-12、188、5 本とも投稿済み）

## #1814 (Error displaying log for backup that has never been run)

This no longer happens. When the database of a backup does not exist yet, or has no `LogData` table, the log endpoint now returns an empty list instead of an error. I checked it with the current master: a backup created through the API and never run gives `200` and `[]` for `/api/v1/backup/{id}/log`. The check for a missing database is in 2.4.0.0 and later.

I think this can be closed.

## #2846 (Log files do not contain timestamps)

The log file now has a timestamp on each line. With the current master, `--log-file` gives lines like this:

```
2026-11-12 18:10:49 +09 - [Information-Duplicati.Library.Main.Controller-StartingOperation]: The operation Backup has started
```

Logging to syslog is asked for in #1417, so I think this one can be closed.

## #1266 (Record name/properties of backup config in dlist file)

This is in 2.4.0.0 and later. A backup run from the server stores its configuration as `task-setup.json` in the dlist file, controlled by `--store-task-config`. The default (`Auto`) does this for encrypted backups, without the passwords.

I checked it with the current master: after one run of an encrypted backup, `task-setup.json` was in the dlist, and after restoring the control files it had the name of the backup and the source path, but not the passphrase.

I think this can be closed.

## #1273 (Enhancement of verify options)

The `restore-test` command, in canary 2.4.0.102 and later, covers the first point. It restores files from the remote data only and checks each file against the hash and size in the backup. With `--restore-test-recreate-database=true` it builds a temporary database from the destination first, so it does not use the local database.

I checked it with the current master: after deleting the local database, `restore-test --restore-test-recreate-database=true --restore-test-mode=Full` restored and verified all 3 files, and reported `Database: recreated from the remote destination`. `--restore-test-sample-count` or `--restore-test-sample-percent` test only a part.

It does not keep the restored files (the second point). A normal restore with `--no-local-db` restores from the remote data without a local database. If that covers it, I think this can be closed.

## #2903 (Exclude "messages" section from email)

Since 2.4.0.0, paths are removed from the report by default: they are shown as `-redacted-` unless `--allow-paths-in-log-messages` is set. So a file or folder name from a warning no longer goes into the email.

If you want a shorter email, `--send-mail-body` can be set to your own text. The section is only included where `%RESULT%` is used, and values such as `%PARSEDRESULT%` and `%OPERATIONNAME%` can be used instead.

I think this covers the request. Should it be closed?
