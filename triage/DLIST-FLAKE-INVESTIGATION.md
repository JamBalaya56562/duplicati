# `DisruptionTests.TestMultiExceptionOnDlistAsync` — the interrupted-run flake

**Status 2026-09-05. Still nothing to read, and the other red is gone.**
[#7276](https://github.com/duplicati/duplicati/pull/7276) merged on 2026-09-04 and
`Test_Unknown_NoPartitions_Async` passes. Every `tests.yml` run from 09-02 19:10 to 09-04
12:52 failed; the two runs since — the PR's own, and the `release/canary-2.4.0.100` one cut
minutes after it merged — are green. **That is two data points.** No third-party PR has run
yet, so this is not confirmed the way a week of green would confirm it.

**The 09-04 caveat is lifted; the habit is not.** There is no second Windows red to confuse
this one with any more, but read the failing test name before calling a Windows-only red a
flake. That is what told the two apart.

**Status 2026-09-04. Still nothing to read, and there is now a red on Windows that is not
this one.** `Test_Unknown_NoPartitions_Async` fails on every Windows unit-test job, from
`proprietary/DiskImage` — a PowerShell call that exits 1 with an empty error message. It
fails on branches whose diff cannot reach it, so it is on master, not in any one PR. **Read
the failing test name before calling a Windows-only red a flake.** See the 2026-09-04 entry
in [ISSUE-TRIAGE-REPORT.md](ISSUE-TRIAGE-REPORT.md).

**Status 2026-09-01, checked twice. Still nothing to read.** [#7233](https://github.com/duplicati/duplicati/pull/7233)
has been on master since 2026-08-29 and no occurrence has come in since, over three days of
upstream activity. Of the last 30 `tests.yml` runs, three were red, and every one of them
failed on **all three platforms** — two on `Run10kIPCAsync` /
`RunBackupViaIPC_ReceivesCallbacksAsync`, one on the metadata repair tests, all on
maintainer branches. The IPC pair was fixed by follow-up commits on the same branch; the
repair one stayed red and #7220 was merged anyway. **None of them is this one** — the
assertion and the case are different in all three. Nothing to do but wait.

One thing worth knowing for when it does arrive: [#7250](https://github.com/duplicati/duplicati/pull/7250)
is making the unit tests complete in release mode. It changes `BasicSetupHelper` and two
test files, not the workflow, so the jobs still build Debug today. But if the CI ever
follows, the timings this test races on change, and an occurrence from before that is not
comparable with one from after.

**Status 2026-08-29. Both signatures have now been seen upstream, and between them they
cover all three platforms.** The second one came in on **windows**, on
[#7173](https://github.com/duplicati/duplicati/pull/7173)
([job 99048873142](https://github.com/duplicati/duplicati/actions/runs/33232964775/job/99048873142)),
a branch that adds nothing but `CREATE INDEX` statements to `LocalTestDatabase`. macOS and
ubuntu passed in the same run.

```
The last backup reported 0 added and 0 modified file(s), 0 added and 0 modified folder(s).
Versions present: #0 full at 04:41:26Z with 3 file(s), #1 full at 04:41:25Z with 3 file(s)
Expected: 1  But was: 2
```

That is the second signature below, to the character: case `(False,False,3,True)`, 1 against 2,
nothing added or modified, and **two full versions one second apart**. Until now it had only
been seen on the probe branch on macOS, so it was on record but not upstream.

| signature | case | first seen upstream | platform |
|---|---|---|---|
| a partial survives | `(True,False,3,True)` | [#7221](https://github.com/duplicati/duplicati/pull/7221), 2026-08-27 | ubuntu |
| a completed dlist survives | `(False,False,3,True)` | [#7173](https://github.com/duplicati/duplicati/pull/7173), 2026-08-29 | windows |

**[#7233](https://github.com/duplicati/duplicati/pull/7233) is merged (2026-08-29), and it
only answers the first one.** It records what each interrupted run sent, which names the run
that uploaded when it should have had no reason to. An ordinary job now carries that, so the
next occurrence of the first signature should arrive with the answer in it — there is nothing
left to set up, only an occurrence to wait for. The passing shape reads
`Interrupted runs: #0 sent nothing; #1 sent nothing; #2 sent nothing`. The second signature has no such question: with `before=false` the put
completes before the error is thrown, so the first run really does upload, and really is
supposed to. What is unexplained there is that the dlist stays.

**Status 2026-08-28. It is not macOS-only.** It failed on **ubuntu** on
[#7221](https://github.com/duplicati/duplicati/pull/7221)
([job 98546439052](https://github.com/duplicati/duplicati/actions/runs/33080600037/job/98546439052),
2026-08-27), on a branch touching nothing but `Duplicati/Library/Backend/DrimeCloud/`.
Windows and macOS passed in the same run. The title said macOS-only through 2026-08-17;
that was the sample, not the fault. Known occurrences now span **windows (#7045, 2026-07-12),
macOS (#7203, 2026-08-23) and ubuntu (#7221, 2026-08-27)**.

**#7177 paid off.** The ubuntu failure arrived carrying the version list, and it matches the
first signature below exactly — `expected=1 actual=3`, `added=0 modified=0`, base + partial +
full. Without it the log would have read `Expected: 1 But was: 3` and taught nobody anything.

**There is now a local Linux harness, and it did not reproduce either.**
`sl archive` the tree into a `wslc` container on `mcr.microsoft.com/dotnet/sdk:10.0`
(.NET 10.0.400), build `Duplicati.UnitTest.csproj`, run the one case. The archive needs
`proprietary/**` and the root files (`LICENSE`, `changelog.txt`) or the build fails on
`Duplicati.Library.SourceProviders` and `Duplicati.License`.

| where | configuration | iterations | failures |
|---|---|---|---|
| windows | the one case | 8 | 0 |
| windows | with the coverage collector | 12 | 0 |
| linux | the one case, instrumented | 15 | 0 |
| linux | the whole class, with coverage | 4 | 0 |
| linux | the one case, all 8 cores saturated | 10 | 0 |

The load arm was the thing the old note said to try next. **It found nothing**, which agrees
with round 6 below: load is not the lever. Every linux pass reported the same thing the
instrumentation was added to show — **0 of 3 interrupted runs uploaded anything** — so the
passing behaviour is confirmed, not assumed.

**Read this file before investigating again.** On 2026-08-28 the whole of the analysis below
— the `doUpload` decision point, the correlation with the first interrupted run throwing, the
synthetic-filelist chain — was re-derived from the source before anyone opened this file. It
cost hours and produced nothing that was not already written here.

**Status 2026-08-17. Still not fixed, but no longer invisible.** The third of the three ways
forward listed at the end — making the failure say what happened — shipped as
[#7177](https://github.com/duplicati/duplicati/pull/7177) and **merged on 2026-08-17**. Every
future occurrence in an ordinary CI job now carries the version list with timestamps, whether
each version is partial, and the added and modified counts. That is the evidence nine rounds of
probing on a fork could not buy.

**The probe branch is gone.** `probe/dlist-flake` was deleted from the fork on 2026-08-17, local
bookmark and commit included. It had done 663 iterations across nine rounds and the anomaly had
not appeared in the last 312, so more of the same was not worth the CI. Rebuild it only if there
is a new question to ask; the old one is answered as far as repetition can answer it.

**Do not confuse this with the repair flake.** `TestPartialRepairPossibleWithPartialDataAsync`
also failed on macOS during this period and looks similar in a CI summary. That one was a
different, fully understood bug — one run in 256 the byte the test means to corrupt already held
the constant being written — and was fixed in
[#7178](https://github.com/duplicati/duplicati/pull/7178), merged 2026-08-17.

What follows is what was established and what was ruled out, including a hypothesis of mine that
a controlled experiment did not support.

## That it is a flake

Of the last thirty `tests.yml` runs on `duplicati/duplicati`, eight had a failing unit
test job. This test appears in two of them, both macOS:

| run | branch | result |
|---|---|---|
| 31757801037 | `fix/restore-io-honours-cancellation` | Expected 1, was **2** |
| 31808839842 | `feature/bump-ngclient-231` | Expected 1, was **3** |

The second settles it. That branch changes two files —
`Duplicati/Server/webroot/ngclient/package.json` and its lock file — and no C# at all.
Windows and Ubuntu passed on both commits.

The test was already stabilised once, in `461dccd675fe` (2026-07-17), which added
`check-filetime-only`. Both failing cases are `modifyInBetween=false`, the cases that
change was meant to cover.

## Reproducing it

A probe branch (`probe/dlist-flake` on the fork) runs the one test repeatedly on macOS and
prints, for every case, the fileset list with timestamps, the added/modified counters, the
destination before and after the last backup, and the log messages that last backup wrote.

| round | configuration | iterations | failures |
|---|---|---|---|
| 1 | the test alone | 40 | 0 |
| 2 | with the coverage collector the real job uses | 24 | **3** |
| 3 | as 2, with the message sink unfiltered | 40 | **1** |
| 4 | as 3, plus a directory listing after every step | 60 | 0 |
| 5 | as 3, controlled on the gap below | 120 | 0 |
| 6 | as 3, three shards under CPU load, three under disk churn, two clean | 96 | **1** |
| 7 | as 3, recording each interrupted run's backend puts | 71 | **3** |
| 8 | as 7, controlled on the gap, judged on run 1 throwing | 112 | 0 |
| 9 | as 7, arms dropped, aimed only at catching it | 100 | 0 |

**The coverage collector is what brings it out** — nothing in round 1, three in round 2's
twenty-four. It slows execution, and this failure is timing-sensitive.

**Load is not the lever.** Round 6 made the machine bad on purpose and the only failure
came from a shard with no load at all.

**The rate moves between days by more than any of these experiments can see through.**
Round 7 saw the same case fail three times in seventy-one. Rounds 8 and 9 then went **312
iterations without a single one**, on the same commit shape, the same configuration and the
same signal — round 9 having dropped the arms entirely and aimed at nothing but catching
it. Every shard reported exactly the baseline count of throws, which is what a clean run
looks like.

Across all nine rounds: **eight occurrences in 663 iterations**, and none in the last 312.
That is what defeated both attempts at a controlled experiment: the control arm has to
fail for the treatment arm's silence to mean anything, and it would not.

## What the failures look like

Two signatures, both with `withBase=true` and `modifyInBetween=false`:

```
case=(True,False,3,True) expected=1 actual=3
  counters added=0 modified=0 examined=3
  fileset version=0 full=1 time=20:38:26     <- the last backup
  fileset version=1 full=0 time=20:38:20     <- partial: a synthetic filelist
  fileset version=2 full=1 time=20:38:16     <- the base backup
```

```
case=(False,False,3,True) expected=1 actual=2
  counters added=0 modified=0 examined=3
  fileset version=0 full=1 time=21:14:46
  fileset version=1 full=1 time=21:14:45
  remote-before   ...211445Z.dlist   ...211446Z.dlist    <- both already there
```

Two things hold in both. **The last backup adds nothing** — `added=0 modified=0` — and in
the second it wrote no log messages at all and the extra dlists were already at the
destination before it started. So the last backup is not where this goes wrong; whatever
happens, happens in the interrupted runs before it.

The first signature is a synthetic filelist: `UploadSyntheticFilelist` uploads one when
the interrupted run's dlist volume is left in `Uploading` or `Temporary`
(`UploadSyntheticFilelist.cs:58`), and being partial it then forces the last backup to
upload a fileset of its own through `lastWasPartial`
(`UploadRealFilelist.cs:49`). Whether the volume is left in that state or is cleaned to
`Deleting` and deleted is decided in `BackupHandler.cs:257-286`.

The second is a dlist from an interrupted run that survived: with `before=false` the put
completes and the error is thrown after it, so the file is really there.

Both outcomes are arguably correct product behaviour. What the test asserts is an exact
fileset count that assumes neither happens.

## The one thing that is settled

Round 7 gave each interrupted run a sink that records its completed backend puts, which
costs nothing to observe — unlike listing the destination, which is itself a delay and is
why round 4's zero proves nothing. Across 142 runs of case `(False,False,3,True)`:

| did the first interrupted run throw? | result | count |
|---|---|---|
| no | PASS | 136 |
| **yes** | **FAIL** | **6** |

**No exceptions in either direction.** The failure is exactly the runs where the first
interrupted run threw.

That narrows it sharply. The deterministic backend fails only a put of a `.dlist.`, so a
run that threw is a run that tried to upload a fileset. `UploadRealFilelist` decides that
at `UploadRealFilelist.cs:49`:

```csharp
var doUpload = options.UploadUnchangedBackups || changeCount > 0 || lastWasPartial;
```

`upload-unchanged-backups` is off by default, so with the source unchanged the cause is
one of the other two: something looked changed, or the previous backup looked partial.
The passing runs never throw, which is what an unchanged source should do — a run with
nothing to upload never reaches the error at all.

For the record, `withBase=false` throws on every single run, 140 of 140, in all four of
those cases. There is a real first backup to upload there, so that is expected and it is
only the `withBase=true` cases that are anomalous when they throw.

### Which of the two is still open

A local probe answered half of it. Twelve plain backups, each followed by the query
`GetIncompleteFilesetsAsync` runs — filesets whose remote volume is `Uploading` or
`Temporary` and which hold an entry — came back:

```
run 1..12: incomplete=0  | volumes: Blocks/Verified=1, Files/Verified=1, Index/Verified=1
```

**Twelve of twelve leave everything Verified.** So a backup that completes does not, by
itself, leave behind the state that becomes `lastWasPartial`. That weakens the second
explanation without eliminating it, since the test runs both backups in one process and
this probe used two.

Separating them needs one more observation: whether the first interrupted run logs
anything about a synthetic filelist. `UploadSyntheticFilelist` reads the same volume state
that becomes `lastWasPartial`, so it speaks when that state is the reason and is silent
when a change count is. The probe branch carries that instrumentation; catching it needs
the anomaly to appear.

## A hypothesis the evidence did not support

The two surviving dlists in the second signature are **one second apart**, which is what
the collision handling in `BackupHandler.cs:679` produces when two filesets want the same
second. The loop sleeps three seconds between the interrupted runs — the comment says
"Prevent clashes in timestamps" — but nothing separates the base backup from the first of
them.

Round 5 tested this properly: five shards slept three seconds after the base backup and
five did not, from one commit and one build in one run, differing by that and nothing
else. Both arms ran (960 probes each, confirmed by a marker in the output).

**Both arms: zero failures in sixty iterations.** The control arm produced no failures
either, so the experiment had no power — it does not show the gap is irrelevant, it shows
the failure did not appear at all that day.

Round 8 repeated it on the sharper signal from round 7 — whether run 1 throws, which fires
at 4.2% against the whole test's 1.6% — and got the same nothing: every one of the eight
completed shards reported exactly 168 throws of 224 observations, the count for the six
cases that always throw, in both arms. **Zero anomalies in 112 iterations.**

So the hypothesis has been put to a controlled test twice and neither test could see. It
is unsupported, not disproved, and it has now cost 232 iterations of macOS CI. The local
probe above, which found no completed backup leaving an unsettled volume, argues against
it separately and for less.

Round 4's zero is worth the same caution: it had added a directory listing after every
step, and a listing is a delay, which is the thing under suspicion.

## Where this leaves it

The obstacle is not the analysis, it is the rate. It moves between days by more than the
experiments can see through — three failures in seventy-one one day, none in a hundred and
twelve the next, same code, same configuration, same signal. A controlled comparison needs
the control arm to fail, and it will not do so on demand.

What is established is worth stating plainly: **the test fails exactly when the first
interrupted run decides to upload a fileset it should have had no reason to upload.** What
is not established is which of the two remaining terms of `doUpload` made it do so.

### What the instrumentation cannot do

The probe branch already carries what would answer the last question: each interrupted run
records whether `UploadSyntheticFilelist` said anything, and that distinguishes
`lastWasPartial` from a change count. It has now sat through 212 iterations without the
anomaly appearing, so it has never had the chance to speak. **More rounds of the same are
not worth the CI.**

Note also that none of this reaches the ordinary test job even when it does fail there.
The probe prints through `TestContext.Progress`, which only exists on the probe branch; the
upstream job's log keeps the assertion and nothing else. So an occurrence upstream teaches
nobody anything, which is the thing most worth changing.

Ways forward that do not need the last step:

- **Make the disruption deterministic.** `--synchronous-upload` (default false) takes the
  concurrency out of the upload path, so what is at the destination when the error is
  thrown stops depending on what was still in flight. Small, and aimed at the actual
  source of variation. Unproven as a fix, because verifying it needs the failure to be
  reproducible.
- **Assert something that does not depend on the race.** Both extra filesets are
  defensible product behaviour — a synthetic filelist preserves an interrupted run's
  progress, and a `PutAfter` dlist really did upload before the error. The exact count is
  what is brittle.
- ~~**Make the failure say what happened.**~~ **Done — #7177, merged 2026-08-17.** The
  assertion used to print two numbers; it now names the versions with their timestamps and
  whether each is partial, plus the added and modified counts. This fixed nothing, and it was
  the only one of the three that was certain to help.

Either would be honest only if the PR says the fix is unverified, for the same reason
everything else here is: the failure cannot be summoned.

Raising the failure rate deliberately — running the test against a loaded machine — would
make either of those testable, and is the thing to try before spending more CI on
repetition alone.

## Scripts

- `triage/incomplete-probe.sh`, `triage/incomplete-check.py` — run a plain backup and ask
  the database the question the next backup asks, which is whether any fileset is left
  looking interrupted. Needs no macOS and no race.
- The probe branch was `probe/dlist-flake` on the fork, one commit per round. **Deleted
  2026-08-17** — see the status note at the top.
