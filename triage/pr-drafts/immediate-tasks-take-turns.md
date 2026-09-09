Title: Let the immediate tasks of a backup database take turns

A task that runs immediately, such as a listing of the restore tree, tried the lock of the backup database once and failed with `DatabaseLocked` when it was taken (`QueueRunnerService.RunImmediatelyAsync`). The new UI lists several folders at the same time when they are opened quickly. All but one of these listings then failed with "The backup database is currently in use by another operation", although nothing else was running. The response is HTTP 200 with `{"Success":false,"StatusCode":"DatabaseLocked"}`.

## The change

- Tasks that run immediately now wait for each other, one database at a time (a `SemaphoreSlim` per database), and then try the lock as before.
- A queued task such as a backup can hold the lock for a long time, so a listing still fails at once while one runs.

## Testing

- New tests in `ServerApiIntegrationTests`:
  - 12 listings of one backup at the same time all succeed. Before, 48 of 60 failed over 5 runs, and with 2 listings one failed every time.
  - A listing still fails at once while a backup holds the lock.
- In the web UI (ngclient 0.0.248, a server built with this change), opening three folders of the restore tree at the same time 5 times gave no error. All 11 list-folder responses had `"Success":true`. Before, 2 of 3 attempts showed the error.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
