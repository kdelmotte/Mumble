import SwiftUI

// MARK: - OnboardingCompleteView (Step 6)

struct OnboardingCompleteView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    private var allPermissionsGranted: Bool {
        viewModel.permissionManager.microphoneGranted && viewModel.permissionManager.accessibilityGranted
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer().frame(height: 10)

                // Summary card (two-column)
                summaryCard

                Spacer().frame(height: 10)

                // Warning + action if accessibility is missing
                if !viewModel.permissionManager.accessibilityGranted {
                    accessibilityWarning
                }

                Spacer().frame(height: 10)

                // Vocabulary tip
                vocabularyTip

                Spacer()
            }

            // Confetti overlay
            if allPermissionsGranted {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image("MumbleIconSettings")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .mascotGlow(color: .green, intensity: 1.5)

            if allPermissionsGranted {
                Text("You're all set!")
                    .font(.mumbleDisplay(size: 28))

                Text("Mumble is ready to go. Here's a summary of your setup.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Almost there!")
                    .font(.mumbleDisplay(size: 28))

                Text("Accessibility permission is required for Mumble to insert text. If you already granted it, try restarting the app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Summary Card (Two-Column)

    private var toneSummaryValue: String {
        let personal = viewModel.toneMappingConfig.tone(for: .personal).displayName
        let work = viewModel.toneMappingConfig.tone(for: .work).displayName
        return "\(personal) / \(work)"
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column
            VStack(spacing: 0) {
                compactCell(
                    icon: "fn",
                    iconColor: .accentColor,
                    title: "Trigger",
                    value: "Hold \(viewModel.currentShortcut.displayString)",
                    isSystemIcon: false
                )

                Divider().padding(.horizontal, 10)

                compactCell(
                    icon: "mic.fill",
                    iconColor: .red,
                    title: "Microphone",
                    value: viewModel.microphoneSummaryValue,
                    statusColor: viewModel.permissionManager.microphoneGranted ? .green : .yellow
                )

                Divider().padding(.horizontal, 10)

                compactCell(
                    icon: "accessibility",
                    iconColor: .blue,
                    title: "Accessibility",
                    value: viewModel.permissionManager.accessibilityGranted ? "Granted" : "Not granted",
                    statusColor: viewModel.permissionManager.accessibilityGranted ? .green : .yellow
                )
            }

            // Column divider
            Divider()

            // Right column
            VStack(spacing: 0) {
                compactCell(
                    icon: "key.fill",
                    iconColor: .orange,
                    title: "API Key",
                    value: "Configured",
                    statusColor: .green
                )

                Divider().padding(.horizontal, 10)

                compactCell(
                    icon: "textformat",
                    iconColor: .teal,
                    title: "Tone",
                    value: toneSummaryValue
                )

                Divider().padding(.horizontal, 10)

                compactCell(
                    icon: "power",
                    iconColor: .purple,
                    title: "Launch at Login",
                    value: viewModel.launchAtLogin ? "On" : "Off",
                    statusColor: viewModel.launchAtLogin ? .green : .secondary
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .themedCard(accent: .green, elevated: true)
    }

    // MARK: - Compact Cell

    private func compactCell(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        isSystemIcon: Bool = true,
        statusColor: Color? = nil
    ) -> some View {
        HStack(spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.15), iconColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)

                if isSystemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(iconColor)
                } else {
                    Text(icon)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(iconColor)
                }
            }

            // Title + Value
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    if let statusColor {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                    }

                    Text(value)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Vocabulary Tip

    private var vocabularyTip: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MumbleTheme.brandGradient)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tip: Custom Vocabulary")
                    .font(.callout.weight(.semibold))

                Text("Got names that always get misspelled? Add them in Settings \u{203A} Vocabulary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MumbleTheme.brandGradient.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Accessibility Warning

    private var accessibilityWarning: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)

                Text("Grant Accessibility in System Settings, then return here. If it still shows \"Not granted\", restart the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(accent: .yellow)

            Button("Open Accessibility Settings") {
                viewModel.permissionManager.openAccessibilitySettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingCompleteView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
