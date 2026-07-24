//
//  NLTransactionParser.swift
//  YouShu
//

import Foundation

// MARK: - Parse Result

struct ParsedTransaction: Equatable {
    var type: TransactionType?
    var amount: Double?
    var category: Category?
    var account: Account?
    var destinationAccount: Account?
    var note: String?
}

// MARK: - Category Synonym Map

private let categorySynonyms: [String: [String]] = [
    "餐饮": ["吃", "饭", "午饭", "晚饭", "晚餐", "早餐", "外卖", "餐厅", "饭店",
             "奶茶", "咖啡", "水果", "零食", "聚餐", "请客", "夜宵", "小吃", "烧烤", "火锅",
             "自助", "面", "米线", "饺子", "面包", "蛋糕", "冰淇淋", "饮料", "酒", "啤酒",
             "买菜", "食材", "食堂", "快餐", "盒饭", "麻辣烫", "串串", "日料", "西餐"],
    "交通": ["打车", "地铁", "公交", "加油", "停车", "过路费", "高速", "高铁", "火车",
             "飞机", "机票", "出租车", "滴滴", "骑车", "共享单车", "充电", "保养", "洗车",
             "通行", "油费", "车票", "叫车", "网约车", "顺风车"],
    "购物": ["买", "淘宝", "京东", "拼多多", "超市", "衣服", "鞋子", "手机", "电脑",
             "日用", "护肤品", "化妆品", "家电", "数码", "文具", "玩具", "宠物", "猫粮",
             "狗粮", "网购", "快递", "双十一", "618", "秒杀", "折扣"],
    "居住": ["房租", "房贷", "水电", "物业", "燃气", "网费", "话费", "维修", "电费",
             "水费", "暖气", "装修", "家居", "电器", "灯具", "窗帘", "搬家"],
    "娱乐": ["电影", "游戏", "KTV", "旅游", "演唱会", "运动", "健身", "游泳", "唱歌",
             "追剧", "会员", "视频", "音乐", "充游戏", "密室", "剧本杀", "桌游", "滑雪",
             "按摩", "spa", "SPA", "泡汤", "温泉", "露营", "门票", "景点"],
    "医疗": ["医院", "药", "挂号", "体检", "牙医", "看病", "诊所", "检查", "验血",
             "手术", "住院", "医保", "中药", "西药", "药房", "口罩", "消毒"],
    "教育": ["学费", "培训", "书本", "考试", "课程", "辅导", "网课", "考证", "教材",
             "文具", "书包", "补习", "学车", "驾校"],
    "工资": ["工资", "薪水", "奖金", "年终奖", "补贴", "报销", "兼职", "提成", "分红",
             "理财", "利息", "退款", "押金", "返现", "退税"],
    "红包/礼金": ["红包", "生日", "礼物", "结婚", "压岁钱", "份子钱", "赠礼", "礼金",
               "祝贺", "满月", "升学"],
]

// MARK: - Type Keywords

private let expenseKeywords: Set<String> = [
    "花了", "买了", "付款", "支付", "消费", "开销", "用了", "花掉", "购买", "缴费",
    "还了", "还", "扣了", "扣款", "支出", "出了", "给钱", "付钱", "买单", "结账",
]
private let incomeKeywords: Set<String> = [
    "收入", "到账", "收到了", "收到", "进账", "赚了", "发了", "入账", "挣了",
    "收款", "拿来", "领了", "取钱",
]
private let transferKeywords: Set<String> = [
    "转了", "转给", "转入", "转账", "转出", "汇给", "汇了",
]

// MARK: - Parser

enum NLTransactionParser {

    static func parse(
        _ text: String,
        categories: [Category],
        accounts: [Account]
    ) -> ParsedTransaction {
        var result = ParsedTransaction()
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return result }

        // 1. Extract amount
        result.amount = extractAmount(cleaned)

        // 2. Detect type
        result.type = detectType(cleaned)

        // 3. Match category via direct name + synonyms
        result.category = matchCategory(cleaned, categories: categories, type: result.type)

        // 4. Match account
        result.account = matchAccount(cleaned, accounts: accounts)
        if result.type == .transfer {
            result.destinationAccount = matchDestinationAccount(cleaned, accounts: accounts, source: result.account)
        }

        // 5. Extract note
        result.note = extractNote(cleaned, result: result)

