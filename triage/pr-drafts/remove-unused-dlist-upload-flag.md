# PR draft: chore/remove-unused-dlist-upload-flag

Branch: `chore/remove-unused-dlist-upload-flag` on origin (JamBalaya56562/duplicati), one commit
[5aa5e1e9e8ec5bc32bf5102ed9800f1ec5dd8053](https://github.com/JamBalaya56562/duplicati/commit/5aa5e1e9e8ec5bc32bf5102ed9800f1ec5dd8053)
**stacked on `fix/repair-missing-filesets-upload-in-turn`**
([8d084333b7db6624a8dfbd7a4aa65a42eb4299e8](https://github.com/JamBalaya56562/duplicati/commit/8d084333b7db6624a8dfbd7a4aa65a42eb4299e8)),
which is stacked on `fix/rename-after-error-avoids-taken-name`.

Merge order: rename-after-error-avoids-taken-name → repair-missing-filesets-upload-in-turn → this one. Open each
only after the one below is merged, rebased onto master (no stacked PRs). It touches the lines next to the
previous fix, and the reason the block can go is that fix.

## Title

Remove the never-set anyDlistUploads flag in repair

## Body

`RepairHandler.RunRepairRemoteAsync` declares `var anyDlistUploads = false;` before re-uploading the dlists of
filesets without a registered volume, and after the loop waits for the backend, flushes and commits only
`if (anyDlistUploads)`. Nothing ever sets the flag. It came in with
[55fc5d2e6c498ccd2ced3a32b594a6d1531a50d3](https://github.com/duplicati/duplicati/commit/55fc5d2e6c498ccd2ced3a32b594a6d1531a50d3)
(2025-03, "Added support for recreating filesets and remote lists in some scenarios") already unset, and no
later commit on master set it (`git log -S anyDlistUploads`). So the block has never run.

The intent was clearly to wait for the uploads started in the loop. After #<repair-missing-filesets-upload-in-turn>,
the loop uploads with `waitForComplete: true` and flushes in `onDbUpdate`, including the `Uploaded` state after
each upload (`PutOperation.PerformUploadAsync`). When the loop ends, nothing is queued and nothing is waiting to
be flushed. Setting the flag would only add a commit in the middle of the repair, and the repair commits at the
end (`CommitRepairTransaction`) as it always has.

This removes the flag and the block. No change in behaviour: the code removed never ran.

### Testing

- `Duplicati.slnx` builds with 0 warnings.
- `RenameAfterErrorTests` (including `RepairRetriesOfTwoDlistsDoNotTakeTheSameNameAsync`, which goes through this
  loop), `RepairHandlerTests`, `RepairFilesetTimestampTests`: 30 of 30 pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
