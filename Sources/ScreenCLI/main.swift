import ArgumentParser
import Foundation
import Vision
import Translation
import AppKit

@main
struct ScreenCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screencli",
        abstract: "Local screen translation and search CLI for macOS",
        subcommands: [Translate.self, Search.self],
        defaultSubcommand: Translate.self
    )
}

struct Translate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Translate the full current screen on-device"
    )
    
    @Option(name: .shortAndLong, help: "Target language code (e.g. zh, ja, fr)")
    var to: String = "en"
    
    @Flag(name: .long, help: "Copy result to clipboard")
    var copy = false
    
    @Flag(name: .long, help: "Output as JSON")
    var json = false
    
    func run() async throws {
        print("Capturing full screen...")
        let imageURL = try await captureFullScreen()
        print("Running OCR...")
        let text = try await performOCR(on: imageURL)
        guard !text.isEmpty else {
            print("No text found on screen.")
            return
        }
        print("Translating to \(to)...")
        let translated = try await translate(text: text, to: to)
        
        if json {
            let output: [String: Any] = [
                "original": text,
                "translated": translated,
                "target": to
            ]
            if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("\n--- Original ---")
            print(text)
            print("\n--- Translated ---")
            print(translated)
        }
        
        if copy {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(translated, forType: .string)
            print("\nCopied to clipboard.")
        }
        
        try? FileManager.default.removeItem(at: imageURL)
    }
}

struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Select a region of the screen, OCR it, and search on Google"
    )
    
    @Flag(name: .long, help: "Copy OCR text only (do not open browser)")
    var copy = false
    
    @Flag(name: .long, help: "Do not open browser")
    var noOpen = false
    
    func run() async throws {
        print("Select a region on screen (drag to select, Escape to cancel)...")
        let imageURL = try await captureInteractiveRegion()
        print("Running OCR...")
        let text = try await performOCR(on: imageURL)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("No text found in selection.")
            try? FileManager.default.removeItem(at: imageURL)
            return
        }
        
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Extracted text:\n\(cleaned)")
        
        if copy {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cleaned, forType: .string)
            print("Copied to clipboard.")
        }
        
        if !noOpen && !copy {
            let query = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleaned
            let url = URL(string: "https://www.google.com/search?q=\(query)")!
            NSWorkspace.shared.open(url)
            print("Opened Google search in default browser.")
        }
        
        try? FileManager.default.removeItem(at: imageURL)
    }
}

// MARK: - Helpers

func captureFullScreen() async throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let url = tempDir.appendingPathComponent("screencli-full-\(UUID().uuidString).png")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", url.path]  // -x no sound, full screen
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(domain: "ScreenCLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screen. Grant Screen Recording permission in System Settings > Privacy & Security."])
    }
    return url
}

func captureInteractiveRegion() async throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let url = tempDir.appendingPathComponent("screencli-region-\(UUID().uuidString).png")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-i", "-x", url.path]  // -i interactive selection
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(domain: "ScreenCLI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Selection cancelled or failed."])
    }
    return url
}

func performOCR(on imageURL: URL) async throws -> String {
    guard let cgImage = NSImage(contentsOf: imageURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "ScreenCLI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load captured image"])
    }
    
    return try await withCheckedThrowingContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            continuation.resume(returning: text)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

func translate(text: String, to target: String) async throws -> String {
    let source = Locale.Language(identifier: "en") // or detect; simplified for now
    let targetLang = Locale.Language(identifier: target)
    
    let availability = LanguageAvailability()
    let status = await availability.status(from: source, to: targetLang)
    
    guard status == .installed || status == .supported else {
        throw NSError(domain: "ScreenCLI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Language pair not supported or pack not installed. Download in System Settings > General > Language & Region > Translation Languages."])
    }
    
    let session = TranslationSession(installedSource: source, target: targetLang)
    let response = try await session.translate(text)
    return response.targetText
}
