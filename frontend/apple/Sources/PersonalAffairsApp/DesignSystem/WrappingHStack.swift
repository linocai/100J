import SwiftUI

struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let rowSpacing: CGFloat
    let content: Content

    init(
        spacing: CGFloat = AppTheme.Spacing.sm,
        rowSpacing: CGFloat = AppTheme.Spacing.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.content = content()
    }

    var body: some View {
        WrappingLayout(spacing: spacing, rowSpacing: rowSpacing) {
            content
        }
    }
}

private struct WrappingLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? CGFloat.greatestFiniteMagnitude
        let rows = rowIndexes(for: sizes, maxWidth: maxWidth)
        let rowWidths = rows.map { row in
            row.reduce(CGFloat.zero) { partial, index in
                partial + sizes[index].width
            } + CGFloat(max(0, row.count - 1)) * spacing
        }
        let rowHeights = rows.map { row in
            row.map { sizes[$0].height }.max() ?? 0
        }
        let totalHeight = rowHeights.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * rowSpacing
        let resolvedWidth = proposal.width ?? (rowWidths.max() ?? 0)
        return CGSize(width: resolvedWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = rowIndexes(for: sizes, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            for index in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: sizes[index].width, height: sizes[index].height)
                )
                x += sizes[index].width + spacing
            }
            y += rowHeight + rowSpacing
        }
    }

    private func rowIndexes(for sizes: [CGSize], maxWidth: CGFloat) -> [[Int]] {
        guard !sizes.isEmpty else { return [] }
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        let availableWidth = max(1, maxWidth)

        for index in sizes.indices {
            let itemWidth = min(sizes[index].width, availableWidth)
            let nextWidth = current.isEmpty ? itemWidth : currentWidth + spacing + itemWidth
            if nextWidth > availableWidth, !current.isEmpty {
                rows.append(current)
                current = [index]
                currentWidth = itemWidth
            } else {
                current.append(index)
                currentWidth = nextWidth
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }

        return rows
    }
}
