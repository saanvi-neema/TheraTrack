import Foundation
import PDFKit
import Vision
import UIKit

enum DocumentTextExtractor {
    static func extractText(from data: Data, fileName: String) async throws -> String? {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf":
            return extractPDFText(data: data)
        case "jpg", "jpeg", "png":
            return try await extractImageText(data: data)
        case "txt":
            return String(data: data, encoding: .utf8)
        default:
            return nil
        }
    }

    private static func extractPDFText(data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        var text = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text.isEmpty ? nil : text
    }

    private static func extractImageText(data: Data) async throws -> String? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
