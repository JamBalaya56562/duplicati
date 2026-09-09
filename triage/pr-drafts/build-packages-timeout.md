# PR draft: ci/build-packages-timeout

Branch: `ci/build-packages-timeout` (JamBalaya56562/duplicati), commit [36ceb1526536c612e65faf4955a19789842c5c33](https://github.com/JamBalaya56562/duplicati/commit/36ceb1526536c612e65faf4955a19789842c5c33), based on upstream master 71981c36.

## Title

ci: limit Build packages jobs to 150 minutes

## Body

The Build packages job had no `timeout-minutes`, so a stalled build holds the runner for GitHub's 6 hour default. That happened on #7539: the windows-latest job ([run 39986637787](https://github.com/duplicati/duplicati/actions/runs/39986637787/job/120527404050)) printed `Building linux-arm7-cli ...` and then nothing until it was cancelled at the 6 hour limit (step "Compile releases" ran 16:25:40 → 22:25:52).

This sets `timeout-minutes: 150` on the job.

Durations of the last 40 runs of this workflow (2026-10-22 to 2026-10-24, 79 successful jobs, from `gh run list` + the jobs API):

| | jobs | min | median | max |
|---|---|---|---|---|
| macos-latest | 40 | 33 | 63 | 86 |
| windows-latest | 39 (+1 hung) | 36 | 71 | 75 |

150 minutes is about 1.75× the slowest successful job, so normal runs keep plenty of headroom while a hang now fails after 2.5 hours instead of 6.

Checked with actionlint 1.7.12 (no findings; a non-numeric value in the same place is rejected, so the key is validated).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
