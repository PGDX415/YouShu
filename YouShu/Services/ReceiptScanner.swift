//
//  ReceiptScanner.swift
//  YouShu
//

import UIKit
import Vision

// MARK: - Scan Result

struct ReceiptScanResult {
    var amount: Double?
    var merchant: String?
    var date: Date?
    var rawText: String
    var suggestedCategory: Category?
}

// MARK: - Scanner

enum ReceiptScanner {

    /// Run Vision OCR on the image, then parse the recognized text.
    static func scan(_ image: UIImage, categories: [Category]) async -> ReceiptScanResult {
        guard let cgImage = image.cgImage else {
            return ReceiptScanResult(rawText: "")
        }

        // 1. OCR
        let recognizedText = await recognizeText(in: cgImage)

        // 2. Parse
        return parseReceipt(recognizedText, categories: categories)
    }

    // MARK: - Vision OCR

    private static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Parse

    private static func parseReceipt(
        _ text: String,
        categories: [Category]
    ) -> ReceiptScanResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ReceiptScanResult(
            amount: findAmount(lines),
            merchant: findMerchant(lines),
            date: findDate(lines),
            rawText: text,
            suggestedCategory: suggestCategory(text, categories: categories)
        )
    }

    // MARK: - Amount Detection

    private static func findAmount(_ lines: [String]) -> Double? {
        // Priority 1: "合计" / "总计" / "total" line
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("合计") || lower.contains("总计")
               || lower.contains("total") || lower.contains("实付")
               || lower.contains("应付") || lower.contains("应收") {
                if let amt = extractNumber(line) { return amt }
            }
        }

        // Priority 2: line with ¥ and a number
        for line in lines {
            if (line.contains("¥") || line.contains("￥")) && line.range(of: #"\d"#, options: .regularExpression) != nil {
                if let amt = extractNumber(line) { return amt }
            }
        }

        // Priority 3: any line with a number followed by 元
        for line in lines {
            if let amt = extractNumber(line) { return amt }
        }

        return nil
    }

    private static func extractNumber(_ text: String) -> Double? {
        // Try: ¥123.45, 123.45元, 123元, 123, 123.45
        let patterns = [
            #"[¥￥]\s*(\d+(?:\.\d{1,2})?)"#,
            #"(\d+(?:\.\d{1,2})?)\s*元"#,
            #"(\d+(?:\.\d{1,2})?)"#,
        ]
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex?.firstMatch(in: text, range: range),
                  let r = Range(match.range(at: 1), in: text) else { continue }
            if let value = Double(text[r]), value > 0 {
                return value
            }
        }
        return nil
    }

    // MARK: - Merchant Detection

    private static func findMerchant(_ lines: [String]) -> String? {
        // Common receipt patterns: merchant name is at the top
        let skipWords: Set<String> = [
            "小票", "收据", "发票", "订单", "消费", "明细", "清单",
            "谢谢", "欢迎", "电话", "地址", "日期", "时间", "序号",
            "品名", "数量", "单价", "金额", "合计", "总计", "找零",
            "实收", "应收", "应付", "实付", "支付", "微信", "支付宝",
        ]

        // First 5 lines are most likely to contain merchant name
        for line in lines.prefix(5) {
            let cleaned = line
                .replacingOccurrences(of: #"[#\*\-\.\(\)（）]"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard cleaned.count >= 2 && cleaned.count <= 30 else { continue }

            let hasSkipWord = skipWords.contains { cleaned.contains($0) }
            let hasNumber = cleaned.range(of: #"\d"#, options: .regularExpression) != nil
            if !hasSkipWord && !hasNumber {
                return cleaned
            }
        }

        // Fallback: longest line without numbers in first 8 lines
        return lines.prefix(8)
            .filter { $0.range(of: #"\d"#, options: .regularExpression) == nil }
            .filter { $0.count >= 2 && $0.count <= 30 }
            .max(by: { $0.count < $1.count })
    }

    // MARK: - Date Detection

    private static func findDate(_ lines: [String]) -> Date? {
        let datePatterns = [
            #"(\d{4})[年/\-](\d{1,2})[月/\-](\d{1,2})"#,
            #"(\d{1,2})[月/\-](\d{1,2})"#,
        ]

        for line in lines {
            for pattern in datePatterns {
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex?.firstMatch(in: line, range: range) else { continue }

                var components = DateComponents()
                components.calendar = Calendar.current

                if match.numberOfRanges == 4 {
                    // Full date: YYYY/MM/DD
                    if let r1 = Range(match.range(at: 1), in: line),
                       let r2 = Range(match.range(at: 2), in: line),
                       let r3 = Range(match.range(at: 3), in: line),
                       let y = Int(line[r1]), let m = Int(line[r2]), let d = Int(line[r3]) {
                        components.year = y
                        components.month = m
                        components.day = d
                        if let date = components.date { return date }
                    }
                } else if match.numberOfRanges == 3 {
                    // Short date: MM/DD
                    if let r1 = Range(match.range(at: 1), in: line),
                       let r2 = Range(match.range(at: 2), in: line),
                       let m = Int(line[r1]), let d = Int(line[r2]) {
                        components.month = m
                        components.day = d
                        // Assume current year
                        components.year = Calendar.current.component(.year, from: Date())
                        if let date = components.date { return date }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Category Suggestion

    private static func suggestCategory(_ text: String, categories: [Category]) -> Category? {
        // Use same synonym matching as NLTransactionParser
        // Look for restaurant/food keywords
        let foodKeywords = ["餐", "饭", "面", "菜", "火锅", "烧烤", "奶茶", "咖啡", "小吃", "炸鸡", "披萨"]
        let transportKeywords = ["加油", "停车", "高速", "地铁", "公交"]
        let shopKeywords = ["超市", "商场", "店", "淘宝", "京东"]

        let lower = text.lowercased()

        if foodKeywords.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "餐饮" }
        }
        if transportKeywords.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "交通" }
        }
        if shopKeywords.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "购物" }
        }
        return nil
    }
}
