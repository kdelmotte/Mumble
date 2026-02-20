import SwiftUI

// MARK: - PermissionsCheckView (Step 1)

struct PermissionsCheckView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 12)

            // Privacy note
            privacyNote

            Spacer().frame(height: 12)

            // Permission rows
            VStack(spacing: 12) {
                permissionRow(
                    icon: "mic.fill",
                    iconColor: .red,
                    title: "Microphone",
                    description: "Required to capture audio for speech-to-text",
                    isGranted: viewModel.permissionManager.microphoneGranted,
                    action: viewModel.requestMicPermission,
                    index: 0
                )

                permissionRow(
                    icon: "accessibility",
                    iconColor: .blue,
                    title: "Accessibility",
                    description: "Required to type transcribed text into the active app",
                    isGranted: viewModel.permissionManager.accessibilityGranted,
                    action: viewModel.requestAccessibilityPermission,
                    index: 1
                )
            }

            // Warning if permissions are missing
            if viewModel.hasPermissionWarning {
                Spacer().frame(height: 10)
                permissionWarning
            }

            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("MumbleIconPermissions")
                .resizable()
                .scaledToFit()
                .frame(height: 90)
                .mascotGlow(color: .red)

            Text("Welcome to Mumble")
                .font(.mumbleDisplay(size: 28))

            Text("Fast speech-to-text dictation, right from your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            Text("Audio is sent to your own Groq instance for transcription. No data is stored.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(accent: .green)
    }

    // MARK: - Permission Row

    private func permissionRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void,
        index: Int
    ) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.15), iconColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mumbleHeadline())

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status + Action
            if isGranted {
                GradientCheckmark()
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .themedCard(accent: iconColor, elevated: isGranted)
        .staggeredEntrance(index: index)
    }

    // MARK: - Permission Warning

    private var permissionWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text("Both permissions are required to continue. Mumble needs microphone access to hear you and accessibility access to type for you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(accent: .yellow)
    }
}

// MARK: - Preview

#Preview {
    PermissionsCheckView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
