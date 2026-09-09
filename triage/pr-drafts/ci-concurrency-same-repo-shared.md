Follow-up to #7431, which made overlapping live test runs from branches of this repository cancel each other, as @kenkendk noted in https://github.com/duplicati/duplicati/pull/7431#issuecomment-6096409667.

## What happens

#7431 ([`93737a08`](https://github.com/duplicati/duplicati/commit/93737a08c985c7d81a50d0a69b178ee9c9f273bb)) gave each run of `backendtests.yml` and `secretprovidertests.yml` a group per pull request, and each job that uses the repository's secrets a group per job and runner. GitHub keeps one running and one waiting job per group, and a newer waiting job replaces the older one. When three runs or more from branches of this repository overlap, the waiting order differs from job to job, so every run loses some jobs to another run and ends cancelled, hours after it started.

For example, [run 37943017780](https://github.com/duplicati/duplicati/actions/runs/37943017780) (`feature/fix-tray-after-avalonia-update`) ran from 14:17 to 20:32 on 10-09: 40 jobs passed, and 10 were cancelled without running a step, with `Canceling since a higher priority waiting request for duplicati-ci-livetests-test_onedrive-windows-latest exists`. In the first six runs from branches of this repository that ended cancelled after the merge, 70 jobs were cancelled this way. Pull requests from forks were not affected, as they skip the jobs that use the secrets.

## The change

- Runs from branches of this repository, and manual runs, share one group for the whole repository again (`duplicati-ci-livetests`, `duplicati-ci-secretprovidertests`, `cancel-in-progress: false`), as before #7431.
- The job groups are removed.
- Pull requests from forks keep a group per pull request with `cancel-in-progress: true`, so they run side by side and a newer run for the same pull request replaces the older one. The choice is made from `github.event.pull_request.head.repo.full_name`.

## Checked

`actionlint` reports nothing for either file.

On my fork, with pull requests inside the fork (so from the same repository):

- Three pull requests opened within 12 seconds: in both workflows the first ran, the second was cancelled 8 seconds after it was created without running a job (`Canceling since a higher priority waiting request for duplicati-ci-livetests exists`, and `duplicati-ci-secretprovidertests` for the other workflow), and the third waited until I cancelled the first, then started. This is the behaviour before #7431.
- The same with a test-only commit that inverts the `head.repo.full_name` comparison, so the pull requests take the fork path: all three ran side by side, and a second push to one of them cancelled its earlier run with `Canceling since a higher priority waiting request for Backend Live Tests-5 exists`.

The test pull requests and branches are closed and deleted.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
