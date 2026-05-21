import PersonalAffairsCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// v1.1 重构后的 design token。对齐 `新前端面板演示.html` 的 `:root` 与 Apple HIG 2025。
enum AppTheme {
    /// 4pt 网格的间距体系。
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    /// HIG-friendly 圆角刻度（Sequoia / iOS 26）。
    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    /// 板块色：与 HTML demo 一一对应，全部为 Apple System Colors。
    enum Section {
        static let today    = Color.orange
        static let plan     = Color.indigo
        static let calendar = Color.orange
        static let agent    = Color.purple
        static let settings = Color.gray
    }

    /// 状态色，PillView / Card 等通过 status pill 调用。
    enum Status {
        static let personal = Color.mint
        static let company  = Color.indigo
        static let warning  = Color.orange
        static let danger   = Color.red
        static let success  = Color.green
        static let info     = Color.cyan
        static let neutral  = Color.secondary
    }

    /// 玻璃卡片专用的 corner / shadow tokens。
    enum Glass {
        static let cardCorner: CGFloat = 14
        static let sheetCorner: CGFloat = 28
        static let shadowRadius: CGFloat = 18
        static let shadowOpacityLight: Double = 0.12
        static let shadowOpacityDark: Double = 0.42
    }

    /// 平台无关的语义底色。
    enum Background {
        static var canvas: Color {
            #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
            #else
            return Color(uiColor: .systemBackground)
            #endif
        }

        static var grouped: Color {
            #if os(macOS)
            return Color(nsColor: .underPageBackgroundColor)
            #else
            return Color(uiColor: .systemGroupedBackground)
            #endif
        }
    }
}

/// 与 v1 兼容的 enum，给 ViewModels 中残留的 PillStyle 引用用。
/// **v1.1 起 PillStyle 不直接渲染** — 由 `StatusPill(style:)` 选色。
public enum PillStyle: String, Equatable {
    case neutral
    case neutralSubtle
    case personal
    case company
    case calendar
    case agent
    case warning
    case warningSubtle
    case danger
    case success

    var color: Color {
        switch self {
        case .neutral, .neutralSubtle: return AppTheme.Status.neutral
        case .personal: return AppTheme.Status.personal
        case .company: return AppTheme.Status.company
        case .calendar: return AppTheme.Section.calendar
        case .agent: return AppTheme.Status.warning  // unused now, will be mapped
        case .warning, .warningSubtle: return AppTheme.Status.warning
        case .danger: return AppTheme.Status.danger
        case .success: return AppTheme.Status.success
        }
    }
}

// MARK: - 域类型扩展（沿用 v1，给 enum 提供 SF Symbol 与 pill 默认）

extension TaskPriority {
    var sortRank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .urgent: return .danger
        case .high: return .warning
        case .medium: return .neutral
        case .low: return .neutralSubtle
        }
    }

    var label: String {
        switch self {
        case .urgent: return "紧急"
        case .high: return "高优"
        case .medium: return "中优"
        case .low: return "低优"
        }
    }
}

extension ProjectStatus {
    var pillStyle: PillStyle {
        switch self {
        case .active: return .company
        case .completed: return .success
        case .archived: return .neutralSubtle
        }
    }
}

extension CalendarItemType {
    var systemImage: String {
        switch self {
        case .appointment: return "calendar"
        case .anniversary: return "gift"
        case .subscriptionExpiry: return "creditcard"
        case .deadline: return "flag"
        case .reminder: return "bell"
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .subscriptionExpiry: return .warning
        case .deadline: return .danger
        case .anniversary: return .warningSubtle
        case .appointment: return .company
        case .reminder: return .neutral
        }
    }
}

extension NoteType {
    var systemImage: String {
        switch self {
        case .idea: return "lightbulb"
        case .memo: return "doc.text"
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .idea: return .warning
        case .memo: return .neutral
        }
    }
}

extension Date {
    var dayKey: String {
        DateOnlyFormatter.shared.string(from: self)
    }

    var compactTime: String {
        TimeOnlyFormatter.shared.string(from: self)
    }
}

enum DateOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum TimeOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

func parsedDateOnly(_ value: String?) -> Date? {
    guard let value else { return nil }
    return DateOnlyFormatter.shared.date(from: value)
}
