## Summary
The CloudStack live test of #7967 failed on macOS ([job](https://github.com/duplicati/duplicati/actions/runs/44900004067/job/136833730604)). In the fourth run, an uploaded file was still missing from the listing after the backend tester had read the listing again 3 times:

```
File listing does not match yet (1 problem(s)), re-checking in 1000 ms
File listing does not match yet (1 problem(s)), re-checking in 2000 ms
File listing does not match yet (1 problem(s)), re-checking in 4000 ms
*** File 7 with name ... was uploaded but not found afterwards
```

The third run of the same job needed 3 re-checks too. An OpenStack Swift container listing is updated after the upload has returned, so it can lag behind.

The default of `--verification-retries` is now 5 instead of 3, so the re-checks wait up to 31 seconds in all instead of 7. They only wait when the listing does not match. The wait is computed in `GetVerificationDelay`, which both re-check loops use.

## Testing
- New test `BackendTesterVerificationTests.TheDefaultReChecksWaitLongEnoughForALaggingListing`. It adds up the waits of the default re-checks. With the old default of 3 it fails with `Expected: greater than or equal to 00:00:30`, `But was: 00:00:07`. With 5 it passes.
- Tests matching `BackendTester`: 29 passed. No new warnings.
- Not tested against a real Swift container, since the fork has no CloudStack credentials.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
