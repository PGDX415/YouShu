//
//  SplashView.swift
//  YouShu
//

import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.02, green: 0.08, blue: 0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated rings
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .accentColor.opacity(0.6), .accentColor, .accentColor.opacity(0.3), .clear],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(ringRotation))
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .orange.opacity(0.4), .orange, .orange.opacity(0.2), .clear],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 340, height: 340)
                    .rotationEffect(.degrees(-ringRotation * 0.7))
                    .scaleEffect(ringScale * 0.9)
                    .opacity(ringOpacity * 0.6)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .accentColor.opacity(0.4), radius: 20, x: 0, y: 8)

                    Text("¥")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                Text("有数")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.top, 24)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                // Tagline
                Text("家庭记账 · 智慧理财")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(4)
                    .padding(.top, 12)
                    .opacity(titleOpacity)

                Spacer()

                // Loading indicator
                ProgressView()
                    .tint(.white.opacity(0.5))
                    .scaleEffect(0.8)
                    .padding(.bottom, 60)
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            animateIn()
        }
    }

    private func animateIn() {
        // Ring animation
        withAnimation(.easeOut(duration: 1.2)) {
            ringScale = 1.0
            ringOpacity = 0.5
        }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Logo scale + fade in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6, blendDuration: 0)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Title slide up + fade in
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            titleOffset = 0
            titleOpacity = 1.0
        }

        // Transition to main app after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isActive = false
            }
        }
    }
}

#Preview {
    SplashView(isActive: .constant(true))
}
