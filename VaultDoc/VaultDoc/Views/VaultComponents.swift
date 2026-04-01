import SwiftUI

enum VaultStatusTone {
    case neutral
    case positive
    case warning
    case critical

    var fill: Color {
        switch self {
        case .neutral:
            return BrandTheme.surfaceElevated
        case .positive:
            return BrandTheme.accentCool.opacity(0.18)
        case .warning:
            return BrandTheme.accentBright.opacity(0.18)
        case .critical:
            return BrandTheme.alert.opacity(0.18)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral:
            return BrandTheme.textSecondary
        case .positive:
            return BrandTheme.accentCool
        case .warning:
            return BrandTheme.accentBright
        case .critical:
            return BrandTheme.alert
        }
    }
}

enum NoticeBannerTone {
    case info
    case success
    case critical

    var fill: Color {
        switch self {
        case .info:
            return BrandTheme.surface
        case .success:
            return BrandTheme.accentCool.opacity(0.12)
        case .critical:
            return BrandTheme.alert.opacity(0.12)
        }
    }

    var border: Color {
        switch self {
        case .info:
            return BrandTheme.accentBright.opacity(0.30)
        case .success:
            return BrandTheme.accentCool.opacity(0.32)
        case .critical:
            return BrandTheme.alert.opacity(0.42)
        }
    }

    var iconColor: Color {
        switch self {
        case .info:
            return BrandTheme.accentBright
        case .success:
            return BrandTheme.accentCool
        case .critical:
            return BrandTheme.alert
        }
    }

    var textColor: Color {
        switch self {
        case .critical:
            return BrandTheme.alert
        case .info, .success:
            return BrandTheme.textPrimary
        }
    }
}

enum VaultItemStatus {
    case verified
    case incomplete
    case missingEvidence

    var title: String {
        switch self {
        case .verified:
            return L10n.tr("Verified")
        case .incomplete:
            return L10n.tr("Incomplete")
        case .missingEvidence:
            return L10n.tr("Missing evidence")
        }
    }

    var tone: VaultStatusTone {
        switch self {
        case .verified:
            return .positive
        case .incomplete:
            return .warning
        case .missingEvidence:
            return .critical
        }
    }

    var icon: String {
        switch self {
        case .verified:
            return "checkmark.seal.fill"
        case .incomplete:
            return "exclamationmark.circle.fill"
        case .missingEvidence:
            return "doc.text.magnifyingglass"
        }
    }
}

extension Item {
    var vaultStatus: VaultItemStatus {
        if isDocumented {
            return .verified
        }
        if photos.isEmpty && documents.isEmpty {
            return .missingEvidence
        }
        return .incomplete
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BrandTheme.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(BrandTheme.textSecondary)
                }
            }

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrandTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        )
    }
}

struct ValueBadge: View {
    let title: String
    let value: String
    var tone: VaultStatusTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BrandTheme.textSecondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tone == .neutral ? BrandTheme.textPrimary : tone.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.fill)
        )
    }
}

struct StatusBadge: View {
    let title: String
    let systemImage: String
    var tone: VaultStatusTone

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.fill)
            )
    }
}

struct NoticeBanner: View {
    let text: String
    let systemImage: String
    var tone: NoticeBannerTone = .info

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tone.iconColor)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tone.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tone.border, lineWidth: 1)
                )
        )
    }
}

struct VaultItemRow: View {
    let item: Item
    let valueText: String

    var body: some View {
        HStack(spacing: 14) {
            itemLeading

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.categoryDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BrandTheme.textSecondary)

                    Text(L10n.tr("•"))
                        .foregroundStyle(BrandTheme.textSecondary)

                    Text(valueText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .lineLimit(1)
                }

                StatusBadge(
                    title: item.vaultStatus.title,
                    systemImage: item.vaultStatus.icon,
                    tone: item.vaultStatus.tone
                )
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BrandTheme.textSecondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrandTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        )
    }

    private var itemLeading: some View {
        Group {
            if let photo = item.photos.first {
                CachedDataImage(data: photo.imageData, cacheKey: photo.id.uuidString, maxDimension: 72)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandTheme.surfaceElevated)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(BrandTheme.accentBright)
                    }
            }
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BrandTheme.accentPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(BrandTheme.actionForeground)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
