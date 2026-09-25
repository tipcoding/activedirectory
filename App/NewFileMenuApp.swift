import FinderSync
import SwiftUI

@main
struct NewFileMenuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var enabled = FIFinderSyncController.isExtensionEnabled
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("New File Menu").font(.title2).bold()
                    Text("Create files from Finder's right-click menu.")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Circle()
                    .fill(enabled ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(enabled ? "Finder extension is enabled" : "Finder extension is not enabled")
            }

            if !enabled {
                Text("Turn on “New File Menu” under System Settings › Privacy & Security › Extensions › Added Extensions (older macOS: System Preferences › Extensions › Finder).")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Open Extension Settings…") {
                FIFinderSyncController.showExtensionManagementInterface()
            }

            Divider()

            Text("Right-click in any Finder window and choose New File ›").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(FileTemplate.all, id: \.title) { template in
                    HStack {
                        Text(template.title)
                        Spacer()
                        Text(template.fileName).foregroundColor(.secondary).font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .onReceive(timer) { _ in enabled = FIFinderSyncController.isExtensionEnabled }
    }
}
