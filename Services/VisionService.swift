import Foundation
import Vision
import UIKit


final class VisionService {
    @MainActor static let shared = VisionService()
    private init() {}

    /// Analyzes a UIImage and returns a descriptive string.
    /// Runs entirely off the main thread — safe to await from @MainActor contexts.
    func describe(image: UIImage) async throws -> String {
        // CGImage extraction must happen before the detached task
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "VisionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not read image data."])
        }

        // Move Vision work off MainActor so handler.perform() doesn't block UI
        return try await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Text recognition
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.minimumTextHeight = 0.0

            // Image classification
            let classifyRequest = VNClassifyImageRequest()

            try handler.perform([textRequest, classifyRequest])

            var parts: [String] = []

            // Top classification
            if let top = classifyRequest.results?.first {
                let confidence = String(format: "%.0f%%", top.confidence * 100)
                parts.append("Main subject: \(top.identifier) (\(confidence) confidence)")
            }

            // Extracted text
            let texts = (textRequest.results ?? []).compactMap {
                $0.topCandidates(1).first?.string
            }
            if !texts.isEmpty {
                parts.append("Visible text: " + texts.joined(separator: " | "))
            }

            return parts.isEmpty
                ? "No recognizable content detected in the image."
                : parts.joined(separator: "\n\n")
        }.value
    }
}
