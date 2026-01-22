# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftTree is a fast, native macOS disk usage analyzer that scans folders and volumes to identify large files and directories. It provides both a GUI macOS app and a CLI tool.

## Build Commands

```bash
# Build CLI (release)
swift build -c release

# Run CLI examples
.build/release/swifttree scan ~/ --json ~/swifttree.json --metric allocated
.build/release/swifttree scan /Applications --metric allocated

# Run tests
swift test

# Build GUI app - open in Xcode, select "SwiftTreeApp" scheme, build and run
```

## Architecture

**Targets (defined in Package.swift):**
- `SwiftTreeApp` - macOS GUI application (SwiftUI)
- `swifttree` - Command-line tool
- `Core` - Shared scanning library
- `CoreC` - C module for high-performance directory reading

**Key architectural decisions:**

1. **Performance-critical C bridge (CoreC/):** Uses `getattrlistbulk` on macOS for batched directory reading with fallback to `readdir` + `fstatat`. This is the primary performance optimization.

2. **Swift Actors for concurrency:** `TreeBuilder`, `WorkStream`, and `ProgressTracker` in Scanner.swift use actors for thread-safe state management during concurrent directory traversal.

3. **Two size metrics:** Logical size (`st_size`) vs allocated size (`st_blocks * 512`). The `SizeMetric` enum controls which is used.

4. **MVVM pattern in GUI:** `ScanViewModel` manages scan state; SwiftUI views in App/Views/ bind to published properties.

**Source layout:**
- `App/` - SwiftUI app with ViewModels and Views
- `CLI/` - Command-line tool entry point
- `Core/` - Scanner, Models, TreemapLayout, SnapshotStore
- `CoreC/` - C module with SwiftTreeCoreC.h/.c

## Platform Requirements

- macOS 13+ (primary), Linux compatible for Core/CLI
- Swift 5.9+ / Xcode 15+
- Full Disk Access permission required for unrestricted scanning on macOS
