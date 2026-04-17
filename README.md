# PowerUnRar for macOS

PowerUnRar is a macOS archive extractor rebuilt on top of the open-source [mcnahum/zipper](https://github.com/mcnahum/zipper) project. It keeps the bundled `7zz` extraction engine from that codebase, but replaces the original compression-focused UI with a dedicated sequential RAR extraction workflow.

## Features

- scans a dedicated folder, defaulting to `/Volumes/BD`
- lists only archive files in that folder, not in subfolders
- groups multi-part RAR sets into a single queue item
- lets you select the archive sets to process
- extracts archives one by one into automatically created destination folders
- keeps a live queue with running progress, current file details, and green/red completion states
- produces a final extraction report after the queue finishes
- supports light, dark, and auto appearance modes

## Building

```bash
xcodegen generate
open PowerUnRar.xcodeproj
```

The build number is incremented automatically during target builds through `Scripts/increment_build_number.sh`.
