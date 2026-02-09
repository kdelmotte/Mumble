import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 16)

            Divider()

            // Bottom bar: step dots + navigation
            bottomBar
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
        }
        .frame(width: 520, height: 700)
        .background(.background)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case 0:
            PermissionsCheckView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 1:
            APIKeySetupView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 2:
            ShortcutSetupView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 3:
            ToneSetupView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 4:
            StartupPreferenceView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 5:
            OnboardingCompleteView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        default:
            EmptyView()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Back button
            if viewModel.canGoBack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.goToPreviousStep()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Spacer()
                    .frame(width: 60)
            }

            Spacer()

            // Step indicator dots
            stepIndicator

            Spacer()

            if viewModel.isLastStep {
                Button(action: {
                    viewModel.completeOnboarding()
                }) {
                    HStack(spacing: 4) {
                        Text("Start Mumbling")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.goToNextStep()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!viewModel.canProceedFromStep(viewModel.currentStep))
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingViewModel.totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == viewModel.currentStep ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}
