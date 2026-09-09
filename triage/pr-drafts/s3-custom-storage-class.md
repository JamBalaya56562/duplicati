## What happens

In the old web UI (`ngax`), choosing "Custom storage class" for an S3 destination and typing a class name does not stick: after saving, the destination has no storage class, and it shows the default again.

The "Custom storage class" entry is the empty option of the select, so choosing it sets `scope.s3_storageclass` to `null`, and the typed name goes into `scope.s3_storageclass_custom`. The S3 URL builder only wrote `s3-storage-class` when `s3_storageclass != null`, so the custom name was never written. The region right above it has an `else if (scope.s3_region_custom != null)` branch for the same case; the storage class did not.

## The change

Add the same `else if` for the storage class: when no listed class is selected, write the custom value.

## Red to green

There is no test framework for the `ngax` scripts, so this was checked by hand in a browser against a server running the web root from this branch (`--webservice-webroot`), with an S3 job using placeholder credentials (nothing connects to S3). `CUSTOM_TEST_CLASS` is used as the custom name because the server's list already contains `GLACIER_IR`, the class from #4882.

| | Before | After |
|---|---|---|
| Choose "Custom storage class", type `CUSTOM_TEST_CLASS`, save | **red**: no `s3-storage-class` in the saved URL | `s3-storage-class=CUSTOM_TEST_CLASS` |
| Open the job again | (nothing to show) | "Custom storage class" selected, the field holds `CUSTOM_TEST_CLASS`; saving unchanged keeps it |
| Choose "Standard (STANDARD)" from the list, save | `STANDARD` | `STANDARD` |

An empty custom name is written as `s3-storage-class=`, which is what the "(default)" entry already writes.

The new UI does not have this: there the storage class is an advanced option that takes free text, and saving `CUSTOM_TEST_CLASS` puts `s3-storage-class=CUSTOM_TEST_CLASS` in the URL (checked in the browser). #4882, the same report for `GLACIER_IR`, was closed as fixed in the new UI.

Fixes #3750

🤖 Generated with [Claude Code](https://claude.com/claude-code)
