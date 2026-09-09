Title: Add an option to request S3 server-side encryption

There is no way to ask S3 to encrypt the stored objects on the server side (#2193).

## The change

- New option `--s3-server-side-encryption`: `none` (default), `AES256` for keys managed by the server, or `aws:kms` for keys of the key management service. A specific key can be given with `--s3-server-side-encryption-kms-key-id`.
- The `x-amz-server-side-encryption` header (and the KMS key id) is sent with each upload, and with the copy a rename makes, as a copy is encrypted as its request says rather than as its source is.
- Both S3 clients (AWS SDK and Minio) send it.
- An unknown value, or a key without `aws:kms`, is refused when the backend is created.

## Testing

New `S3ServerSideEncryptionTests` with a local stub S3 server (`HttpListener`), each for the AWS and the Minio client:
- Without the option, no encryption header is sent.
- `AES256`, and `aws:kms` with a key id, are requested for the uploads and for the copy of a rename.
- A KMS key without `aws:kms`, and an unknown value, are refused.

Not tried: a real S3 bucket with KMS.

Fixes #2193

🤖 Generated with [Claude Code](https://claude.com/claude-code)
