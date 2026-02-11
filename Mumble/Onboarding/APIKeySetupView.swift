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

            Text("Connect to Groq")
                .font(.title.bold())

            Text("Mumble uses Groq's Whisper model for fast, accurate transcription.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - API Key Card

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Link to Groq console
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Link("Get a free API key at console.groq.com",
                     destination: URL(string: "https://console.groq.com/keys")!)
                    .font(.callout)
            }

            // Secure input field
            HStack(spacing: 10) {
                SecureField("Paste your Groq API key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($isKeyFieldFocused)

                validationIndicator
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Validation Indicator

    @ViewBuilder
    private var validationIndicator: some View {
        if viewModel.isTestingKey {
            ProgressView()
                .controlSize(.small)
        } else if viewModel.keyTestResult == .success {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            result == .success
                ? Color.green.opacity(0.06)
                : Color.red.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.keyTestResult)
    }
}

// MARK: - Preview

#Preview {
    APIKeySetupView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
