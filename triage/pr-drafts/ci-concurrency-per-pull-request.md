## What happens

`backendtests.yml` and `secretprovidertests.yml` each use one concurrency group for the whole repository (`duplicati-ci-livetests`, `duplicati-ci-secretprovidertests`) with `cancel-in-progress: false`. GitHub keeps at most one run of a group waiting, and a newer one replaces it. When several pull requests are opened or updated at about the same time, the runs of all but the first and the last are cancelled without running any job.

That happened when #7426 to #7430 were opened within a minute: for #7426, both the secret provider tests and the backend live tests were cancelled, and so were the secret provider tests of #7427 and #7430 and the backend live tests of #7429. It also cancels the jobs that need no secrets, such as the file provider, libsecret and Testcontainers Vault tests, which are the ones that run for pull requests from forks.

## The change

- Each workflow has a group per pull request, or per branch for a manual run, with `cancel-in-progress: true`: a newer run for the same pull request replaces the older one, and runs for other pull requests are left alone.
- The jobs that run only with the repository's secrets, and so use the shared test accounts and secret stores, keep taking turns with the same job of other runs. They have their own group, named after the old one plus the job ID and the runner OS, with `cancel-in-progress: false`. The job ID is written out, as `github.job` is empty when a job's concurrency group is evaluated: with it, the jobs of one run shared a group per OS and cancelled each other. The jobs of one run still run side by side, as they did before, since their groups differ. In pull requests from forks these jobs are skipped.

The jobs with secrets can still have a waiting job replaced when three runs or more queue up for the same job, as before; only the jobs without secrets, and runs of other pull requests as a whole, are no longer affected.

## Checked

`actionlint` reports nothing for either file.

On my fork, which has no secrets except a placeholder Testcontainers token, I started `secretprovidertests.yml` by hand on three branches within a few seconds of each other. The runs with this change used an earlier version of it that differed only in the group names of the jobs with secrets, which are skipped there:

| | master | this change |
|---|---|---|
| first branch | ran | ran |
| second branch | **cancelled**, no job ran | ran |
| third branch | waited for the first, then ran | ran |
| the first branch again | | the earlier run on that branch was cancelled, the new one ran |

I then started `backendtests.yml` the same way, once on master and on two branches with this change. The fork's placeholder token lets the Testcontainers jobs (FTP, SFTP, SSH, WebDAV, CIFS) run; they pass on Ubuntu and fail on Windows and macOS in all three runs, master included, so those failures come from the fork. No job was cancelled. In each run with this change, the Ubuntu jobs started together, and each job of the second run started when the same job on the same OS of the first run had finished, for example FTP on Ubuntu at 19:26:23 after 19:26:21, CIFS at 19:27:02 after 19:26:59.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
