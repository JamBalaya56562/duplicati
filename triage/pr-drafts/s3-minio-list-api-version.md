## Summary

#7483 made the AWS S3 client read `--s3-list-api-version`. The Minio client (`s3-client=minio`) never read the option at all: `S3MinioClient.ListBucketAsync` built `ListObjectsArgs` without `WithListObjectsV1(...)`, so it always listed with the Minio SDK default, v2 (`list-type=2`), even with `--s3-list-api-version=v1`.

- The Minio client now reads `--s3-list-api-version`, or the deprecated `--list-api-version` when that is not set, the same way the AWS client does after #7483, and passes it through `WithListObjectsV1`.
- When neither option is set, nothing is passed, so the Minio default of v2 is kept and existing setups are unaffected. The AWS client defaults to v1, so the two clients still differ when the option is not set; the help text now says that the Minio client uses v2 in that case.

Commit: [b2840c1ac9c1203e27c4f897f2d34275b44572a7](https://github.com/JamBalaya56562/duplicati/commit/b2840c1ac9c1203e27c4f897f2d34275b44572a7)

## Testing

New `S3MinioListApiVersionTests` constructs the real `S3` backend with `s3-client=minio` against an in-process `HttpListener` that records each request URL, then calls `ListAsync`:

- On master, `ListUsesV1ApiWhenS3ListApiVersionIsV1` and `ListUsesV1ApiWhenLegacyListApiVersionIsV1` fail: the request still has `list-type=2`.
- With this change, the 4 `S3MinioListApiVersionTests` and the 5 `S3ListApiVersionOptionTests` from #7483 pass.
- No new build warnings in the touched files.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
