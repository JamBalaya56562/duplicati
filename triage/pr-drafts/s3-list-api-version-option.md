## Summary

The S3 backend declares `--s3-list-api-version` (`v1`/`v2`), but `S3AwsClient` looked up a different key, `list-api-version`. Setting `--s3-list-api-version=v2` therefore had no effect: the AWS client always sent a V1 `ListObjects` request (`GET /bucket/?delimiter=%2F&max-keys=1000&prefix=pfx%2F`), and only the undeclared `--list-api-version=v2` switched it to `list-type=2`. The mismatch has been there since both keys were added in [1716d09b5175728d478cc2687867bf2c4dfd8e37](https://github.com/duplicati/duplicati/commit/1716d09b5175728d478cc2687867bf2c4dfd8e37).

- The AWS client now reads `--s3-list-api-version`. The constant lives on `S3AwsClient`, next to `S3_ARCHIVE_CLASSES_OPTION`, and `S3Backend` uses it for the option declaration, so the two cannot drift again.
- `--list-api-version` was the only way to get V2 listing until now, so anyone who found it keeps working: it is still read when `--s3-list-api-version` is not set. It is now declared as a deprecated option, so using it logs "The option --list-api-version has been deprecated: The option list-api-version is deprecated, use s3-list-api-version instead." instead of "not supported and will be ignored".
- The MinIO client is unchanged: it never read either key.

Commit: [7cc10fa0a0376175d53c17995cad15a119945727](https://github.com/JamBalaya56562/duplicati/commit/7cc10fa0a0376175d53c17995cad15a119945727)

## Testing

New `S3ListApiVersionOptionTests` points the real `S3` backend (`s3-client=aws`) at an in-process `HttpListener` that records each request URL and returns an empty bucket listing.

- `ListUsesV1ApiByDefault`: no option → no `list-type=2`
- `ListUsesV2ApiWhenS3ListApiVersionIsV2`: `s3-list-api-version=v2` → `list-type=2`
- `ListUsesV2ApiWhenLegacyListApiVersionIsV2`: `list-api-version=v2` → `list-type=2` (also passes before the fix; it guards the fallback)
- `S3ListApiVersionTakesPrecedenceOverLegacyOption`: `s3-list-api-version=v1` + `list-api-version=v2` → no `list-type=2`
- `ListRemoteWarnsThatLegacyListApiVersionIsDeprecated`: runs `Controller.ListRemoteAsync` with `list-api-version=v2` and checks both the V2 request and the deprecation warning

With the S3 backend sources from master 85d15280 and the new tests:

```
Failed ListRemoteWarnsThatLegacyListApiVersionIsDeprecated
  Expected: some item String containing "--list-api-version" and String containing "s3-list-api-version"
  But was:  < "The supplied option --list-api-version is not supported and will be ignored" >   (localized in the run)
Failed ListUsesV2ApiWhenS3ListApiVersionIsV2
  Expected: String containing "list-type=2"
  But was:  "/test-bucket/?delimiter=%2F&max-keys=1000&prefix=pfx%2F"
Failed S3ListApiVersionTakesPrecedenceOverLegacyOption
  Expected: not String containing "list-type=2"
  But was:  "/test-bucket/?list-type=2&delimiter=%2F&max-keys=1000&prefix=pfx%2F"
Failed: 3, Passed: 2, Total: 5
```

With the fix, together with `S3BackendEndpointParsingTests`:

```
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "FullyQualifiedName~S3ListApiVersionOptionTests|FullyQualifiedName~S3BackendEndpointParsingTests"
Passed! - Failed: 0, Passed: 15, Skipped: 0, Total: 15
```

The S3 backend and unit test projects build with 0 warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
