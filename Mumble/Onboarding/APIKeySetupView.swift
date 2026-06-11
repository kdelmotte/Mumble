import SwiftUI

// MARK: - APIKeySetupView (Step 2 — API Key)

struct APIKeySetupView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 32)

            // API key input card
            apiKeyCard

            Spacer().frame(height: 20)

            // Test result
            if let result = viewModel.keyTestResult {
                testResultView(result)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.keyTestResult)
            }

            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("MumbleIconAPIKey")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .mascotGlow(color: .orange)

            Text("Connect a Provider")
                .font(.mumbleDisplay(size: 28))

            Text("Choose your transcription provider and model, then add the API key you want Mumble to use during dictation.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - API Key Card

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Provider", selection: providerBinding) {
                ForEach(TranscriptionProvider.allCases) { provider in
                    Text(provider.displayName)
                        .tag(provider)
                }
            }
            .pickerStyle(.menu)

            Picker("Model", selection: modelBinding) {
                ForEach(viewModel.availableModels) { model in
                    Text(model.displayName)
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.availableModels.count == 1)

            if let detail = viewModel.selectedModel.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Link(viewModel.selectedProvider.keySetupLabel, destination: viewModel.selectedProvider.keySetupURL)
                    .font(.callout)
            }

            // Secure input field
            HStack(spacing: 10) {
                SecureField(viewModel.selectedProvider.apiKeyPlaceholder, text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($isKeyFieldFocused)

                validationIndicator
            }
        }
        .themedCard(accent: .orange, elevated: true)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isKeyFieldFocused
                        ? MumbleTheme.brandGradient
                        : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isKeyFieldFocused ? 2 : 0
                )
                .animation(.easeInOut(duration: 0.2), value: isKeyFieldFocused)
        )
    }

    // MARK: - Validation Indicator

    @ViewBuilder
    private var validationIndicator: some View {
        if viewModel.isTestingKey {
            ProgressView()
                .controlSize(.small)
        } else if viewModel.keyTestResult == .success {
            GradientCheckmark()
        } else if case .failure = viewModel.keyTestResult {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 16))
        }
    }

    // MARK: - Test Result

    private func testResultView(_ result: KeyTestResult) -> some View {
        HStack(spacing: 10) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)

                Text("Key valid! Your API key has been saved securely to your local Keychain.")
                    .font(.callout)
                    .foregroundStyle(.green)

            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(accent: result == .success ? .green : .red)
    }

    private var providerBinding: Binding<TranscriptionProvider> {
        Binding(
            get: { viewModel.selectedProvider },
            set: { viewModel.selectProvider($0) }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedModel.id },
            set: { viewModel.selectModel($0) }
        )
    }
}

// MARK: - Preview

#Preview {
    APIKeySetupView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
