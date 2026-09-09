## Summary

`S3AwsClient.ListBucketAsync` pages through listings of more than 1000 objects, but no test covered that loop. This adds `S3AwsClientPaginationTests`, which points the real `S3` backend (`s3-client=aws`) at an in-process `HttpListener`. The listener serves a two-page listing and records each request's query.

- `V2ListFollowsContinuationToken`: the second `list-type=2` request carries the `NextContinuationToken` from page 1
- `V1ListFollowsNextMarker`: the second V1 request sends `marker=` set to the page-1 `NextMarker`
- `V1RecursiveListContinuesAfterLastKeyWithoutNextMarker`: with `--s3-recursive-list` no delimiter is sent, and S3 then returns no `NextMarker`. The AWS SDK fills it in from the last key, so the second request still sends `marker=pfx/a.txt`. This pins that SDK behaviour, which the loop depends on.

Each test also checks that both files are returned. The fake server stops a client after 5 requests, so a broken loop fails instead of hanging.

Commit: [8337fd362ee28cd7f0a235f835e1a3fe72910e3b](https://github.com/JamBalaya56562/duplicati/commit/8337fd362ee28cd7f0a235f835e1a3fe72910e3b)

## Testing

On master 85d15280:

```
dotnet test Duplicati/UnitTest/Duplicati.UnitTest.csproj --no-build --filter "FullyQualifiedName~S3AwsClientPaginationTests"
Passed! - Failed: 0, Passed: 3, Skipped: 0, Total: 3
```

To check that the tests can fail, `filename = listResponse.NextContinuationToken;` in `S3AwsClient.ListBucketAsync` was temporarily replaced with `filename = null;`. All three tests then failed:

```
Failed V1ListFollowsNextMarker                                 Expected: property Count equal to 2  But was: 6
Failed V1RecursiveListContinuesAfterLastKeyWithoutNextMarker   Expected: property Count equal to 2  But was: 6
Failed V2ListFollowsContinuationToken                          Expected: property Count equal to 2  But was: 6
```

The build reports 0 warnings.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
