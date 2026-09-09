# ラベルなしの open Issue の仕分け 2026-10-31

利用者の指示で、ラベルなしの open 208 件を 4 つのサブエージェントで 1 件ずつ読んで仕分けた（Issue とコメント、duplicati master `d2f77cc8`、ngclient `130afe5d`）。**読んだだけで、ビルドも実行もしていない**。PRESENT のうち新しい 6 件（#5045 以外）は自分でもコードの箇所を読んで確かめた。

| 区分 | 件数 |
|---|---|
| PRESENT | 11（うち #7472・#7524・#7538 は自分のブランチか PR あり） |
| NEEDS_REPRO | 21 |
| FIXED | 39 |
| ENHANCEMENT | 65 |
| EXTERNAL | 29 |
| NO_INFO | 33 |
| QUESTION | 7 |
| DUPLICATE | 3 |

## 直す候補（PRESENT、まだ手を付けていないもの）

| # | 内容 | 箇所 | 確認 | 規模 |
|---|---|---|---|---|
| 3163 | Windows で ACL を読めないと、時刻や属性を含むメタデータ全部が空になる | `SystemIOWindows.cs:706` が無防備、`MetadataGenerator.cs:98-101` が空を返す | 自分でコード確認 | 小 |
| 5250 | USN・変更追跡の backup で、前の版の引き継ぎがファイル数の 2 乗で遅い | `LocalBackupDatabase.cs:1694` の一時テーブルに索引なし、1 行ずつ DELETE | 自分でコード確認 | 小 |
| 3987 | 保持ポリシーが間隔より数秒短い版を消す | `DeleteHandler.cs:393` に許容幅なし（keep-time にはある） | 自分でコード確認 | 小 |
| 5055 | 全体の設定に all-versions があると、restore の一覧に別の版のファイルが出て、選んでも復元されない | `ListFilesHandler.cs:55,64` | 自分でコード確認 | 小 |
| 4175 | usn-policy=required でも USN の失敗が全体の走査になる（help と食い違い） | `BackupHandler.cs:115-119` | 自分でコード確認 | 小、初回の扱いは判断 |
| 3018 | 旧 UI の編集画面を保存すると、読み込み時の古いメタデータで最後の実行の情報が戻る | ngax `EditBackupController.js:206-207,503` | サブエージェントのみ | 小 |
| 5045 | 起動時に溜まった実行待ちのジョブが、スケジュールを消しても走る | `Scheduler.cs:417`、キューから消す手段なし | サブエージェントのみ | 中 |
| 4507 | recreate のあと、残った dindex が存在しない dblock を指し続ける（#4586 は重複） | `RecreateDatabaseHandler.cs:494-504`、`FilelistProcessor.cs:416-418` | 10-30 の probe で確認、その時は見送り | 小 |

ついでの発見: `s3-client=minio` で S3 のストレージクラスのオプションが使われない（`S3MinioClient.cs:47`）。

## 要再現（手元で試せるもの）

- part00: #2660（WebDAV の digest 認証で PUT の再送）・#3057（MSSQL LocalDB）・#3231（復元中に別のマシンが backup）・#3271（壊れた相対リンクだけの復元）・#3295（ネットワークなしのメール報告）
- part01: #3859（XMPP、Prosody）・#3959（SFTP の IPv6）・#4044（RecoveryTool の開きすぎ）・#4155（SFTP の切断）・#4675（SFTP の容量不足）・#4711（S3 の先頭の /、10-30 に取り下げ済み）・#4737・#4831（FTPS の TLS セッションの再利用）
- part02: #5082（FTP の 226 応答）・#5156（旧 UI のソースの選択の表示）
- part03: #6597・#6626・#6639（FTPS の Status is Failed）・#6683・#6840・#7476（自分の `fix/service-commands-without-preload` あり）

## 各サブエージェントの表


### part00

# Triage of part00.tsv (50 issues), master d2f77cc8

