import SwiftUI

// MARK: - OnboardingCompleteView (Step 4)

struct OnboardingCompleteView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    private var allPermissionsGranted: Bool {
        viewModel.permissionManager.microphoneGranted && viewModel.permissionManager.accessibilityGranted
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 20)

            // Summary card
            summaryCard

            Spacer().frame(height: 16)

            // Warning + action if accessibility is missing
            if !viewModel.permissionManager.accessibilityGranted {
                accessibilityWarning
                Spacer().frame(height: 24)
            } else {
                Spacer().frame(height: 8)
            }

            // Complete button
            Button(action: {
                viewModel.completeOnboarding()
            }) {
                Text("Start Mumbling")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("MumbleIconSettings")
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            if allPermissionsGranted {
                Text("You're all set!")
                    .font(.title.bold())

                Text("Mumble is ready to go. Here's a summary of your setup.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Almost there!")
                    .font(.title.bold())

                Text("Accessibility permission is required for Mumble to insert text. If you already granted it, try restarting the app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(
                icon: "fn",
                iconColor: .accentColor,
                title: "Trigger",
                value: "Hold Fn to dictate",
                isSystemIcon: false
            )

            Divider().padding(.leading, 54)

            summaryRow(
                icon: "mic.fill",
                iconColor: .red,
                title: "Microphone",
                value: viewModel.permissionManager.microphoneGranted ? "Granted" : "Not granted",
                statusColor: viewModel.permissionManager.microphoneGranted ? .green : .yellow
            )

            Divider().padding(.leading, 54)

            summaryRow(
                icon: "accessibility",
                iconColor: .blue,
                title: "Accessibility",
                value: viewModel.permissionManager.accessibilityGranted ? "Granted" : "Not granted",
                statusColor: viewModel.permissionManager.accessibilityGranted ? .green : .yellow
            )

            Divider().padding(.leading, 54)

            summaryRow(
                icon: "key.fill",
                iconColor: .orange,
                title: "API Key",
                value: "Configured",
                statusColor: .green
            )

            Divider().padding(.leading, 54)

            summaryRow(
                icon: "power",
                iconColor: .purple,
                title: "Launch at Login",
                value: viewModel.launchAtLogin ? "On" : "Off",
                statusColor: viewModel.launchAtLogin ? .green : .secondary
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Open Accessibility Settings") {
                viewModel.permissionManager.openAccessibilitySettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Summary Row

    private func summaryRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        isSystemIcon: Bool = true,
        statusColor: Color? = nil
    ) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                if isSystemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                } else {
                    Text(icon)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(iconColor)
                }
            }

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                if let statusColor {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                }

                Text(value)
                    .font(.callout.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Accent Color Extension

    private var accentColor: Color { .accentColor }
}

// MARK: - Preview

#Preview {
    OnboardingCompleteView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
