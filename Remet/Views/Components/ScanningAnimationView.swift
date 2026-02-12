import SwiftUI

/// A native SwiftUI scanning animation - no external dependencies
struct ScanningAnimationView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var tintColor: Color = .blue

    var body: some View {
        ZStack {
            // Outer pulsing circles
            ForEach(0..<3) { index in
                Circle()
                    .stroke(tintColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .scaleEffect(pulseScale + CGFloat(index) * 0.2)
                    .opacity(isAnimating ? 0 : 1)
            }

            // Rotating scanner line
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tintColor, tintColor.opacity(0)]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // Center icon
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(tintColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
                isAnimating = true
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ScanningAnimationView(tintColor: .blue)
            .frame(width: 120, height: 120)

        ScanningAnimationView(tintColor: .green)
            .frame(width: 100, height: 100)
    }
}