        return result
    }

    // MARK: - Amount

    private static func extractAmount(_ text: String) -> Double? {
        // 1. Arabic numeral: 35元, ¥35, 35块, 35
        let arabicPattern = #"(\d+(?:\.\d{1,2})?)\s*(?:元|块|¥)?"#
        if let match = firstRegexMatch(arabicPattern, in: text),
           let value = Double(match) {
            return value
        }

        // 2. Chinese numeral: 二十五块, 一百二十元, 三千五
        return extractChineseAmount(text)
    }

    /// Parse Chinese numeral amounts like 二十五块 → 25.0, 一百五 → 150.0
    private static func extractChineseAmount(_ text: String) -> Double? {
        let chineseDigitPattern = #"[零〇一二三四五六七八九十百千万两半点]+"#
        let unitPattern = #"(?:块|元|块钱|元钱)"#

        guard let digitRegex = try? NSRegularExpression(pattern: chineseDigitPattern),
              let unitRegex = try? NSRegularExpression(pattern: unitPattern) else {
            return nil
        }

        let nsText = text as NSString
        let digitMatches = digitRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let unitMatches = unitRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for dMatch in digitMatches {
            let digitStr = nsText.substring(with: dMatch.range)
            guard let baseValue = chineseToDouble(digitStr), baseValue > 0 else { continue }

            // Check if there's a following unit (块/元)
            let afterDigit = dMatch.range.location + dMatch.range.length
            var hasUnit = false
            for uMatch in unitMatches {
                if uMatch.range.location >= afterDigit - 1 && uMatch.range.location <= afterDigit + 2 {
                    hasUnit = true
                    break
                }
            }

            if hasUnit || text.contains("花了") || text.contains("买了") || text.contains("用了") {
                return baseValue
            }
        }

        return nil
    }

    /// Convert Chinese numeral string to integer. e.g., 二十五 → 25, 一百二十 → 120, 三千五 → 3500
    private static func chineseToDouble(_ s: String) -> Double? {
        let digitMap: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "两": 2,
        ]
        let unitMap: [Character: Int] = [
            "十": 10, "百": 100, "千": 1000, "万": 10000,
        ]

        let chars = Array(s)
        var total = 0.0
        var current = 0
        var lastUnit = 1

        for (i, ch) in chars.enumerated() {
            if ch == "点" {
                // Parse fractional part
                let frac = chars[(i + 1)...].compactMap { digitMap[$0] }
                if !frac.isEmpty {
                    var decimal = 0.0
                    var divisor = 10.0
                    for d in frac {
                        decimal += Double(d) / divisor
                        divisor *= 10
                    }
                    return total + Double(current) + decimal
                }
                break
            }

            if ch == "半" {
                total += Double(current) + 0.5
                current = 0
                continue
            }

            if let digit = digitMap[ch] {
                current = current * 10 + digit
            } else if let unit = unitMap[ch] {
                let value = current == 0 ? 1 : current
                if unit >= 10000 {
                    // 万: multiply what we have
                    total += Double(value * unit)
                } else if unit >= lastUnit {
                    total += Double(value * unit)
                } else {
                    total += Double(value) * Double(unit)
                }
                current = 0
                lastUnit = unit
            }
        }

        total += Double(current)
        return total
    }

    /// Convenience: first regex match group
    private static func firstRegexMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    // MARK: - Type

    private static func detectType(_ text: String) -> TransactionType? {
        for kw in transferKeywords where text.contains(kw) { return .transfer }
        for kw in incomeKeywords where text.contains(kw) { return .income }
        for kw in expenseKeywords where text.contains(kw) { return .expense }
        if text.contains("元") || text.contains("块") || text.contains("¥") || text.contains("花了") || text.contains("买了") {
            return .expense
        }
        return nil
    }

    // MARK: - Category

    private static func matchCategory(
        _ text: String,
        categories: [Category],
        type: TransactionType?
    ) -> Category? {
        let lower = text.lowercased()

        // Direct name match
        for cat in categories {
            if let t = type, cat.type != t { continue }
            if lower.contains(cat.name.lowercased()) { return cat }
        }

        // Synonym match (longest first)
        for cat in categories {
            if let t = type, cat.type != t { continue }
            guard let synonyms = categorySynonyms[cat.name] else { continue }
            for syn in synonyms.sorted(by: { $0.count > $1.count }) {
                if lower.contains(syn.lowercased()) { return cat }
            }
        }

        return nil
    }

    // MARK: - Account

    private static func matchAccount(_ text: String, accounts: [Account]) -> Account? {
        let lower = text.lowercased()
        return accounts.first { lower.contains($0.name.lowercased()) }
    }

    private static func matchDestinationAccount(
        _ text: String,
        accounts: [Account],
        source: Account?
    ) -> Account? {
        let lower = text.lowercased()
        for prefix in ["转给", "转入", "汇给"] {
            if let range = lower.range(of: prefix) {
                let after = String(lower[range.upperBound...])
                for acc in accounts where acc.id != source?.id {
                    if after.contains(acc.name.lowercased()) { return acc }
                }
            }
        }
        return nil
    }

    // MARK: - Note

    private static func extractNote(_ text: String, result: ParsedTransaction) -> String? {
        var remaining = text

        // Remove amount patterns
        if let amt = result.amount {
            for p in ["\(Int(amt))元", "\(Int(amt))块", "¥\(Int(amt))",
                      "\(amt)元", "¥\(amt)",
                      String(format: "%.2f", amt), String(format: "%.1f", amt),
                      String(Int(amt))] {
                remaining = remaining.replacingOccurrences(of: p, with: "")
            }
        }

        // Remove type keywords
        for kw in expenseKeywords.union(incomeKeywords).union(transferKeywords) {
            remaining = remaining.replacingOccurrences(of: kw, with: "")
        }

        // Remove category name / synonym
        if let cat = result.category {
            remaining = remaining.replacingOccurrences(of: cat.name, with: "")
            if let synonyms = categorySynonyms[cat.name] {
                for syn in synonyms.sorted(by: { $0.count > $1.count }) {
                    if remaining.contains(syn) {
                        remaining = remaining.replacingOccurrences(of: syn, with: "")
                        break
                    }
                }
            }
        }

        // Remove account names
        if let acc = result.account { remaining = remaining.replacingOccurrences(of: acc.name, with: "") }
        if let dest = result.destinationAccount { remaining = remaining.replacingOccurrences(of: dest.name, with: "") }

        let cleaned = remaining
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return cleaned.isEmpty ? nil : cleaned
    }
}
