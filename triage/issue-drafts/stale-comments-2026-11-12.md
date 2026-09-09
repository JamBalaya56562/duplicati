# 未投稿だったコメント（2026-11-12 に全部投稿、183）

## #7783 (Sync copy mode skips a remote source)

Thanks for testing this on the Pi. #7785 takes the same route: for a remote source it takes the root from the provider's `EnumerateAsync`, so `GetEntryAsync` of the backend is not used. It also creates the source folders on the destination when there are several sources, and the warning no longer shows the credentials of the source URL.

## #6683 (WebDAV: files missing from the remote storage, Linux)

This looks like #6748, which was fixed in #7464 and is in 2.4.1.0 (stable). On Linux and macOS, Duplicati read a WebDAV href that is only a path (such as `/dav/folder/file`) as a local file path. When the name had escaped characters, it no longer matched the name of the uploaded file, so the file was reported as missing. 2.2.0.1 was the first stable release with the new WebDAV listing, which matches when this started.

I am not sure it is the same for you, because it depends on the folder and file names, and I don't know yours. Could you try 2.4.1.0 and tell us if the warning is gone?

## #5156 (Incorrect marking in the Source Data tab)

I could not reproduce this on the current master, in the old UI with a backup of `%MY_DOCUMENTS%\B-NEXT\`. The partly selected mark on My Documents showed after a normal reload, a hard reload, right after a server restart, and also when I delayed the replies for `/backup/1` and `/filesystem` by 2 seconds.

In 2.0.7.1 the path separator came from the system info, with `/` as the default until it was loaded. On Windows the paths then did not match when the system info came late, which would explain "only in Chromium, only the first time". Since 9dbdbb1b2 (2.0.7.100 and later) the page waits for the separator. If you still see this on 2.4.1.0, please tell us.

## #3295 (Server stuck when the network is gone and --send-mail-to is set)

I could not reproduce this with the current master on Linux, using the command line. With no network at all (`unshare -rn`) and only `--send-mail-to`, the backup ends after 22 seconds with exit code 2 and the warning `Failed to send message: ... List of configured name servers must not be empty`. With an SMTP server that cannot be reached (`smtp://10.255.255.1:25`), it ends after 79 seconds with a `TimeoutException` warning.

The server uses the same module, but I did not try it there. If you still see this on 2.4.1.0, please tell us.

## #3057 (LocalDB database not found after the first backup)

I tried this on Windows with SQL Server 2022 Express and LocalDB 2022, and the current master.

- The name of a LocalDB instance changes each time it starts (`LOCALDB#7E52A9C7`, then `LOCALDB#A6887C4B`, then `LOCALDB#5F2F1904` after `SqlLocalDB stop` and `start`). A source such as `%MSSQL%\MyServer\LOCALDB#01F69570\MyDatabase` stops working as soon as LocalDB restarts, which matches "the first backup works, the next ones fail".
- The SQL Writer no longer reports LocalDB databases at all. Even while LocalDB was running, `%MSSQL%` listed only the SQLEXPRESS databases, so the LocalDB path was not found even the first time.

Duplicati cannot fix either of these. A LocalDB database can be backed up as its `.mdf` and `.ldf` files, with `--snapshot-policy` so that the files can be read while they are open. I think this issue can be closed.

## #3536 (Backup size much larger than the disks)

I think the size comes from sparse files. Duplicati counts a file by its size, not by the space it uses on the disk. I made a 20 GiB sparse file on ext4: the estimate showed 20 GiB, the backup took 2 minutes and the destination grew by only 1.7 MB.

Most of the time goes into the hash of the whole file, as the holes are read as zeros. Skipping the holes when reading would save only the reading (14 seconds of the 2 minutes here), so I don't think that is worth changing. Excluding the large sparse files you do not need, such as `/var/log/lastlog` or images of virtual machines, makes the estimate and the backup shorter.
