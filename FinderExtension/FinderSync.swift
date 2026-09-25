import Cocoa
import FinderSync

/// Adds a "New File" submenu to Finder's right-click menu.
class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // Watch the whole file system so the menu shows up everywhere.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Right-click on a window background, or on files/folders.
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }

        let menu = NSMenu(title: "")
        let submenu = NSMenu(title: "New File")
        for (index, template) in FileTemplate.all.enumerated() {
            let item = NSMenuItem(title: template.title, action: #selector(createFile(_:)), keyEquivalent: "")
            // Finder copies the menu, so only the title and tag survive.
            item.tag = index
            submenu.addItem(item)
        }

        let root = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        root.submenu = submenu
        menu.addItem(root)
        return menu
    }

    // MARK: - Actions

    @objc func createFile(_ sender: NSMenuItem) {
        let template = FileTemplate.all.indices.contains(sender.tag)
            ? FileTemplate.all[sender.tag]
            : FileTemplate.all.first { $0.title == sender.title }
        guard let template = template, let directory = targetDirectory() else { return }

        do {
            let url = try create(template, in: directory)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert(error: error)
                alert.messageText = "Could not create \(template.fileName)"
                alert.runModal()
            }
        }
    }

    /// Folder in which the new file goes: the clicked folder, the parent of a
    /// clicked file, or the folder shown in the Finder window.
    private func targetDirectory() -> URL? {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), selected.count == 1, let item = selected.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue,
               !isPackage(item) {
                return item
            }
            return item.deletingLastPathComponent()
        }
        return controller.targetedURL()
    }

    private func isPackage(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
    }

    private func create(_ template: FileTemplate, in directory: URL) throws -> URL {
        let url = uniqueURL(for: template, in: directory)
        try Data(template.contents.utf8).write(to: url, options: .withoutOverwriting)
        if template.executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return url
    }

    /// "untitled.txt", then "untitled 2.txt", "untitled 3.txt", ... like Finder does.
    private func uniqueURL(for template: FileTemplate, in directory: URL) -> URL {
        var url = directory.appendingPathComponent(template.fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            var name = "\(template.baseName) \(counter)"
            if !template.fileExtension.isEmpty { name += ".\(template.fileExtension)" }
            url = directory.appendingPathComponent(name)
            counter += 1
        }
        return url
    }
}
