I think this was fixed in 2.3.0.0 (stable) and 2.2.1.0 (beta) by 0b79785f0703f1194308e6cef08bbd3e40ff032c. Since that change, the AWS client signs with the region from the region field (`s3-location-constraint`) when `--s3-authentication-region` is not set.

I tested against MinIO set to region `fr-par` (`MINIO_REGION=fr-par`), with `Duplicati.CommandLine.BackendTool LIST` and the default AWS client:

- 2.0.5.1, with the region set to `fr-par`: "The authorization header is malformed; the region is wrong; expecting 'fr-par'". The MinIO client worked, as reported above.
- 2.2.0.3 (stable), with the region set to `fr-par`: the same error.
- 2.3.0.0 and 2.4.1.0 (stable), with the region set to `fr-par`: the bucket was listed.
- Without a region, 2.4.1.0 still fails with the same message, as expected for a server that requires `fr-par`.

For the old releases I used the official Docker images. On current master, `--s3-authentication-region=fr-par` also works on its own.

If nobody still sees this on 2.3.0.0 or later, I think it can be closed.
