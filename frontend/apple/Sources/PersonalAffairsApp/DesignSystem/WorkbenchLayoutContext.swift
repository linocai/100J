import SwiftUI

enum WorkbenchContentMode: Equatable {
    case wide
    case regular
    case compact
}

struct WorkbenchLayoutContext: Equatable {
    var windowWidth: CGFloat
    var centerWidth: CGFloat
    var showsInspector: Bool
    var contentMode: WorkbenchContentMode

    static let `default` = WorkbenchLayoutContext(
        windowWidth: 1440,
        centerWidth: 900,
        showsInspector: true,
        contentMode: .wide
    )

    init(
        windowWidth: CGFloat,
        centerWidth: CGFloat,
        showsInspector: Bool,
        contentMode: WorkbenchContentMode? = nil
    ) {
        self.windowWidth = windowWidth
        self.centerWidth = max(0, centerWidth)
        self.showsInspector = showsInspector
        self.contentMode = contentMode ?? Self.mode(for: centerWidth)
    }

    var usesWideColumns: Bool {
        centerWidth >= 900
    }

    var isCompact: Bool {
        centerWidth < 720
    }

    var pagePadding: CGFloat {
        if centerWidth < 700 { return AppTheme.Spacing.md }
        if centerWidth < 900 { return AppTheme.Spacing.lg }
        return AppTheme.Spacing.xl
    }

    var narrowControlWidth: CGFloat {
        min(260, max(180, centerWidth - pagePadding * 2))
    }

    private static func mode(for centerWidth: CGFloat) -> WorkbenchContentMode {
        if centerWidth >= 900 { return .wide }
        if centerWidth >= 700 { return .regular }
        return .compact
    }
}

private struct WorkbenchLayoutContextKey: EnvironmentKey {
    static let defaultValue = WorkbenchLayoutContext.default
}

extension EnvironmentValues {
    var workbenchLayout: WorkbenchLayoutContext {
        get { self[WorkbenchLayoutContextKey.self] }
        set { self[WorkbenchLayoutContextKey.self] = newValue }
    }
}
