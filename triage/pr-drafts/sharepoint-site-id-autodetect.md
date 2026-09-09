Title: Find the SharePoint v2 site from the url without --site-id

## Summary

The SharePoint v2 backend can find the site from a url like `sharepoint://tenant-my.sharepoint.com/personal/user//Documents/folder`: `GetRootPathFromUrlAsync` looks the site up by the part before `//` and stores its id. But the constructor threw "No site ID was provided" whenever `--site-id` was missing, so that lookup never ran and `--site-id` was required in practice.

The constructor no longer throws. The drive path is now worked out the first time it is needed:

- With `--site-id`, it is built from the option, as before.
- Without it, the root path is resolved first (this runs the site lookup), and the site id found there is used.
- If no site is found either way, the same "No site ID was provided" error is thrown, now from the first operation instead of the constructor.

To test this without a network, the Graph backend gets a constructor that takes the message handler in place of the authenticating one (`private protected` in `MicrosoftGraphBackend`, `internal` in `SharePointV2`), and the `OAuthHttpClient` constructor that takes an `OAuthHttpMessageHandler` is now public. The public `(url, options)` constructors are unchanged, so `BackendLoader` still creates the backend the same way. `RootPath` in `MicrosoftGraphBackend` is now `protected` so `SharePointV2` can resolve it.

Commit: [0708e8f32fdb6079adb80abde2851f6cadb489a0](https://github.com/JamBalaya56562/duplicati/commit/0708e8f32fdb6079adb80abde2851f6cadb489a0)

Fixes #3948

## Testing

New `SharePointV2SiteIdTests`, with a stub message handler that answers the Graph requests:

- `TheSiteIsFoundFromTheUrlWithoutASiteIdOptionAsync`: lists a personal-site url without `--site-id` and asserts that the list request goes to `/v1.0/sites/{found id}/drive/root:/Vhds:/children`.
- `AUrlThatNamesNoSiteStillNeedsTheSiteIdOption`: a url with no site still fails with `SharePointMissingSiteId`.
- `TheLoaderCanStillCreateTheBackend`: `Activator.CreateInstance(type, url, options)` still works, as `BackendLoader` uses it.

Before the change, the first two tests failed with `UserInformationException: No site ID was provided` thrown by the constructor. After the change, `SharePointV2SiteIdTests` and `OneDriveUrlTests` pass (15 passed, 0 failed). The build has no new warnings.

Not tested against a real SharePoint tenant.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
