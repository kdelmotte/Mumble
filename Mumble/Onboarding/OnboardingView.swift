import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 16)

            // Bottom bar: progress + navigation
            bottomBar
        }
        .frame(width: 520, height: 700)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                MumbleTheme.subtleBackground(for: colorScheme)
            }
        }
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
            MicrophoneSelectionView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 3:
            ShortcutSetupView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 4:
            ToneSetupView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 5:
            StartupPreferenceView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case 6:
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
        VStack(spacing: 0) {
            GradientDivider()

            VStack(spacing: 12) {
                // Progress bar
                StepProgressBar(
                    currentStep: viewModel.currentStep,
                    totalSteps: OnboardingViewModel.totalSteps
                )
                .padding(.horizontal, 20)

                // Navigation buttons
                HStack {
                    // Back button
                    if viewModel.canGoBack {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                viewModel.goToPreviousStep()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                            }
                        }
                        .buttonStyle(MumbleButtonStyle(isProminent: false))
                    } else {
                        Spacer()
                            .frame(width: 60)
                    }

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
                        .buttonStyle(MumbleButtonStyle(isProminent: true))
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                viewModel.goToNextStep()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Continue")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .buttonStyle(MumbleButtonStyle(isProminent: true))
                        .opacity(viewModel.canProceedFromStep(viewModel.currentStep) ? 1.0 : 0.5)
                        .disabled(!viewModel.canProceedFromStep(viewModel.currentStep))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}