| number | title (short) | bucket | evidence | repro / size |
|---|---|---|---|---|
| 1727 | UnrecognizedReparsePointException (dedup files) | FIXED | AlphaFS removed in 7c9f964ee (#5211). `SystemIOWindows.GetSymlinkTarget` (Common/IO/SystemIOWindows.cs:533-572) uses `FileInfo.LinkTarget` (null for non-link reparse points, per the .NET docs) and the WSL fallback returns null unless the tag is LX_SYMLINK, so dedup/cloud reparse files are read as regular files. Source: docs, not run here | - |
| 1745 | Heavy disk I/O, LastModified temp table | NO_INFO | 2016 performance report. The `CREATE TEMPORARY TABLE "LastModified-..."` query no longer exists in Library/Main (grep finds nothing), and no recent data | - |
| 1845 | Retry restore of files that failed hash | ENHANCEMENT | Asks for automatic retry and a full remote integrity test | - |
| 2072 | OAuth AuthID fallback to form data | ENHANCEMENT | Feature request for proxies that strip the `X-AuthID` header | - |
| 2229 | Windows 10 backup very slow | NO_INFO | 2016 performance report (SQLite block inserts with a 100 KB blocksize). The default blocksize is now 1 MB (Main/Options.cs:57). No current data | - |
| 2272 | Slow OneDrive upload speed | EXTERNAL | Throughput against OneDrive. Needs a Microsoft account to measure. No code lead | - |
| 2345 | Cannot access files (UAC/service) | QUESTION | The service runs as a user without access to other profiles. Answered in the comments (run as a service/SYSTEM, `--no-hosted-server`) | - |
| 2655 | VSS fails with mounted .vhd + parent drive | EXTERNAL | 0x8004232C is the VSS nested-volume limit (OS). The follow-up "in progress" error came from the old AlphaVSS code, which was rewritten (WindowsModules/VanaraVssBackup.cs:310 aborts the backup). A separate snapshot set per volume would be an enhancement | - |
| 2660 | WebDAV digest auth fails on macOS | NEEDS_REPRO | The reported List failure was in Mono `AsyncHttpRequest` buffering, which is gone (0eef7ec49). Digest now goes through `CredentialCache` (WEBDAV.cs:452-457). But PUT sends a non-seekable `StreamContent(timeoutStream)` (WEBDAV.cs:712-713), which may not be resendable on the digest 401 retry | Apache httpd + mod_dav with `AuthType Digest` in Docker, backup with `--force-digest-authentication`. Fix S if it fails |
| 2925 | Backup doesn't resume after sleep | NO_INFO | 2017 canary. ts678 could not reproduce, and there are no logs | - |
| 2947 | Repair deleted newer remote files | FIXED | Repair now refuses to run when remote files are newer than the DB (Operation/RepairHandler.cs:211-229, bae82feea, 2025-02). The rest is usage questions | - |
| 2949 | HTTP 400 on `Connection: upgrade` | FIXED | HttpServer was replaced by ASP.NET Core/Kestrel (9f7902574). JamBalaya already verified that this returns 200 | - |
| 2955 | Hang during backup to S3 | NO_INFO | 2017 version, no cause found. Backends now have list and read/write timeouts (6c7843b33, 2025-03; S3AwsClient/S3MinioClient use them) | - |
| 2968 | Hang during SSH backup | NO_INFO | 2017 version. Linked to a failing USB source disk, and the reporter could not reproduce it later. SSHv2Backend now has timeouts (6c7843b33) | - |
| 3006 | Internal server error behind a proxy on another port | FIXED | The old HttpServer put the error body in the status line. It was replaced by Kestrel (9f7902574), so the response body and status are separate | - |
| 3018 | Saving the edit page overwrites job metadata | PRESENT (ngax only) | The old UI loads `data.Backup` incl. `Metadata` (ngax EditBackupController.js:503) and sends it back on save (:206-207, put at :490). The server stores it whenever it is non-null (RestAPI/Database/Connection.cs:904-906, from BackupPutDelete.cs:86). ngclient only sends Metadata for drafts (backup.state.ts:250), and the schedule LastRun is preserved (Connection.cs:920-930) | Open the job's Edit page in ngax, run the job from another tab, save after it finishes. "Last successful run" goes back. S (drop Metadata in ngax or ignore it on PUT) |
| 3028 | FTPS upload: "DATA connection terminated without SSL shutdown" | NO_INFO | 2018 report with no comments. The FTP backend is now FluentFTP (FTP/FTPBackend.cs). No code lead | vsftpd with `ssl_enable` and `debug_ssl` in Docker could check it |
| 3037 | Corrupt backup cannot be repaired | NO_INFO | 2018: missing dblocks after a backend move. Repair, list-broken-files and purge were reworked many times since, and there is no repro | - |
| 3039 | Built-in update/install fails to restart | FIXED | In-place install was removed. The update API only has `/updates/check` (WebserverCore/Endpoints/V1/Updates.cs:31), and updates are installed from packages | - |
| 3057 | MSSQL LocalDB "cannot be found" on 2nd run | NEEDS_REPRO | The selection still keys on the VSS logical-path instance (`LOCALDB#xxxx`) stored in the source (SourceProvider/Builtin/MSSQL/MSSQLSourceProvider.cs:396-443, MSSQLUtility.cs:179-186). If LocalDB changes that ID on each start, the stored source fails | Install free SqlLocalDB + SQL VSS writer, select the DB, `sqllocaldb stop/start`, back up again. M |
| 3085 | "Found inconsistency" not fixed by repair | NO_INFO | 2018 DB states, and Recreate worked for users. Validation and recreate code changed a lot. No current repro | - |
| 3150 | Locale/ISO date format | ENHANCEMENT | Request to separate language and date format | - |
| 3159 | OD4B legacy SharePoint login failure | EXTERNAL | Legacy SharePoint CSOM backend with user/password auth. Needs an M365 account, and Microsoft retired that auth | - |
| 3163 | ACL read failure drops all metadata (Cryptomator) | PRESENT | `SystemIOWindows.GetMetadata` calls `GetAccessControl` without a guard (Common/IO/SystemIOWindows.cs:706). The exception escapes `GetMinorMetadata` (MetadataGenerator.cs:60), and the outer catch returns an empty dict (MetadataGenerator.cs:98-101), so timestamps and attributes are lost too. A 2022 comment confirms it is still seen | Mount a WinFsp/Cryptomator (free) or other ACL-less volume and back up a file; or a unit test with an ISystemIO whose GetMetadata throws. S (catch the ACL read separately) |
| 3178 | (1920) file cannot be accessed, MS Store app files | EXTERNAL | ERROR_CANT_ACCESS_FILE on Store app package files, even through VSS. An OS restriction | - |
| 3223 | Restored old local DB corrupts destination | FIXED | Stale-DB check in repair (RepairHandler.cs:224-229, bae82feea) | - |
| 3231 | Direct restore fails during a concurrent backup | NEEDS_REPRO | Direct restore builds a temp DB (RestoreHandler.cs:251-260), then verifies the remote list (RestoreHandler.cs:1106). Files uploaded meanwhile raise "remote files that are not recorded" (FilelistProcessor.cs:176-182) | Local-folder destination: start a direct restore of a large backup and run a backup to the same folder meanwhile. S (ignore extra volumes for a temp DB) |
| 3249 | LVM snapshot "Not enough free space" | EXTERNAL | The VG has no free extents for the snapshot (user's disk layout). The script reports it correctly | - |
| 3271 | Restoring only symlinks skips a relative one | NEEDS_REPRO | The restore was rewritten, and related fixes landed (dangling file-symlink restore e51f7c3d4, separators 245a8dbe5), but this case (only symlinks selected, relative dangling file link not restored) is not clearly covered | Windows (Developer Mode): folder with dir/file/relative/absolute symlinks, back up, restore only the symlinks to a new folder with both engines. S-M |
| 3286 | "One or more errors occurred" with no info | NO_INFO | The real error (DB inconsistency) was in the server log. 2018 version, and the AggregateException wrapping has changed since | - |
| 3295 | Server stuck when the email report has no network | NEEDS_REPRO | SendMail now sets a 1 min MailKit timeout (Modules/Builtin/SendMail.cs:296) and uses DnsClient for MX (:264). The hang is probably gone, but this is not verified | Hyper-V/WSL VM with the NIC disconnected, `--send-mail-to` without `--send-mail-url`, run a backup and check the queue is released |
| 3323 | "cannot commit - no transaction is active" | NO_INFO | 2018 stack (`DatabaseCommon.Dispose`) belongs to code that was replaced since. No repro | - |
| 3446 | Pinentry garbles the terminal | EXTERNAL | pinentry-curses/tty and the shared TTY (GnuPG T4198) | - |
| 3497 | OD4B "Cannot send a content-body with this verb-type" | EXTERNAL | Mono-only per the reports. The legacy SharePoint backend still uses CSOM `OpenBinaryDirect` (SharePoint/SharePointBackend.cs:571), but testing needs an OD4B account | - |
| 3509 | Stuck forever after FTPS server reboot | FIXED | FTP List and connect now run under `WithTimeout` (FTP/FTPBackend.cs:400, :669), added in 6c7843b33 | - |
| 3530 | Report full of stack traces for vanished files | FIXED | One-line known-problem warnings (1d4642acd, #6426). JamBalaya already verified this in a comment | - |
| 3533 | Recreate DB with asymmetric GPG fails | EXTERNAL | The gpg private-key passphrase cannot be entered when running as a service (no pinentry). It works from the CLI per the comments | - |
| 3535 | WebDAV TrustFailure | EXTERNAL | Mono TLS/cert store, which is no longer used (.NET) | - |
| 3548 | `--auth-password` with special characters | FIXED | JamBalaya verified on ba7565ae: SigV4 signs with the exact secret for both clients | - |
| 3570 | send-xmpp non-standard port | FIXED | The port can be given in the username. Verified by JamBalaya, and the reporter agreed | - |
| 3588 | S3 failure shown as successful | NO_INFO | The cause was IAM. A failed run now only updates `LastErrorDate` (RestAPI/Runner.cs:1281, 1346-1348). No repro | - |
| 3590 | Google Drive UNIQUE Remotevolume.Name,State | NO_INFO | 2019 DB state. Schema 16 added a Name-only unique index. Needs Google Drive to try | - |
| 3594 | Locked files cause corrupt backup | NO_INFO | ts678 could not reproduce with ordinary locked files. Later comments are unrelated (server.key ACL) | - |
| 3627 | Killed during initial backup, cannot recreate | NO_INFO | ts678 found the kill/restart scenario now resumes fine. No current repro | - |
| 3635 | "File in use by another process" (DB) | NO_INFO | Probably the DB inside the backup sources or a concurrent instance. No log and no repro | - |
| 3683 | Backup hangs (Jottacloud) | NO_INFO | 2019. The WhenAll hang theory was not confirmed. Jottacloud now uses timeouts (6c7843b33) | - |
| 3716 | gpg "No pinentry" | EXTERNAL | gpg-agent/pinentry configuration on Windows (Kleopatra) | - |
| 3738 | Remove Utility.AsyncHttpRequest | FIXED | Removed in 0eef7ec49 (#6291). JamBalaya confirmed it in a comment | - |
| 3752 | Hyper-V / MSSQL "not installed" messages | QUESTION | They are Information-level probes (Snapshots/Windows/HyperVUtility.cs:202, MSSQLUtility.cs:146), triggered by the source picker, not errors | - |
| 3753 | UNIQUE FilesetEntry with Firefox `lock` symlink | FIXED | Fixed in #4256/2.0.5.110. JamBalaya could not reproduce it on 31bf7aa (comment) | - |

Count: 50 rows (input has 50 issues).

### part01

# Unlabeled issues, part 01 (51 issues), master d2f77cc8

Evidence kinds: "code" = read in master (推測 unless stated), "verified" = observed earlier in this session's triage notes (`alltriage.txt`), "comment" = an existing evidenced comment on the issue.

| number | title (short) | bucket | evidence | repro / size |
|---|---|---|---|---|
| 3806 | Update activation fails without manual restart | FIXED | The in-place "Activate" update path was removed by the new updater in 115e88780 (2024-03-15); no `ActivateUpdate`/activate code is left in `Duplicati/Library/AutoUpdater` or the server. Updates now go through OS installers. | - |
| 3819 | Auto-set volume size / http timeout from bandwidth | ENHANCEMENT | Feature proposal. | - |
| 3859 | XMPP fails in Docker (Iphlpapi.dll) | NEEDS_REPRO | agsXmpp/Sharp.Xmpp were replaced by Artalk.Xmpp 1.0.5 (#5213, `Modules.Builtin.csproj:14`, `SendJabberMessage.cs:255`), and Mono is gone. The DllNotFound came from Mono, but no one has tested the new library on Linux. | Run a Prosody/ejabberd container and send a report from the WSL CLI with `--send-xmpp-to`. S if it still fails |
| 3959 | SFTP to an IPv6 host fails / server crash | NEEDS_REPRO | `SSHv2.ParseSshUrl` now uses System.Uri, and `ssh://[fe80::1]/p` parses to host `[fe80::1]` (`SSHv2Backend.cs:100-120`, `SshUrlTests.cs`). Brackets are kept in `m_server` (`:155`), which is then handed to SSH.NET. Untested whether SSH.NET connects with the brackets. | In WSL, connect with sshd listening on `::1` and target `ssh://[::1]:22/path`. S (strip brackets) |
| 3985 | "Create bug report" does nothing | ENHANCEMENT | Working as designed: the report waits in the single-operation queue behind a stuck repair. The request is to run it out of order or rename it. | - |
| 3987 | Retention policy deletes a weekly backup a few seconds short | PRESENT | `DeleteHandler.cs:393` keeps a version only if `(fileset.Time - lastKept.Time) >= Interval`, with no tolerance. The 1% / 1 h tolerance (`Options.cs:879-883`) applies only to `--keep-time`. A daily or weekly schedule that starts a few seconds late therefore thins out every other version under `1W`/`1D` intervals. | Unit test of the retention logic: filesets 7d minus 5s apart with `1M:1W` → one gets deleted. S (apply the same tolerance to intervals) |
| 4015 | OneDrive "404 /me/drive" fatal after backup | EXTERNAL | Graph intermittently returns 404 for `/me/drive` in `GetQuotaInfoAsync` (`MicrosoftGraphBackend.cs:234`). A quota failure is not caught (`BackupHandler.cs:654`), so it fails the job. That is a possible small hardening, but the cause is on the provider side and needs a OneDrive account. | Needs OneDrive |
| 4044 | RecoveryTool restore: Too many open files | NEEDS_REPRO | `CompressedFileMRUCache` caps open archives at 200 (`--max-open-archives`) and disposes the oldest (`RecoveryTool/Restore.cs:574-617`). That was already true in 2019, and no leak was found (the earlier triage called it "undecidable"). | In WSL, set `ulimit -n 256` and run a recovery restore of a local backup with more than 300 small dblocks. S–M if it reproduces |
| 4155 | SFTP session drop reported as a temp-file IO error | NEEDS_REPRO | A 2020 stack trace from `SpillCollectorProcess`. The backend manager and the spill path were rewritten in 2025, and the code does not show whether the root error is still masked. | WSL sshd with `MaxSessions 1` (or restart sshd mid-backup); check that the reported error is the SSH one. S–M |
| 4157 | Limit temp usage when the temp dir is small | ENHANCEMENT | Feature request; the workaround is `concurrency-*` limits or `tempdir`. | - |
| 4175 | usn-policy=required still falls back to a full scan | PRESENT | `BackupHandler.cs:115-119` turns every `UsnJournalSoftFailureException` into "Performing full scan" whatever the policy is. The help text (`Strings.cs:156`) says "required" aborts the backup. In addition, one unresolvable entry anywhere on the volume (`USNJournal.cs:498,586`) disables USN. | Windows as admin: back up with `--usn-policy=required`, run `fsutil usn deletejournal /d C:` and recreate it, back up again → full scan instead of an abort. S (code or doc; first-run soft failure needs a decision) |
| 4192 | OD4B "Cannot send a content-body with this verb-type" | EXTERNAL | A Mono HTTP issue in the old OD4B client. The backend now uses the updated PnP client (#5112) on .NET. Checking it needs an OD4B account; the earlier triage left it undecided. | Needs OD4B |
| 4198 | MinIO SecureChannelFailure | EXTERNAL | Mono 4.6 TLS. The reporter fixed it by upgrading Mono, and Duplicati no longer uses Mono. | - |
| 4209 | MinIO first backup: all files "missing" | NO_INFO | 2020/Mono, no URL or log. The symptom matches #4711 (leading `/` in the folder path), but that is not confirmed. | - |
| 4216 | Google Drive hangs on "waiting for upload to finish" | NO_INFO | 2020/Mono. The reporters traced it to backing up Duplicati's own DB; no log. | - |
| 4218 | Large SFTP backup fails (DNS / tmp file) | EXTERNAL | The reporter showed it is Mono DNS resolution (an `/etc/hosts` entry fixed it). Mono is gone. | - |
| 4290 | Support PowerShell pre-script | ENHANCEMENT | `.ps1` cannot be started directly by `ProcessStartInfo` (`RunScript.cs:406`). The workaround `--run-script-with-arguments` + `powershell.exe -File x.ps1` exists (`RunScript.cs:63,115`). | - |
| 4328 | rclone hang unless disable-piped-streaming | FIXED | Piped download was removed in 627bccbb9 (2024-09-26); the option is gone. The rclone executer reads output asynchronously and throws on stderr (`Rclone.cs:96-195`). | - |
| 4468 | Rootless Docker restore gives wrong GID silently | EXTERNAL | Unmapped owners appear as 65534 (overflowgid) inside the user namespace, and that is what was backed up. The restore wrote back what it recorded (comment already posted with the arithmetic). | - |
| 4507 | purge-broken-files does not stop the "missing remote file" warning | PRESENT (minor) | Recreate registers the dblock that a stale dindex points to as Temporary (`RecreateDatabaseHandler.cs:494-504`). The next list drops it from the DB with an Information log (`FilelistProcessor.cs:416-418`), so purge-broken-files sees nothing missing (`ListBrokenFilesHandler.cs:83-86`). The orphan dindex stays at the destination, and every recreate warns again. Verified 2026-10-30 (`ProbeOrphanDindex.cs`): repair on an existing DB removes it (`RepairHandler.cs:654`), compact does not, although `LocalRecreateDatabase.cs:1374` says it does. That triage chose not to fix it. | Local backend: back up, delete a dblock+dlist, put back only the dindex, recreate twice. S |
| 4530 | Fix OS notifications | FIXED | Native notifiers: Windows toasts 9e3a5695c, macOS 8274b51b8, Linux D-Bus 80f6be4ca (2026-08). Wired in `AvaloniaRunner.cs:286`. | - |
| 4532 | Replace WebClient/WebRequest/HttpWebRequest | FIXED | `git grep -E 'new WebClient\|WebRequest\.Create\|HttpWebRequest' -- '*.cs'` returns 0 on master (comment already posted; last use removed in #6291). | - |
| 4533 | Rewrite thread interruption code | ENHANCEMENT | `Thread.Abort` is gone and backends take a CancellationToken. `Thread.Interrupt` remains in `HostedInstanceKeeper.cs:100` and `Server/Program.cs:423`. Refactoring task, no bug. | - |
| 4534 | Make all backends async | FIXED | #5978 (4822bc45, Feb 2025); `IBackend` is async-only (comment already posted). | - |
| 4536 | Remove AlphaFS | FIXED | #5211 (f70748359); `git grep -i alphafs` is 0 (comment posted). | - |
| 4538 | Verify BackendTester | FIXED | Covered by `BackendTester{Cleanup,EmptyFolder,RateLimit,Verification}Tests.cs`; it also drives the fork CI backend tests. Task issue. | - |
| 4539 | Verify BackendTool | FIXED | `BackendToolTests.cs` exists on master. Task issue. | - |
| 4540 | Verify ConfigurationImporter | FIXED | The tool was removed and replaced by `duplicati-server-util` in 735b4020e (2024-08-26). | - |
| 4541 | Verify RecoveryTool | FIXED | `RecoveryToolTests.cs` (`RecoverAsync`, prefix/path-map restores) plus path-traversal tests exist. Task issue. | - |
| 4544 | Fix assumptions about relative paths | FIXED | The cited `Duplicati/Server/WebServer/Server.cs` no longer exists (Kestrel rewrite 235568dad). No other concrete case was given. | - |
| 4545 | X509Certificate2(byte[]) unsupported on macOS | FIXED | Loading uses `X509CertificateLoader`. The only `new X509Certificate2(` takes an `X509Certificate` (`SslCertificateValidator.cs:60`). Comment posted. | - |
| 4546 | RSACryptoServiceProvider(CspParameters) | FIXED | #4584 (bfdeae06); `git grep CspParameters` is 0 (comment posted). | - |
| 4554 | Embedded resources missing on net5-split | FIXED | `/api/v1/backupdefaults` returns `aes` on master since #6249 (measured, comment posted). | - |
| 4586 | "Remote file referenced ... not found in list" after recreate | DUPLICATE | Same mechanism as #4507: a leftover dindex points to a dblock that does not exist, and only repair on an existing DB removes it. | see #4507 |
| 4627 | HTTP 400 on large request headers | FIXED | Kestrel (#5112, 235568da). Measured 200 with Cookie headers up to 30,000 bytes (comment posted). | - |
| 4671 | Add a "verifying database consistency" phase | ENHANCEMENT | UI/progress feature. | - |
| 4675 | SFTP hangs / unknown error when the remote disk is full | NEEDS_REPRO | Probably fixed: SSH.NET 2025.1.0 (3f6b1384d, now 2026.0.0) contains sshnet PR #1643 for missed upload errors that caused hangs (per the SSH.NET maintainer's comment; ドキュメント根拠). Upload goes through `BeginUploadFile` (`SSHv2Backend.cs:299`). | SFTP container with a small tmpfs as the target, back up a file larger than it; expect an error, not a hang. S |
| 4709 | Backup stalls at verification (OneDrive, 2022 canary) | NO_INFO | Only a screenshot from an old canary. The verify/backend code has been rewritten since. | - |
| 4711 | S3 folder with leading "/" → "found prefixes: uplicati" | NEEDS_REPRO | The quoted message no longer appears (9dfe977d3). ngclient warns about a leading slash (`destination.config.ts:47`). A backend fix (`fix/s3-leading-slash-folder-list`) was withdrawn on 2026-10-30: real MinIO returned 0 keys and SignatureDoesNotMatch, unlike the fake S3 server. | `cgr.dev/chainguard/minio` (`--user 0`), folder `/x`; observe what list and put do now. M |
| 4737 | FTPES 426 "Data channel closed" | NEEDS_REPRO | The FtpWebRequest backend was removed (a4482a4d0, 2024-10). The remaining FluentFTP is 54.2.0, and FluentFTP fixed a 426 case in v42. The server (Freebox) is unknown, so this may be the same TLS session-reuse problem as #4831. | vsftpd/pure-ftpd FTPES container with `require_ssl_reuse`; test the connection. S–M |
| 4750 | Hyper-V writer warnings on Windows client | FIXED | ea2ba06ff (2024-11-25) added `--hyperv-ignore-client-warning`, which suppresses the client-version warning (`HyperVSourceProvider.cs:96,257-261`). Excluding the writer is still rejected on purpose (`:245-248`). | - |
| 4753 | Linux filenames in Windows-1252 bytes not backed up | EXTERNAL | Non-UTF-8 file names cannot round-trip through .NET strings on Linux (a runtime limitation), so the enumerator cannot open them. | - |
| 4792 | send-http-url not sent with many warnings | FIXED | Duplicate of #2843, fixed by aabfbb8d (chunked escaping). Comment posted. | - |
| 4795 | OneDrive restore stalls after CommitBlockMarker | NO_INFO | 2022 report on the legacy restore; the restore flow has since been rewritten. No log of where it hangs. | - |
| 4798 | macOS 12.5: restore points "undefined", TempFile.Path NOT NULL | NO_INFO | Mono-era macOS. The NOT NULL comes from `RegisterTempFile("create-bug-report", r.TargetPath, ...)` (`RestAPI/Runner.cs:1156`) after the report itself failed. No follow-up since 2022. | - |
| 4799 | Excluded locked file still accessed | QUESTION | Maintainers could not reproduce it. The reporter's audit log shows the job running as `admin` (tray-icon instance) rather than the service, which points to a setup issue. | - |
| 4803 | S3 storage class (Scaleway) ignored; backup fails after GLACIER | FIXED (part) | Archived objects are now skipped in verification (71b3152f7, 771b546be). The storage class is sent by the default aws client (`S3AwsClient.cs:308-309`). Side note: `S3MinioClient` ignores `storageClass` (`S3MinioClient.cs:47`, never used). Part 1 on Scaleway is unverified. | - |
| 4814 | Publish GitHub "latest release" for deb-get | ENHANCEMENT | Release-process request. | - |
| 4827 | Restore of symlinks fails with EEXIST | FIXED | An existing link is now replaced, or kept if it already points to the same target (`FileRestoreDestinationProvider.cs:176-226`; b93320b6b 2026-09-27, #7535 for dangling links). | - |
| 4831 | FTPS with FileZilla Server 1.x (TLS session resumption) | NEEDS_REPRO | `FTPBackend.cs:346-367` uses FluentFTP 54.2.0 with the .NET SslStream. FluentFTP.GnuTLS, which fixed it in a contributor's test, is not used. | FileZilla Server 1.x (free) on Windows localhost with TLS 1.2/1.3. M (GnuTLS stream option) |
| 4832 | Storj: a failed first upload breaks later backups | EXTERNAL | Needs a Storj account. No error text was ever provided. | Needs Storj |

**Count: 51 rows** (input file has 51 lines).

Bucket counts (counted with awk over the table): PRESENT 3 (3987, 4175, 4507), NEEDS_REPRO 8 (3859, 3959, 4044, 4155, 4675, 4711, 4737, 4831), FIXED 19, ENHANCEMENT 7, EXTERNAL 7, NO_INFO 5, QUESTION 1, DUPLICATE 1.

### part02

# Triage of part02.tsv (58 issues), master d2f77cc8

| number | title (short) | bucket | evidence | repro / size |
|---|---|---|---|---|
| 4845 | S3 compatible slow upload with sig v4 | NO_INFO | 2.0.6.3 (mono / old AWS SDK); single report, no reproduction, S3 client code replaced since (S3AwsClient.cs, Minio client). | - |
| 4846 | Revoked AuthID keeps working | EXTERNAL | Cause is in duplicati/oauth-handler: access token cached in memcache and not cleared on revoke (already explained in a JamBalaya56562 comment). | Change goes in oauth-handler |
| 4878 | Storj DCS with API key fails ("node id is required") | EXTERNAL | Satellites are still bare `host:7777` (Storj/StorjBackend.cs:66-70, :114-121); whether uplink.NET 2.14 resolves known node IDs is library behaviour (unverified). Needs a Storj account. | Needs Storj account |
| 4984 | DisruptionTests StopAfterCurrentFile / partial then no-change full backup not uploaded | FIXED | 5f8ff74b (2025-03-08, "Streamlined handling of previous backup's fileset…") added `lastWasPartial` to the upload condition; now UploadRealFilelist.cs:57 `doUpload = … \|\| lastWasPartial`. | - |
| 5007 | Recreate does not detect missing encryption config | FIXED | 73a2f32b "Stop recreate early if passphrase is missing": RecreateDatabaseHandler.cs:230 throws `MissingPassphrase`. | - |
| 5035 | Re-created dindex lacked list folder, recreate downloads dblock | NO_INFO | Only seen once under unusual B2 503 + retries=0; no simple repro. Recreated dindex now writes blocklists (Common/IndexVolumeCreator.cs:179-184), and the upload/interruption path was rewritten in 2.1 (d99f74ed). | - |
| 5045 | Unscheduling a job may not prevent it from running | PRESENT | Scheduler enqueues missed runs at startup (RestAPI/Scheduler.cs:417, `m_queueRunnerService.AddTask(job)`); nothing removes an already queued task when the schedule is deleted. IQueueRunnerService has no remove/dequeue method, and OnStartingWorkAsync (Scheduler.cs:237) does not re-check the schedule. | Local Windows: settings pause 10 min at startup, schedule job 1-2 min ahead, quit, start after the time, delete the schedule, wait for the pause to end: job runs. Size M |
| 5055 | all-versions: restore tree shows files of other versions, they are silently not restored | PRESENT | With global `--all-versions=true` (applied to the list task via Runner.GetCommonOptions, Runner.cs:2007), ListFilesHandler.cs:55/64 skips `TakeFirstAsync` even when a `time` is given, so the tree lists files from all filesets, while the restore uses only the chosen version. Not run (unverified). | Local: set all-versions=true in Settings advanced options, back up A and B, delete B, back up, restore latest selecting A and B: only A restored. Size S (ignore all-versions in UI list with a time, or restore per-version) |
| 5082 | Alternative FTP misuses low-level FluentFTP API (OpenRead) | NEEDS_REPRO | Suggested fix (DownloadStream instead of OpenRead) not applied: FTP/FTPBackend.cs:522 still uses `client.OpenRead` + stream copy (FluentFTP 54.2.0). Whether the final 226 reply is now consumed on dispose is not settled by the code. | proftpd container (WSL/Docker), loop BackendTester get/list with FluentFTP logging on, look for out-of-order replies. Size S |
| 5092 | Deleting a backup should revoke the OAuth token | ENHANCEMENT | Feature request; disputed (AuthIDs are shared between jobs). | - |
| 5102 | Storj out-of-storage error not reported | FIXED | PR #5120 (81e162fd) checks the upload result: Storj/StorjBackend.cs:273-274 throws `upload.ErrorMessage`. | - |
| 5113 | Hang when FTP destination refuses login | FIXED | Reported on the legacy FTP backend, removed in a4482a4d (2024-10-11); "FTP" now uses the FluentFTP code that errored in the reporter's test. | - |
| 5114 | Unable to schedule backup to S3 (NameResolutionFailure) | EXTERNAL | DNS failure inside third-party linuxserver Docker image, old 2.0.7.1; no follow-up. | - |
| 5131 | "Unexpected difference in fileset", cannot delete versions | NO_INFO | Resolved on the forum per kenkendk; DB bugreport is private; no code lead. | - |
| 5136 | TrayIcon crashed with c0000005 | NO_INFO | Access violation in ntdll on the old .NET Framework WinForms TrayIcon (2.0.7.101); TrayIcon has since moved to .NET 8/Avalonia; no repro. | - |
| 5139 | Minio SDK connection test false "Access denied" | NO_INFO | Reporter never answered the requests for logs. The test now also writes, reads and deletes a test file (Utility/BackendExtensions.cs:90), so the old list-only path no longer applies. | - |
| 5156 | Source tree parent "partial" squares missing in Chromium (ngax) | NEEDS_REPRO | ngax sourceFolderPicker.js:214-232 sets `include=' '` from `partialincludemap` (built at :370); looks like an ordering race between the watchers and special-folder mapping (:383) on first load; code does not settle it. | Local: ngax UI in Chrome/Edge, edit a job with a nested source (e.g. a subfolder of My Pictures), hard-refresh on the Source tab. Size S-M |
| 5186 | Tray icon stayed "paused" after wake | NO_INFO | One-off, not repeatable even by reporter; TrayIcon rewritten (Avalonia) since 2.0.8.1. | - |
| 5205 | Remove `use-ssl` flag and logic | ENHANCEMENT | Planned refactor; still present (DynamicLoader/BackendLoader.cs:83-95 `s` suffix, S3Backend.cs:43). | - |
| 5224 | Tray icon disappears when backup starts (Linux) | EXTERNAL | DBus socket reset in Avalonia tray (AvaloniaUI/Avalonia#13130), per Jojo-1000's analysis. | - |
| 5226 | Crash when Storj backup starts on Linux | EXTERNAL | uplink.NET native library issue (TopperDEL: fixed in newer uplink.NET); Duplicati now uses 2.14.3623; needs Storj account to confirm. | Needs Storj account |
| 5239 | Rework direct recovery in the UI | ENHANCEMENT | Design task. | - |
| 5240 | Improve direct restore speed | ENHANCEMENT | Design task. | - |
| 5242 | Improve recovery tool use cases | ENHANCEMENT | Feature request. | - |
| 5244 | DB version 12 vs 10 after failed update | QUESTION | User documents own workaround; cause was the old self-updater, which kenkendk says was removed. | - |
| 5248 | TrayIcon Quit leaves server running | NO_INFO | kenkendk: resolved by new server hosting; asked reporter to retest, no answer. | - |
| 5250 | Slow SQL with etilqs reads in AppendFilesFromPreviousSetWithPredicate | PRESENT | Local/LocalBackupDatabase.cs:1694 creates the temp FilesetEntry table without an index, then :1721/:1752 runs `DELETE … WHERE FileID=@FileId` once per row, so each delete scans the table: quadratic. Reached via USN (BackupHandler.cs:438) or change tracking (:487). Not timed (unverified). | Unit test or bench: DB with ~200k files in previous fileset, call AppendFilesFromPreviousSetWithPredicateAsync with predicate true for most; or Windows admin + usn-policy on a large tree. Size S (index the temp table or delete in bulk) |
| 5268 | IOException: Stale file handle (NFS) | EXTERNAL | NFSv4 mount behaviour inside a third-party Docker image. | - |
| 5273 | TrayIcon should use websocket | ENHANCEMENT | Not done: TrayIcon/HttpServerConnection.cs:418 comment "Should rewrite … use websockets". | - |
| 5398 | Backup fails: 550 deleting a dlist that doesn't exist | FIXED | a4482a4d maps FTP 550/450 on delete to a missing file; d99f74ed (#5896) treats a missing-file delete as done after a list. | - |
| 5421 | Standardize argument parsing | ENHANCEMENT | Refactor. | - |
| 5440 | Optional RTL layout | ENHANCEMENT | Feature request. | - |
| 5457 | Screenshot tests for visual regressions | ENHANCEMENT | Feature request. | - |
| 5482 | Pause on metered connections | ENHANCEMENT | No metered detection in code (grep "metered" empty). | - |
| 5553 | Detect low-power/no-network in scheduler | ENHANCEMENT | Not implemented (no network check in Scheduler.cs). | - |
| 5554 | Multi-threading / other DB types? (zh) | QUESTION | Question plus loose suggestions, answered by kenkendk. | - |
| 5590 | WSL filesystem hidden files | ENHANCEMENT | Request to treat dotfiles over `\\wsl.localhost` as hidden; Windows hidden attribute comes from the 9P share, not Duplicati. | - |
| 5591 | First visit shows "Connection lost" | NO_INFO | Seen once on 2.0.9.108 (ngax era), not repeatable; ngclient is now the default UI. | - |
| 5594 | Passkey login | ENHANCEMENT | Feature request. | - |
| 5599 | Install scripts | ENHANCEMENT | Feature request. | - |
| 5601 | Custom backup file suffixes | ENHANCEMENT | Feature request (wrapping backend suggested). | - |
| 5602 | Reorder backups (run order) | ENHANCEMENT | UI sorting added (PR #6090); run order still by ID. | - |
| 5635 | Remove Library.Utility.Uri | ENHANCEMENT | Refactor; still partly blocked by folder-name authorities (memory note). | - |
| 5647 | Updater downloads and installs package | ENHANCEMENT | Feature request. | - |
| 5649 | FreeBSD support | ENHANCEMENT | Porting request. | - |
| 5663 | Rename packageId osx to macos | ENHANCEMENT | Not done (no "macos" package id in AutoUpdater). | - |
| 5675 | Agent on macOS access to Documents | ENHANCEMENT | Platform feature. | - |
| 5759 | Improve TemporaryFamily usage in tokens | ENHANCEMENT | Security hardening design. | - |
| 5764 | Proton Drive backend | DUPLICATE | Duplicate of #5086 (stated in comments). | - |
| 5794 | Theme as server-saved setting | ENHANCEMENT | ngclient still keeps it in localStorage (layout/layout.state.ts:20 `localStorageSignal('darkTheme')`). | - |
| 5912 | Restart webserver by API | ENHANCEMENT | Feature request. | - |
| 5915 | Stream filelists into DB | ENHANCEMENT | Memory optimisation. | - |
| 5917 | HEAD operation in IBackend | ENHANCEMENT | Not in Interface (no Head/Stat method). | - |
| 5932 | Auto-create DB if missing | ENHANCEMENT | No such option in Main/Options.cs. | - |
| 5933 | Temporary backup configs for restore | ENHANCEMENT | Design task. | - |
| 5934 | `.duplicati-ignore` file | ENHANCEMENT | Only `ignore-filenames` (whole folder skip, Options.cs:596) exists; no gitignore-style filters. | - |
| 5942 | Prioritise restore over backup jobs | ENHANCEMENT | Feature request. | - |
| 5992 | Exclude own folder in Docker | ENHANCEMENT | Feature request. | - |

Count: 58 rows (input file has 58 lines).

Buckets: PRESENT 3, NEEDS_REPRO 2, FIXED 5, ENHANCEMENT 31, EXTERNAL 6, NO_INFO 8, QUESTION 2, DUPLICATE 1 (total 58; issue set matches part02.tsv).

### part03

# Triage result, part 03 (master d2f77cc8)

| number | title (short) | bucket | evidence | repro / size |
|---|---|---|---|---|
| 6074 | rsync mirror job option | ENHANCEMENT | New feature; kenkendk objects ("why not rsync"). | - |
| 6112 | Customize remote file extensions | ENHANCEMENT | Feature request; no code for custom suffixes. | - |
| 6149 | Error on empty source folder | ENHANCEMENT | Feature request; ts678 points to `--run-script-before` exit codes as workaround. | - |
| 6152 | Resumable recreate database | ENHANCEMENT | Maintainer-filed feature. | - |
| 6209 | Sharded remote paths | ENHANCEMENT | Feature; kenkendk prefers larger volumes, see #1374. | - |
| 6221 | Download restore via browser | ENHANCEMENT | Maintainer-filed feature. | - |
| 6228 | Unfreeze / thaw command | ENHANCEMENT | Maintainer-filed feature (Glacier etc.). | - |
| 6251 | "Failed to create built-in ZIP archive" warnings | EXTERNAL | Old dblocks (2.0.7.x, SharpCompress writer) with >65535 entries have a wrong EOCD count; read falls back to SharpCompress and succeeds (`FileArchiveZip.cs:156-165`). Writes now use System.IO.Compression. Only the legacy data is defective; compact rewrites it. | - |
| 6297 | Proxy support | ENHANCEMENT | kenkendk: no proxy support exists. | - |
| 6304 | Start backup when drive connects | ENHANCEMENT | Feature; contributor proposal, no implementation. | - |
| 6305 | Remove concurrent index file generation | ENHANCEMENT | Maintainer-filed refactor. | - |
| 6325 | Multi-drive restore mapping on Windows | ENHANCEMENT | Maintainer-filed improvement. | - |
| 6327 | Requests-per-second rate limit | ENHANCEMENT | Maintainer-filed feature (`--max-requests-per-second`). | - |
| 6376 | Delete broken remote files | ENHANCEMENT | Maintainer-filed feature. | - |
| 6391 | Expand env vars on import | ENHANCEMENT | Maintainer-filed feature. | - |
| 6440 | Crashes after some time on Server 2019 | NO_INFO | 2.1.0.5; only log is a handled `NotFoundException` from `/filesystem/validate`, no crash record; reporter did not return the Event Viewer crash entry. | - |
| 6557 | Mark Docker image official | ENHANCEMENT | Docker Hub administrative request, not code. | - |
| 6575 | UNIQUE constraint FilesetEntry | FIXED | Cause was a file source inside a folder source; fixed by #7190 (merge 24cedd373), covered by `Issue7189.FileInsideIncludedFolderIsPrunedAndBackedUpAsync` (`Duplicati/UnitTest/Issue7189.cs`). | - |
| 6578 | Architecture proposal (WAL, auto-repair) | ENHANCEMENT | General proposal, not a bug. | - |
| 6597 | Race on restore-from-files first query | NEEDS_REPRO | Maintainer-filed; 5a075d3ce (2025-06, before the issue) changed temp-db listing but the "no fileset found" race is not located in code. | Direct restore from a local folder in ngclient on a fresh server, repeat several times, watch first folder query. |
| 6607 | GPG: backup without private key | ENHANCEMENT | Verification/compact need decryption by design; workaround `--no-backend-verification --no-auto-compact`; wording of "last successful backup" is UI suggestion. | - |
| 6611 | Show settings and their source | ENHANCEMENT | Feature; naming split to ngclient#397. | - |
| 6621 | Non-UTF-8 byte filenames | EXTERNAL | .NET treats paths as UTF-16/UTF-8 strings and transforms invalid bytes (kenkendk confirmed); fix needs bypassing .NET path APIs. | - |
| 6626 | Failed dblock upload leaves blocks in dlist | NEEDS_REPRO | JamBalaya56562 tried failing-dblock scenarios on master, all clean; reporter's DB shows block left in `Block` of a Deleting volume; waiting on reporter's log lines. | Already attempted with a failing test backend; needs the reporter's 08:34 log to pick the path. |
| 6639 | FTPS "Status is Failed" though file written | NEEDS_REPRO | `FTPBackend.cs:485-487` throws when FluentFTP 54.2.0 `UploadStream` returns `FtpStatus.Failed` (server reply text is dropped). Likely Synology + TLS 1.3 data-channel close in FluentFTP; not settled by code. | Local FTPS server in Docker (vsftpd/pure-ftpd, TLS 1.3, explicit), `--ftp-ssl-protocols=Tls13` vs `Tls12`. Size S if only the message needs the server reply. |
| 6683 | Synology WebDAV: files reported missing | NEEDS_REPRO | 2.2.0.1, Docker/arm64; WebDAV listing parse changed since (d02d7feb6 #6591, 20145dc6e #7464 fixes Linux path-only hrefs with escaped chars). Unclear if reporter's path had escaped chars; webdavs→webdav export remark unexplained. | wsgidav (uv) server returning path-only hrefs, run backup on Linux/WSL with 2.2.0.1 vs master. |
| 6744 | Restore thrashes TEMP with dup files | FIXED | Volume cache was capped at 100x volume size; e7b998f909988b34392b2d6f0cc78fecbb7d07ee (#6785) made it unlimited with disk-pressure eviction (`Options.cs:2121-2131`, min free 1 GB). | - |
| 6767 | SMB "difference between bytes read and written" | FIXED | Message came from checking byte count before the NT status; now status is checked first (`SMBShareConnection.cs:552-556`, 77224c22c / #7638), plus timeout fixes (#7593, 11b460843). Underlying server status still unknown; kenkendk asked reporters to retest. | - |
| 6829 | 12 restore downloaders thrash USB HDD | ENHANCEMENT | Default is by design `ProcessorCount/2` (`Options.cs:164,179,189`) and tunable via `--restore-volume-downloaders`; request is for adaptive/HDD-aware defaults. | - |
| 6835 | Movistar cloud backend | EXTERNAL | Backend merged (#6821, `Backend/MovistarCloud`), now broken by Movistar MFA; needs a Movistar subscriber account. | - |
| 6840 | TrayIcon makes dwm.exe busy while screen off | NEEDS_REPRO | Tray is Avalonia (`AvaloniaRunner.cs:598`); kenkendk suspects Avalonia, updated in 2.4; no Duplicati code lead. | Windows 11: start TrayIcon, turn monitor off with `SendMessage(0x112,0xF170,2)` (SC_MONITORPOWER), check dwm.exe CPU on 2.3.0.4 vs master. |
| 6863 | Created parent dir ownership not restored | ENHANCEMENT | Only the selected source (the file) is enumerated, so no metadata exists for the unselected parent; restoring it would require backing up ancestor metadata. | - |
| 6865 | Direct restore from UNC path | QUESTION | ts678: File system destination with manual UNC path works in ngclient (SMB type is optional). | - |
| 7024 | HTML emails | ENHANCEMENT | `SendMail.cs` has no HTML body support. | - |
| 7103 | GUI crash, ServerUtil locks server DB | NO_INFO | Template unfilled, version 0.0.0.0; kenkendk asked why ServerUtil runs, no answer. | - |
| 7105 | Stop/Abort not stopping job | NO_INFO | 2.3.0.4 on Unraid, no log; several stop-hang layers fixed since (#6461 work). | - |
| 7123 | CLI continues with unknown options | ENHANCEMENT | Warning by design (`Controller.cs:1499`); request for strict mode, related #1970. | - |
| 7264 | --max-upload-per-run | ENHANCEMENT | Feature request. | - |
| 7265 | macOS Photos memory growth | EXTERNAL | PhotosKit enumeration path; needs macOS with a large Photos library. | - |
| 7270 | Boot media for bare-metal restore | QUESTION | Duplicati is file-level; no imaging feature. | - |
| 7370 | Drime duplicated files / halts | DUPLICATE | Original "duplicates" symptom fixed via #7285 (closed 2026-09-11); on 2.4.0.1 it became the error tracked in #7474. | - |
| 7470 | Going in circles verifying backend | NO_INFO | linuxserver image, log only shows server restarts; no job log. | - |
| 7472 | Data folder symlink fails permission check | PRESENT | `SystemIOLinux.cs:504` uses `PosixFile.GetUserGroupAndPermissions` (lstat), so a symlink reports 0777. kenkendk wants symlinks rejected; fix branch `fix/datafolder-reject-symlink` (110f35cd7) pushed by JamBalaya56562, no PR yet. | WSL: symlink to a 0700 folder as data folder, start server. Size S. |
| 7474 | Drime: more unique active IDs than folder count | EXTERNAL | Strict check `DrimeBackend.cs:778-780` throws when the listing exceeds the separate folder-count endpoint; cause is Drime's count/listing consistency, needs a Drime account to observe. | - |
| 7476 | 2.4.0.1 MSI install fails | NEEDS_REPRO | Event log: `PreloadSettingsLoader.VerifyPreloadFileSecurity` (`PreloadSettingsLoader.cs:376-393`) throws because the preload folder `C:\Users\Duplicati\AppData\Local\Duplicati` grants rights to another SID (`SystemIOWindows.cs:1129-1133`, only current user/SYSTEM/Admins allowed); the unhandled exception kills `Duplicati.WindowsService.exe` in the installer custom action. Intended security check vs. a dedicated service-account setup; reporter's exact config unclear. | Windows: local user "Duplicati", preload.json in its LocalAppData (ACL incl. that user), run installer / `Duplicati.WindowsService.exe` as SYSTEM. Size S-M (decide policy, avoid hard MSI rollback). |
| 7517 | Jottacloud "Session doesn't have required client" | EXTERNAL | invalid_grant from Jottacloud/OAuth handler on refresh; needs a Jottacloud account. | - |
| 7524 | --restore-permissions alone and symlink owner | PRESENT | `FileRestoreDestinationProvider.cs:235` returns early for links without `--restore-symlink-metadata`, so the owner (`SystemIOLinux.cs:296`) is never set; kenkendk chose option A. Branch `fix/restore-symlink-owner-with-permissions` (f997b0066) pushed, no PR yet. | Linux as root: back up a symlink owned by another user, restore with `--restore-permissions` only, check `stat`. Size S. |
| 7538 | Restore RAM >18 GB, OOM | PRESENT | Per-block delay timers kept alive (`BlockManager.cs:349-350`, `Task.Delay(timeout, tcs1.Token)` not cancelled) and token callbacks per read (`VolumeManager.cs:81-82`); fix in open PR #7653 (JamBalaya56562). | Restore of ~200k small files on Linux, watch RSS / dotnet-gcdump. Size S (PR open). |
| 7627 | Alert when no success for N hours | ENHANCEMENT | Feature request. | - |

Count: 49 issues (input file has 49 lines).

Buckets: ENHANCEMENT 24, EXTERNAL 6, NEEDS_REPRO 6, NO_INFO 4, PRESENT 3, FIXED 3, QUESTION 2, DUPLICATE 1 (total 49).
