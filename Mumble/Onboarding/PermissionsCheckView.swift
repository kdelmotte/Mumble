import SwiftUI

// MARK: - PermissionsCheckView (Step 1)

struct PermissionsCheckView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 20)

            // Privacy note
            privacyNote

            Spacer().frame(height: 20)

            // Permission rows
            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    iconColor: .red,
                    title: "Microphone",
                    description: "Required to capture audio for speech-to-text",
                    isGranted: viewModel.permissionManager.microphoneGranted,
                    action: viewModel.requestMicPermission
                )

                permissionRow(
                    icon: "accessibility",
                    iconColor: .blue,
                    title: "Accessibility",
                    description: "Required to type transcribed text into the active app",
                    isGranted: viewModel.permissionManager.accessibilityGranted,
                    action: viewModel.requestAccessibilityPermission
                )
            }

            // Warning if permissions are missing
            if viewModel.hasPermissionWarning {
                Spacer().frame(height: 16)
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
                .frame(height: 120)

            Text("Welcome to Mumble")
                .font(.title.bold())

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

            Text("Audio is sent to Groq for transcription. No data is stored.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Permission Row

    private func permissionRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status + Action
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    PermissionsCheckView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
