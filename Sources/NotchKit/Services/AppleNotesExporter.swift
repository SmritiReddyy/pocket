import AppKit
import Observation
import os

/// Saves the scratchpad as a new note in the Notes app, in the Quick Notes folder. The note keeps
/// bold, italic, underline, bigger text and the colours you picked.
@MainActor
@Observable
public final class AppleNotesExporter {
    public enum State: Equatable {
        case idle
        case saving
        case saved
        /// macOS said no: Pocket isn't allowed to control Notes.
        case notAllowed
        case failed(String)
    }

    public private(set) var state: State = .idle
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: Log.subsystem, category: "notes-export")

    nonisolated public static let folderName = "Quick Notes"

    public init() {}

    /// Adds the note to Quick Notes, making the folder if it isn't there.
    public func save(_ note: NSAttributedString) {
        guard state != .saving else { return }
        guard !note.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        resetTask?.cancel()
        state = .saving
        let html = Self.html(from: note)
        Task { [weak self] in
            let result = await Task.detached { Self.runScript(body: html) }.value
            guard let self else { return }
            switch result {
            case .success:
                self.state = .saved
            case .failure(.notAllowed):
                self.state = .notAllowed
            case .failure(.other(let message)):
                self.log.error("Saving to Notes failed: \(message, privacy: .public)")
                self.state = .failed(message)
            }
            self.resetTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.state == .saved ? 2 : 6))
                guard !Task.isCancelled else { return }
                self?.state = .idle
            }
        }
    }

    /// Privacy & Security › Automation, where Pocket can be allowed to control Notes.
    public func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Script

    enum ExportError: Error, Equatable {
        case notAllowed
        case other(String)
    }

    /// The body arrives as an argument, so the note's text is never pasted into the script itself.
    nonisolated static let script = """
    on run argv
        set noteBody to item 1 of argv
        tell application "Notes"
            set target to missing value
            repeat with anAccount in accounts
                repeat with aFolder in folders of anAccount
                    if name of aFolder is "\(folderName)" then
                        set target to aFolder
                        exit repeat
                    end if
                end repeat
                if target is not missing value then exit repeat
            end repeat
            if target is missing value then
                set target to make new folder with properties {name:"\(folderName)"}
            end if
            make new note at target with properties {body:noteBody}
        end tell
    end run
    """

    nonisolated static func runScript(body: String) -> Result<Void, ExportError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, body]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return .failure(.other(error.localizedDescription))
        }
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return .success(()) }
        return .failure(classify(message))
    }

    /// osascript reports -1743 when the user hasn't allowed Automation for Notes.
    nonisolated static func classify(_ message: String) -> ExportError {
        if message.contains("-1743") || message.localizedCaseInsensitiveContains("not authorized") {
            return .notAllowed
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return .other(trimmed.isEmpty ? "Notes didn't respond." : trimmed)
    }

    // MARK: HTML

    /// The note as the simple HTML Notes takes for a note's body: one `<div>` a line, with bold,
    /// italic, underline, bigger text and colours kept. White text, the scratchpad's default on
    /// the black notch, is left uncoloured so it shows up on Notes' white page.
    nonisolated static func html(from note: NSAttributedString) -> String {
        let full = NSRange(location: 0, length: note.length)
        var smallest = CGFloat.greatestFiniteMagnitude
        note.enumerateAttribute(.font, in: full) { value, _, _ in
            if let font = value as? NSFont { smallest = min(smallest, font.pointSize) }
        }
        var lines: [String] = [""]
        note.enumerateAttributes(in: full) { attributes, range, _ in
            let pieces = (note.string as NSString).substring(with: range).components(separatedBy: "\n")
            for (index, piece) in pieces.enumerated() {
                if index > 0 { lines.append("") }
                guard !piece.isEmpty else { continue }
                lines[lines.count - 1] += styled(escape(piece), attributes, smallest: smallest)
            }
        }
        return lines.map { "<div>\($0.isEmpty ? "<br>" : $0)</div>" }.joined()
    }

    nonisolated private static func styled(_ text: String, _ attributes: [NSAttributedString.Key: Any], smallest: CGFloat) -> String {
        var result = text
        if let font = attributes[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            if traits.contains(.boldFontMask) { result = "<b>\(result)</b>" }
            if traits.contains(.italicFontMask) { result = "<i>\(result)</i>" }
            if font.pointSize > smallest * 1.2 { result = "<span style=\"font-size: 18px\">\(result)</span>" }
        }
        if (attributes[.underlineStyle] as? Int ?? 0) != 0 { result = "<u>\(result)</u>" }
        if let color = (attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.sRGB), !isWhite(color) {
            let hex = String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
            result = "<span style=\"color: \(hex)\">\(result)</span>"
        }
        return result
    }

    nonisolated private static func isWhite(_ color: NSColor) -> Bool {
        color.redComponent > 0.9 && color.greenComponent > 0.9 && color.blueComponent > 0.9
    }

    nonisolated private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
