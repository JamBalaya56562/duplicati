## What happens

In the old web UI (`ngax`), an S3 destination saved with `s3-client=minio` shows "Amazon AWS SDK" when the job is edited. Saving the job again, even without touching anything, writes `s3-client=aws`.

When an existing destination is opened, `reparseuri` (`backupEditUri.js`) sets `scope.Backend` and calls the S3 parser right away, which reads `s3-client` from the URL into `scope.s3_client`. The `$watch('Backend')` listener then runs in the next digest and calls the S3 loader, whose last lines set `scope.s3_client = s3_client_options[0]` without a condition. The loader always runs after the parser here, so the value read from the URL is replaced by `aws`, and the URL builder writes it back on save.

The other defaults in the same loader (server, region, storage class) are only set when nothing has been read.

## The change

The loader sets the default client only when no client has been read: `if (scope.s3_client == null)`.

## Red to green

There is no test framework for the `ngax` scripts, so this was checked by hand in a browser against a server running the web root from this branch (`--webservice-webroot`), with an S3 job created with `s3-client=minio` and placeholder credentials (nothing connects to S3).

| | Before | After |
|---|---|---|
| Edit the job, destination step | **red**: "Amazon AWS SDK" selected (`s3_client` is `aws`) | "Minio SDK" selected |
| Save without changes, then read the job's URL | **red**: `s3-client=aws` | `s3-client=minio` |
| New job, choose S3 | aws (default) | aws (default) |
| Edit the minio job, switch to "Amazon AWS SDK", save | (not reachable) | `s3-client=aws` |

The new UI does not have this: editing the same kind of job there shows "MinIO Library (minio)", and saving it unchanged keeps `s3-client=minio` (checked in the browser).

Fixes #4405

🤖 Generated with [Claude Code](https://claude.com/claude-code)
