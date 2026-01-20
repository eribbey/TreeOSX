# SwiftTree

SwiftTree is a fast, native macOS disk usage analyzer inspired by WizTree. It scans a chosen folder or volume and renders a treemap plus a sortable table to quickly surface large files and folders.

## Features
- **Fast scanning** using low-overhead POSIX syscalls with `getattrlistbulk` batching and a fallback to `readdir`/`fstatat`.
- **Accurate sizes** for both logical size (`st_size`) and allocated size (`st_blocks * 512`).
- **Interactive UI** with a zoomable treemap, sortable table, breadcrumbs, search, and Finder actions.
- **Graceful error handling** for permission-denied paths.
- **Snapshot persistence** so the last scan loads instantly while a new scan runs.
- **CLI companion** (`swifttree`) for batch scans and JSON output.

## Requirements
- macOS 13+
- Xcode 15+ (or Swift 5.9 toolchain)

## Build & Run (App)
1. Open the repository in Xcode.
2. Select the `SwiftTreeApp` scheme.
3. Build and run.

## Build & Run (CLI)
```bash
swift build -c release
.build/release/swifttree scan ~/ --json ~/swifttree.json --metric allocated
```

## Permissions
Some folders require **Full Disk Access**. If a scan shows many permission errors or missing data, grant Full Disk Access to SwiftTree in **System Settings → Privacy & Security → Full Disk Access** and rescan.

## Benchmarking
Use the CLI tool and note the timing/throughput output:
```bash
.build/release/swifttree scan /Applications --metric allocated
```

## Performance Notes
- **Directory traversal:** `getattrlistbulk` reduces syscall overhead by fetching multiple entries in a single call. When unsupported, the scanner falls back to `readdir` + `fstatat`.
- **Concurrency:** a bounded worker pool scans multiple subtrees in parallel to improve throughput without overwhelming memory.
- **Allocations:** names are buffered in a reusable C buffer and decoded to Swift Strings only when needed.
- **Cancellation:** the scanner checks for cancellation between directory batches for fast stop behavior.

## APFS & Allocation Size Limitations
- `allocatedBytes` is derived from `st_blocks * 512` or `ATTR_FILE_ALLOCATEDSIZE` when available.
- APFS clones/snapshots/sparse files can produce differences versus `du` depending on filesystem semantics. SwiftTree reports the most reliable public API values available.

## Repository Layout (Full Tree)
```
Package.swift
README.md
App/
  SwiftTreeApp.swift
  ViewModels/
    ScanViewModel.swift
  Views/
    BreadcrumbView.swift
    ContentView.swift
    NodeTableView.swift
    StatusBar.swift
    TreemapView.swift
CLI/
  main.swift
Core/
  Formatters.swift
  Models.swift
  Scanner.swift
  SizeMetric.swift
  SnapshotStore.swift
  TreemapLayout.swift
CoreC/
  include/
    SwiftTreeCoreC.h
  src/
    SwiftTreeCoreC.c
Tests/
  CoreTests/
    ScannerTests.swift
```
