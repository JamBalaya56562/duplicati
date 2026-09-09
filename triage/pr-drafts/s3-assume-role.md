The S3 backend can only sign its requests with the access key it is given, so a bucket that is reached through an IAM role cannot be used (#2504).

## The change

- `--s3-assume-role-arn`: the aws client assumes that role with the access key (`AssumeRoleAsync` of STS), and signs the requests with the temporary credentials of the role.
- The credentials come from the new `S3AssumeRoleCredentials`, a `RefreshingAWSCredentials`. They are requested again 5 minutes before they expire (15 minutes when STS gives no expiry), so a long backup keeps going.
- `--s3-assume-role-session-name` (default `duplicati`) and `--s3-assume-role-external-id` are sent with the request.
- `--s3-sts-endpoint` points at another STS, such as the one of a MinIO server. Without it, the global AWS endpoint or the one of the auth region is used.
- The minio client refuses a role (`S3AssumeRoleNotSupportedByMinio`), as it would reach the bucket with the access key instead.

This adds the `AWSSDK.SecurityToken` package, 4.0.100.4. It is the version that goes with the `AWSSDK.Core` 4.0.100.5 already used, and was released on the same day as the `AWSSDK.IdentityManagement` 4.0.100.4 that the project already has.

## Testing

New `S3AssumeRoleTests`, 6 tests, with a fake STS and S3 on one `HttpListener`:

- requests are signed with the temporary key and carry `x-amz-security-token`, and STS gets the role ARN and the default session name
- the session name and the external id reach STS
- credentials close to their expiry are requested again, and ones with time left are not
- without a role, the access key is used and STS is not called
- the minio client refuses a role

All 6 pass. With the other S3 and option tests, 89 tests pass. No new warnings in the S3 project.

Not tried: a real AWS account, and the STS of MinIO.

Fixes #2504

🤖 Generated with [Claude Code](https://claude.com/claude-code)
