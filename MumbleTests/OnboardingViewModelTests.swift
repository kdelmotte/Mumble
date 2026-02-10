import XCTest
import SwiftUI
@testable import Mumble

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private var viewModel: OnboardingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = OnboardingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        ShortcutBinding.resetToDefault()
        ToneMappingConfig.default.save()
        super.tearDown()
    }

    // MARK: - Constants & Initial State

    func testTotalSteps_isSix() {
        XCTAssertEqual(OnboardingViewModel.totalSteps, 6)
    }

    func testInitialState_currentStepIsZero() {
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    func testInitialState_apiKeyIsEmpty() {
        XCTAssertEqual(viewModel.apiKey, "")
    }

    func testInitialState_keyTestResultIsNil() {
        XCTAssertNil(viewModel.keyTestResult)
    }

    func testInitialState_launchAtLoginIsTrue() {
        XCTAssertTrue(viewModel.launchAtLogin)
    }

    func testInitialState_demoTextIsEmpty() {
        XCTAssertEqual(viewModel.demoText, "")
    }

    func testInitialState_isDemoRecordingIsFalse() {
        XCTAssertFalse(viewModel.isDemoRecording)
    }

    func testInitialState_isDemoTranscribingIsFalse() {
        XCTAssertFalse(viewModel.isDemoTranscribing)
    }

    func testInitialState_demoAudioLevelIsZero() {
        XCTAssertEqual(viewModel.demoAudioLevel, 0.0)
    }

    // MARK: - Navigation

    func testCanGoBack_falseAtStepZero() {
        viewModel.currentStep = 0
        XCTAssertFalse(viewModel.canGoBack)
    }

    func testCanGoBack_trueAtStepOne() {
        viewModel.currentStep = 1
        XCTAssertTrue(viewModel.canGoBack)
    }

    func testCanGoForward_trueAtStepZero() {
        viewModel.currentStep = 0
        XCTAssertTrue(viewModel.canGoForward)
    }

    func testCanGoForward_falseAtLastStep() {
        viewModel.currentStep = OnboardingViewModel.totalSteps - 1
        XCTAssertFalse(viewModel.canGoForward)
    }

    func testIsLastStep_trueOnlyAtStepFive() {
        for step in 0..<OnboardingViewModel.totalSteps {
            viewModel.currentStep = step
            if step == OnboardingViewModel.totalSteps - 1 {
                XCTAssertTrue(viewModel.isLastStep, "Expected isLastStep to be true at step \(step)")
            } else {
                XCTAssertFalse(viewModel.isLastStep, "Expected isLastStep to be false at step \(step)")
            }
        }
    }

    func testGoToNextStep_increments() {
        viewModel.currentStep = 0
        viewModel.goToNextStep()
        XCTAssertEqual(viewModel.currentStep, 1)
    }

    func testGoToNextStep_clampedAtLastStep() {
        viewModel.currentStep = OnboardingViewModel.totalSteps - 1
        viewModel.goToNextStep()
        XCTAssertEqual(viewModel.currentStep, OnboardingViewModel.totalSteps - 1)
    }

    func testGoToPreviousStep_decrements() {
        viewModel.currentStep = 3
        viewModel.goToPreviousStep()
        XCTAssertEqual(viewModel.currentStep, 2)
    }

    func testGoToPreviousStep_clampedAtZero() {
        viewModel.currentStep = 0
        viewModel.goToPreviousStep()
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    // MARK: - canProceedFromStep

    func testCanProceedFromStep0_matchesPermissionState() {
        let pm = viewModel.permissionManager
        let expected = pm.microphoneGranted && pm.accessibilityGranted
        XCTAssertEqual(viewModel.canProceedFromStep(0), expected)
    }

    func testCanProceedFromStep1_falseWhenKeyTestResultIsNil() {
        viewModel.keyTestResult = nil
        XCTAssertFalse(viewModel.canProceedFromStep(1))
    }

    func testCanProceedFromStep1_falseWhenKeyTestResultIsFailure() {
        viewModel.keyTestResult = .failure("bad key")
        XCTAssertFalse(viewModel.canProceedFromStep(1))
    }

    func testCanProceedFromStep1_trueWhenKeyTestResultIsSuccess() {
        viewModel.keyTestResult = .success
        XCTAssertTrue(viewModel.canProceedFromStep(1))
    }

    func testCanProceedFromStep2_alwaysTrue() {
        XCTAssertTrue(viewModel.canProceedFromStep(2))
    }

    func testCanProceedFromStep3_alwaysTrue() {
        XCTAssertTrue(viewModel.canProceedFromStep(3))
    }

    func testCanProceedFromStep4_alwaysTrue() {
        XCTAssertTrue(viewModel.canProceedFromStep(4))
    }

    func testCanProceedFromStep5_alwaysTrue() {
        XCTAssertTrue(viewModel.canProceedFromStep(5))
    }

    func testCanProceedFromStep_outOfRangePositive_returnsFalse() {
        XCTAssertFalse(viewModel.canProceedFromStep(6))
    }

    func testCanProceedFromStep_outOfRangeNegative_returnsFalse() {
        XCTAssertFalse(viewModel.canProceedFromStep(-1))
    }

    // MARK: - Shortcut

    func testResetShortcutToDefault_setsDefaultFnKey() {
        viewModel.currentShortcut = ShortcutBinding(modifierFlagsRaw: 0, keyCode: 2)
        viewModel.resetShortcutToDefault()
        XCTAssertEqual(viewModel.currentShortcut, .defaultFnKey)
    }

    // MARK: - Tone Binding

    func testToneBinding_getterReturnsCorrectTone() {
        viewModel.toneMappingConfig = ToneMappingConfig(
            personal: .professional,
            work: .veryCasual,
            other: .casual
        )

        let personalBinding = viewModel.toneBinding(for: .personal)
        let workBinding = viewModel.toneBinding(for: .work)
        let otherBinding = viewModel.toneBinding(for: .other)

        XCTAssertEqual(personalBinding.wrappedValue, .professional)
        XCTAssertEqual(workBinding.wrappedValue, .veryCasual)
        XCTAssertEqual(otherBinding.wrappedValue, .casual)
    }

    func testToneBinding_setterUpdatesConfigAndPersists() {
        viewModel.toneMappingConfig = .default

        let binding = viewModel.toneBinding(for: .work)
        binding.wrappedValue = .professional

        XCTAssertEqual(viewModel.toneMappingConfig.tone(for: .work), .professional)

        let loaded = ToneMappingConfig.load()
        XCTAssertEqual(loaded.tone(for: .work), .professional)
    }

    // MARK: - completeOnboarding

    func testCompleteOnboarding_setsUserDefaultsFlag() {
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
        viewModel.completeOnboarding()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    func testCompleteOnboarding_savesShortcut() {
        let custom = ShortcutBinding(
            modifierFlagsRaw: NSEvent.ModifierFlags.command.rawValue,
            keyCode: 2
        )
        viewModel.currentShortcut = custom
        viewModel.completeOnboarding()

        let loaded = ShortcutBinding.load()
        XCTAssertEqual(loaded, custom)
    }

    func testCompleteOnboarding_savesToneConfig() {
        var config = ToneMappingConfig.default
        config.setTone(.professional, for: .personal)
        viewModel.toneMappingConfig = config
        viewModel.completeOnboarding()

        let loaded = ToneMappingConfig.load()
        XCTAssertEqual(loaded.tone(for: .personal), .professional)
    }
}
