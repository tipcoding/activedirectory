import Foundation

/// A kind of file that can be created from the Finder context menu.
/// Edit `FileTemplate.all` to add, remove or reorder menu entries.
struct FileTemplate {
    let title: String
    let baseName: String
    let fileExtension: String
    let contents: String
    var executable: Bool = false

    var fileName: String {
        fileExtension.isEmpty ? baseName : "\(baseName).\(fileExtension)"
    }

    static let all: [FileTemplate] = [
        FileTemplate(title: "Text File", baseName: "untitled", fileExtension: "txt", contents: ""),
        FileTemplate(title: "Markdown File", baseName: "untitled", fileExtension: "md", contents: "# Untitled\n"),
        FileTemplate(title: "Rich Text Document", baseName: "untitled", fileExtension: "rtf",
                     contents: "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2639\n{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n\\f0\\fs24 \\\n}\n"),
        FileTemplate(title: "HTML File", baseName: "index", fileExtension: "html",
                     contents: """
                     <!DOCTYPE html>
                     <html lang="en">
                     <head>
                       <meta charset="utf-8">
                       <title>Untitled</title>
                     </head>
                     <body>
                     </body>
                     </html>

                     """),
        FileTemplate(title: "JSON File", baseName: "untitled", fileExtension: "json", contents: "{\n}\n"),
        FileTemplate(title: "Python Script", baseName: "script", fileExtension: "py",
                     contents: "#!/usr/bin/env python3\n\n", executable: true),
        FileTemplate(title: "Shell Script", baseName: "script", fileExtension: "sh",
                     contents: "#!/bin/bash\nset -euo pipefail\n\n", executable: true),
        FileTemplate(title: "Swift File", baseName: "untitled", fileExtension: "swift", contents: "import Foundation\n\n"),
        FileTemplate(title: "Empty File", baseName: "untitled", fileExtension: "", contents: ""),
    ]
}
