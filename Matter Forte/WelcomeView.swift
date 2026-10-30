//
//  WelcomeView.swift
//  Matter Forte
//  Created by Prosperity on 29/10/2026.

import SwiftUI

extension Color {
    static let appOrange = Color(
        red: 240 / 255,
        green: 105 / 255,
        blue: 44 / 255
    )
}

struct MatterForteAppView: View {
    var body: some View {
        ContentView()
    }
}

struct NextView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.appOrange)
                Text("Let’s get started")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Welcome to Matter Forte.")
                    .foregroundStyle(.secondary)
            }
            .padding(32)
        }
        .navigationTitle("Get Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MatterForteRootView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showingWelcome = false

    var body: some View {

        MatterForteScene(
            appeared: appeared,
            showingWelcome: showingWelcome,
            onContinue: onContinue
        )
        .task { @MainActor in
            guard !showingWelcome else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.85, dampingFraction: 0.8)) {
                appeared = true
            }
            do {
                try await Task.sleep(nanoseconds: reduceMotion ? 500_000_000 : 3_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) {
                showingWelcome = true
            }
        }
    }
}

struct SplashView: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        MatterForteScene(appeared: appeared, showingWelcome: false, onContinue: {})
            .task { @MainActor in
                withAnimation(reduceMotion ? nil : .spring(response: 0.85, dampingFraction: 0.8)) {
                    appeared = true
                }
                do {
                    try await Task.sleep(nanoseconds: reduceMotion ? 500_000_000 : 3_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                onFinished()
            }
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        MatterForteScene(appeared: true, showingWelcome: true, onContinue: onContinue)
    }
}

private struct MatterForteScene: View {
    let appeared: Bool
    let showingWelcome: Bool
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let arcHeight = min(width * 0.2, 90)

            ZStack {
                Color(uiColor: .systemBackground)

                Ellipse()
                    .fill(Color.appOrange)
                    .frame(width: width * 0.65, height: width * 0.48)
                    .position(x: width * 0.91, y: height * 0.06)
                    .offset(
                        x: showingWelcome ? 60 : (appeared ? 0 : 50),
                        y: showingWelcome ? -80 : (appeared ? 0 : -50)
                    )
                    .opacity(showingWelcome ? 0 : 1)
                    .accessibilityHidden(true)

                Ellipse()
                    .fill(Color.appOrange)
                    .frame(width: width * 0.94, height: width * 0.88)
                    .position(x: width * 0.36, y: height * 0.89)
                    .offset(x: appeared ? 0 : -70, y: appeared ? 0 : 70)
                    .opacity(showingWelcome ? 0 : 1)
                    .accessibilityHidden(true)

                WelcomePanel(arcHeight: arcHeight)
                    .fill(Color.appOrange)
                    .frame(height: height * 0.52)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: showingWelcome || reduceMotion ? 0 : height * 0.16)
                    .opacity(showingWelcome ? 1 : 0)
                    .accessibilityHidden(true)

                MatterForteLogo(animateLetters: true, revealed: appeared)
                    .frame(width: min(width * 0.64, 280))
                    .position(x: width / 2, y: height * (showingWelcome ? 0.28 : 0.44))

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    welcomeContent(bottomInset: geometry.safeAreaInsets.bottom, width: width)
                        .frame(height: height * 0.36)
                }
                .offset(y: showingWelcome || reduceMotion ? 0 : 24)
                .opacity(showingWelcome ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).delay(0.2),
                    value: showingWelcome
                )
                .allowsHitTesting(showingWelcome)
                .accessibilityHidden(!showingWelcome)
            }
            .clipped()
        }
        .ignoresSafeArea()
    }

    private func welcomeContent(bottomInset: CGFloat, width: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 30) {
                Text("Welcome!")
                    .font(.system(size: 36, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                Text("Pick up where you left off or let’s get you started!")
                    .font(.system(size: 23, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(MatterPressStyle())
                .padding(.horizontal, width * 0.09)
                .padding(.top, 9)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.bottom, max(bottomInset, 28))
        }
    }
}
private struct WelcomePanel: Shape {
    let arcHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: arcHeight))
        path.addCurve(
            to: CGPoint(x: rect.width, y: arcHeight),
            control1: CGPoint(x: rect.width * 0.30, y: -arcHeight / 3),
            control2: CGPoint(x: rect.width * 0.70, y: -arcHeight / 3)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct MatterForteLogo: View {
    var animateLetters = false
    var revealed = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let letters = Array("MATTER")

    private var isVisible: Bool {
        !animateLetters || revealed || reduceMotion
    }

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                let scale = geometry.size.width / 100
                ZStack {
                    logoPath([
                        CGPoint(x: 0, y: 23), CGPoint(x: 50, y: 46),
                        CGPoint(x: 50, y: 59), CGPoint(x: 12, y: 41),
                        CGPoint(x: 12, y: 76), CGPoint(x: 50, y: 94),
                        CGPoint(x: 50, y: 107), CGPoint(x: 0, y: 83)
                    ], scale: scale)
                    .fill(Color.appOrange)

                    logoPath([
                        CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 23),
                        CGPoint(x: 100, y: 83), CGPoint(x: 88, y: 89),
                        CGPoint(x: 88, y: 42), CGPoint(x: 50, y: 59),
                        CGPoint(x: 50, y: 46), CGPoint(x: 86, y: 29),
                        CGPoint(x: 50, y: 12)
                    ], scale: scale)
                    .fill(Color.appOrange)
                }
            }
            .frame(width: 88, height: 95)
            .opacity(isVisible ? 1 : 0)
            .animation(
                animateLetters && !reduceMotion ? .easeOut(duration: 0.4) : nil,
                value: revealed
            )

            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    ForEach(letters.indices, id: \.self) { index in
                        Text(String(letters[index]))
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .offset(x: isVisible ? 0 : -35, y: isVisible ? 0 : 18)
                            .opacity(isVisible ? 1 : 0)
                            .animation(
                                animateLetters && !reduceMotion
                                    ? .spring(response: 0.55, dampingFraction: 0.8)
                                        .delay(0.30 + Double(index) * 0.18)
                                    : nil,
                                value: revealed
                            )
                    }
                }
                Text("FORTE")
                    .font(.system(size: 14, weight: .light))
                    .tracking(10)
                    .opacity(isVisible ? 1 : 0)
                    .animation(
                        animateLetters && !reduceMotion
                            ? .easeIn(duration: 0.4).delay(1.55)
                            : nil,
                        value: revealed
                    )
            }
            .foregroundStyle(Color.primary.opacity(isVisible ? 1 : 0.3))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Matter Forte")
    }

    private func logoPath(_ points: [CGPoint], scale: CGFloat) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
            }
            path.closeSubpath()
        }
    }
}

private struct MatterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MatterForteViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MatterForteAppView()
                .previewDisplayName("Splash, welcome, and navigation")
            WelcomeView(onContinue: {})
                .previewDisplayName("Welcome")
        }
    }
}
