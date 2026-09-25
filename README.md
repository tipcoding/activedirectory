# New File Menu

A small macOS app that adds a **New File** item to Finder's right-click menu.
Right-click the background of a Finder window (or a folder/file) and pick a file
type; a new file such as `untitled.txt` is created and selected. Existing names
are never overwritten (`untitled 2.txt`, `untitled 3.txt`, ...).

Built-in types: Text, Markdown, Rich Text, HTML, JSON, Python, Shell script,
Swift and an empty file with no extension.

## Requirements

- macOS 12 or later
- Xcode 14 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`, or `build.sh` installs it)

## Build and install

```bash
./build.sh
```

This generates the Xcode project, builds a Release build, copies it to
`/Applications`, enables the Finder extension and restarts Finder.

To work in Xcode instead: `xcodegen generate && open NewFileMenu.xcodeproj`,
then run the `NewFileMenu` scheme.

## Enable the extension

If the menu does not appear, open the app and click **Open Extension
Settings…**, then turn on **New File Menu**:

- macOS 15+: System Settings › General › Login Items & Extensions › File Providers / Finder
- macOS 13–14: System Settings › Privacy & Security › Extensions › Added Extensions
- macOS 12: System Preferences › Extensions › Finder Extensions

Or from Terminal:

```bash
pluginkit -e use -i com.example.NewFileMenu.FinderExtension
killall Finder
```

## Customize

- **File types:** edit `FileTemplate.all` in `Shared/FileTemplate.swift`.
- **Bundle IDs:** change `com.example.NewFileMenu` in `project.yml` (and in `build.sh`).
- **Signing:** the project is ad-hoc signed for local use. Set `DEVELOPMENT_TEAM`
  in `project.yml` to your Apple team ID to sign with your certificate.

## How it works

The app hosts a [Finder Sync extension](https://developer.apple.com/documentation/findersync)
(`FinderExtension/FinderSync.swift`) that watches `/` and returns a context menu for
`.contextualMenuForContainer` and `.contextualMenuForItems`. The target folder is the
clicked folder, the parent of a clicked file, or the folder shown in the window.
Finder Sync extensions must be sandboxed, so the extension uses a
`temporary-exception.files.absolute-path.read-write` entitlement to write to any
folder. That entitlement is fine for personal use or direct distribution but is not
accepted on the Mac App Store.
