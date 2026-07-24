//
//  PaymentScreenshotScanner.swift
//  YouShu
//
//  Optimized for WeChat/Alipay payment confirmation screenshots.
//  These have a clean layout: one large amount, one merchant name, one date.
//

import UIKit
import Vision

enum PaymentScreenshotScanner {

    static func scan(_ image: UIImage, categories: [Category]) async -> ReceiptScanResult {
        guard let cgImage = image.cgImage else {
            return ReceiptScanResult(rawText: "")
        }

        let text = await recognizeText(in: cgImage)
        return parsePayment(text, categories: categories)
    }

    // MARK: - OCR

    private static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let obs = request.results as? [VNRecognizedTextObservation] ?? []
                let text = obs
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

    private static func parsePayment(
        _ text: String,
        categories: [Category]
    ) -> ReceiptScanResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ReceiptScanResult(
            amount: findPaymentAmount(lines),
            merchant: findMerchant(lines),
            date: findDate(lines),
            rawText: text,
            suggestedCategory: suggestCategory(text, categories: categories)
        )
    }

    // MARK: - Amount (payment screenshot: single large ¥ number)

    private static func findPaymentAmount(_ lines: [String]) -> Double? {
        let skipWords = ["单号", "编号", "订单号", "交易单号", "流水号", "商户单号"]

        // Priority 1: Large ¥ amount (the main payment number)
        for line in lines {
            if line.contains("¥") || line.contains("￥") {
                let numbers = extractAllNumbers(line)
                // Payment amount is usually the largest ¥ number on screen
                if let maxNum = numbers.max(), maxNum > 0.01, numbers.count <= 2 {
                    return maxNum
                }
            }
        }

        // Priority 2: Line with 元 and not a skip word
        for line in lines {
            let lower = line.lowercased()
            if skipWords.contains(where: { lower.contains($0) }) { continue }
            if line.contains("元") {
                let numbers = extractAllNumbers(line)
                if let maxNum = numbers.max(), maxNum > 0.01 {
                    return maxNum
                }
            }
        }

        // Priority 3: Any number that looks like a payment (with decimal)
        for line in lines {
            let numbers = extractAllNumbers(line)
            for num in numbers where num > 0.01 && num != Double(Int(num)) {
                return num
            }
        }

        return nil
    }

    private static func extractAllNumbers(_ text: String) -> [Double] {
        let pattern = #"(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text),
                  let value = Double(text[r]), value > 0 else { return nil }
            return value
        }
    }

    // MARK: - Merchant (single merchant name near the amount)

    private static func findMerchant(_ lines: [String]) -> String? {
        let skipWords: Set<String> = [
            "微信", "支付", "付款", "成功", "完成", "金额", "时间", "日期",
            "单号", "编号", "交易", "返回", "完成", "查看详情",
            "零钱", "余额", "银行卡", "花呗", "信用卡", "储蓄卡",
            "付款方式", "支付方式", "已支付", "支付成功",
        ]

        // WeChat format: "向 星巴克 付款" → merchant is between 向 and 付款
        for line in lines {
            if line.contains("向") && (line.contains("付款") || line.contains("支付")) {
                let cleaned = line
                    .replacingOccurrences(of: "向", with: "")
                    .replacingOccurrences(of: "付款", with: "")
                    .replacingOccurrences(of: "支付", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if cleaned.count >= 2 && cleaned.count <= 30 {
                    return cleaned
                }
            }
        }

        // Alipay format: merchant name near "付款-" or "收款方"
        for line in lines {
            if line.contains("收款方") || line.contains("付款-") || line.contains("商户") {
                let cleaned = line
                    .replacingOccurrences(of: "收款方", with: "")
                    .replacingOccurrences(of: "商户", with: "")
                    .replacingOccurrences(of: "付款-", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: "：", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if cleaned.count >= 2 && cleaned.count <= 30 {
                    return cleaned
                }
            }
        }

        // Fallback: short text line without skip words, near the amount line
        for line in lines where line.count >= 2 && line.count <= 30 {
            let hasSkip = skipWords.contains { line.contains($0) }
            let hasNumber = line.range(of: #"\d"#, options: .regularExpression) != nil
            let isPureDigits = line.allSatisfy { $0.isNumber || $0 == "." || $0 == "¥" || $0 == "￥" }
            if !hasSkip && !hasNumber && !isPureDigits {
                return line
            }
        }

        return nil
    }

    // MARK: - Date

    private static func findDate(_ lines: [String]) -> Date? {
        let patterns = [
            #"(\d{4})[年/\-](\d{1,2})[月/\-](\d{1,2})"#,
            #"(\d{1,2})[月/\-](\d{1,2})日?"#,
        ]
        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, range: range) else { continue }

                var comps = DateComponents()
                comps.calendar = Calendar.current

                if match.numberOfRanges == 4 {
                    if let r1 = Range(match.range(at: 1), in: line),
                       let r2 = Range(match.range(at: 2), in: line),
                       let r3 = Range(match.range(at: 3), in: line),
                       let y = Int(line[r1]), let m = Int(line[r2]), let d = Int(line[r3]) {
                        comps.year = y; comps.month = m; comps.day = d
                        if let date = comps.date { return date }
                    }
                } else if match.numberOfRanges == 3 {
                    if let r1 = Range(match.range(at: 1), in: line),
                       let r2 = Range(match.range(at: 2), in: line),
                       let m = Int(line[r1]), let d = Int(line[r2]) {
                        comps.month = m; comps.day = d
                        comps.year = Calendar.current.component(.year, from: Date())
                        if let date = comps.date { return date }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Category

    private static func suggestCategory(_ text: String, categories: [Category]) -> Category? {
        let lower = text.lowercased()
        let foodKW = ["餐", "饭", "面", "火锅", "烤肉", "奶茶", "咖啡", "外卖", "食堂", "小吃"]
        let transportKW = ["加油", "停车", "高速", "地铁", "公交", "打车", "滴滴"]
        let shopKW = ["超市", "商场", "淘宝", "京东", "拼多多", "便利店"]

        if foodKW.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "餐饮" }
        }
        if transportKW.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "交通" }
        }
        if shopKW.contains(where: { lower.contains($0) }) {
            return categories.first { $0.name == "购物" }
        }
        return nil
    }
}
