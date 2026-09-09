Fixes #4896

## Summary

On a Google Drive shared drive, a permanent delete needs the Manager (`organizer`) role. Users with the Content manager role get `403 Forbidden` whenever Duplicati deletes a remote file, for example an old dlist file. That role can move files to the trash.

This adds an opt-in backend option, `--googledrive-use-trash` (default `false`). When it is on, a delete sends `POST /drive/v2/files/{id}/trash?supportsAllDrives=true` with an empty body instead of `DELETE /drive/v2/files/{id}`. The backend uses Drive API v2, so this uses the v2 `files.trash` endpoint.

- The file listing already asks for `trashed=false`, and every name lookup goes through the same listing, so trashed files do not come back in the listing or in the verification.
- The duplicate-name cleanup in `PutAsync` and the delete step of `RenameAsync` go through `DeleteAsync`, so they follow the option too.
- Without the option, nothing changes.

## Testing

- New `GoogleDriveUseTrashTests` run offline, with a stub `HttpMessageHandler` passed through the existing internal constructor. They check the requests that `ListAsync` and `DeleteAsync` send:
  - option on (personal drive and shared drive): one `POST https://www.googleapis.com/drive/v2/files/file-1/trash?supportsAllDrives=true` with an empty body
  - option off or not set (personal drive and shared drive): one `DELETE /drive/v2/files/file-1`
  - every list query contains `trashed=false`
  - the option is listed in `SupportedCommands` with the default `false`
- Without the change, 3 of the 7 tests fail (`Expected: <POST> But was: <DELETE>`, and the option is missing). With it, they all pass. On the current master, the new tests and the existing Google Drive and WebApi tests pass (29 of 29). The build adds no warnings.
- Not tested against a real shared drive. That a Content manager gets a 2xx response is based on the Drive API documentation, which says that trashing a shared-drive file needs at least `fileOrganizer` on the parent.
- The Google Drive page in duplicati/documentation (`backup-destinations/file-synchronization-providers/googledrive-destination.md`) documents `--googledrive-teamdrive-id`; the new option can be added there after this is merged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
