import SwiftUI

// MARK: - MicrophoneSelectionView (Step 2)

struct MicrophoneSelectionView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 40)

            // Microphone picker card
            microphoneCard
                .staggeredEntrance(index: 0)

            Spacer()
        }
        .onAppear {
            viewModel.refreshMicDevices()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("MumbleIconSettings")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .mascotGlow(color: .blue)

            Text("Choose Your Microphone")
                .font(.mumbleDisplay(size: 28))

            Text("System Default works for most setups. Pick a specific mic if you use an external one.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Microphone Card

    private var microphoneCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Input Device", selection: $viewModel.selectedMicUID) {
                    Text("System Default")
                        .tag("")

                    ForEach(viewModel.availableMicDevices, id: \.uid) { device in
                        Text(device.name)
                            .tag(device.uid)
                    }
                }
                .onChange(of: viewModel.selectedMicUID) { _, newValue in
                    viewModel.selectMicDevice(uid: newValue)
                }

                Button {
                    viewModel.refreshMicDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Refresh device list")
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("You can change this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .themedCard(accent: .blue, elevated: true)
    }
}

// MARK: - Preview

#Preview {
    MicrophoneSelectionView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
