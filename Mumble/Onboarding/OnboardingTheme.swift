// OnboardingTheme.swift
// Mumble
//
// Shared design system for the onboarding flow and settings views.
// Contains brand gradients, card modifiers, typography helpers,
// animation utilities, and reusable components.

import SwiftUI

// MARK: - MumbleTheme

enum MumbleTheme {

    // MARK: - Brand Gradient

    /// Primary brand gradient: coral -> peach -> warm gold.
    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.45, blue: 0.36),
            Color(red: 0.96, green: 0.65, blue: 0.49),
            Color(red: 0.96, green: 0.78, blue: 0.51),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Very subtle gradient tint for window/page backgrounds.
    static func subtleBackground(for colorScheme: ColorScheme) -> LinearGradient {
        let opacity: Double = colorScheme == .dark ? 0.06 : 0.04
        return LinearGradient(
            colors: [
                Color(red: 0.91, green: 0.45, blue: 0.36).opacity(opacity),
                Color(red: 0.96, green: 0.65, blue: 0.49).opacity(opacity * 0.7),
                Color(red: 0.96, green: 0.78, blue: 0.51).opacity(opacity),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Semantic Step Colors

    static func stepAccent(for step: Int) -> Color {
        switch step {
        case 0: return .red
        case 1: return .orange
        case 2: return .blue
        case 3: return .indigo
        case 4: return .teal
        case 5: return .purple
        case 6: return .green
        default: return .accentColor
        }
    }
}

// MARK: - Typography

extension Font {

    /// SF Pro Rounded for display/header text.
    static func mumbleDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Smaller rounded font for section headers and labels.
    static func mumbleHeadline(size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Themed Card Modifier

struct ThemedCardModifier: ViewModifier {
    let accentColor: Color
    let isElevated: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(
                        color: accentColor.opacity(isElevated ? 0.08 : 0.0),
                        radius: isElevated ? 12 : 0,
                        y: isElevated ? 4 : 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.15),
                                accentColor.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func themedCard(accent: Color = .secondary, elevated: Bool = false) -> some View {
        modifier(ThemedCardModifier(accentColor: accent, isElevated: elevated))
    }
}

// MARK: - Mascot Glow Modifier

struct MascotGlowModifier: ViewModifier {
    let glowColor: Color
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                glowColor.opacity(0.15 * intensity),
                                glowColor.opacity(0.05 * intensity),
                                Color.clear,
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .scaleEffect(1.8)
                    .blur(radius: 20)
            )
    }
}

extension View {
    func mascotGlow(color: Color, intensity: CGFloat = 1.0) -> some View {
        modifier(MascotGlowModifier(glowColor: color, intensity: intensity))
    }
}

// MARK: - Gradient Hairline Divider

struct GradientDivider: View {
    var body: some View {
        Rectangle()
            .fill(MumbleTheme.brandGradient)
            .frame(height: 1)
            .opacity(0.2)
    }
}

// MARK: - Step Progress Bar

struct StepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    @State private var animatedProgress: CGFloat = 0

    private var targetProgress: CGFloat {
        guard totalSteps > 1 else { return 1 }
        return CGFloat(currentStep) / CGFloat(totalSteps - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 4)

                // Filled portion with brand gradient
                Capsule()
                    .fill(MumbleTheme.brandGradient)
                    .frame(width: max(4, geometry.size.width * animatedProgress), height: 4)

                // Step dots overlaid on the bar
                HStack(spacing: 0) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.white : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(index <= currentStep ? MumbleTheme.stepAccent(for: index) : Color.clear)
                                    .frame(width: 6, height: 6)
                            )
                            .shadow(
                                color: index == currentStep
                                    ? MumbleTheme.stepAccent(for: index).opacity(0.4)
                                    : .clear,
                                radius: 4
                            )
                            .scaleEffect(index == currentStep ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)

                        if index < totalSteps - 1 {
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(height: 8)
        .onChange(of: currentStep) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = targetProgress
            }
        }
        .onAppear {
            animatedProgress = targetProgress
        }
    }
}

// MARK: - Mumble Button Style

struct MumbleButtonStyle: ButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(isProminent ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MumbleTheme.brandGradient)
                        .shadow(
                            color: Color(red: 0.91, green: 0.45, blue: 0.36).opacity(0.3),
                            radius: 6,
                            y: 2
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Staggered Entrance Animation

struct StaggeredAppearance: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                withAnimation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(baseDelay + Double(index) * 0.1)
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredEntrance(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredAppearance(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Gradient Checkmark

struct GradientCheckmark: View {
    @State private var isAnimated = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(MumbleTheme.brandGradient)
            .scaleEffect(isAnimated ? 1.0 : 0.5)
            .opacity(isAnimated ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isAnimated = true
                }
            }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var opacity: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = now - particle.startTime
                    guard elapsed > 0, elapsed < particle.lifetime else { continue }
                    let progress = elapsed / particle.lifetime
                    let x = particle.startX + sin(elapsed * particle.wobbleFrequency) * 20
                    let y = particle.startY + elapsed * particle.fallSpeed
                    let particleOpacity = 1.0 - progress
                    let rotation = elapsed * particle.rotationSpeed
                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size * 0.6
                    )
                    context.opacity = particleOpacity * 0.8
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: rect.midX, y: rect.midY)
                    transform = transform.rotated(by: rotation)
                    transform = transform.translatedBy(x: -rect.midX, y: -rect.midY)
                    context.concatenate(transform)
                    context.fill(
                        RoundedRectangle(cornerRadius: 1).path(in: rect),
                        with: .color(particle.color)
                    )
                    // Reset transform
                    context.concatenate(transform.inverted())
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            generateParticles()
            // Fade out after 3 seconds
            withAnimation(.easeOut(duration: 1.0).delay(2.5)) {
                opacity = 0
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles() {
        let colors: [Color] = [
            Color(red: 0.91, green: 0.45, blue: 0.36),
            Color(red: 0.96, green: 0.65, blue: 0.49),
            Color(red: 0.96, green: 0.78, blue: 0.51),
            .green, .teal, .orange,
        ]
        let now = Date.now.timeIntervalSinceReferenceDate
        particles = (0..<50).map { _ in
            ConfettiParticle(
                startX: Double.random(in: 0...520),
                startY: Double.random(in: -30...0),
                fallSpeed: Double.random(in: 40...90),
                wobbleFrequency: Double.random(in: 1...4),
                rotationSpeed: Double.random(in: -3...3),
                lifetime: Double.random(in: 2.5...4.0),
                color: colors.randomElement()!,
                size: Double.random(in: 4...8),
                startTime: now + Double.random(in: 0...0.6)
            )
        }
    }
}

private struct ConfettiParticle {
    let startX: Double
    let startY: Double
    let fallSpeed: Double
    let wobbleFrequency: Double
    let rotationSpeed: Double
    let lifetime: Double
    let color: Color
    let size: Double
    let startTime: Double
}
