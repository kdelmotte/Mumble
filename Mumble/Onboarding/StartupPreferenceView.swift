import SwiftUI

// MARK: - StartupPreferenceView (Step 5)

struct StartupPreferenceView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 40)

            // Launch at login toggle card
            launchAtLoginCard
                .staggeredEntrance(index: 0)

            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("MumbleIconStartup")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .mascotGlow(color: .purple)

            Text("Startup Preferences")
                .font(.mumbleDisplay(size: 28))

            Text("Configure how Mumble behaves when your Mac starts up.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Launch at Login Card

    private var launchAtLoginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $viewModel.launchAtLogin) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch Mumble at login")
                        .font(.mumbleHeadline())

                    Text("Mumble will start automatically when you log in so dictation is always ready.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("Mumble runs quietly in your menu bar using minimal resources. You can change this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .themedCard(accent: .purple, elevated: true)
    }
}

// MARK: - Preview

#Preview {
    StartupPreferenceView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
