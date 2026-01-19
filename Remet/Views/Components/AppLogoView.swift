import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 120

    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.coral.opacity(0.15), AppColors.teal.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Face shape
            ZStack {
                // Left half (coral)
                FaceHalfShape(isLeft: true)
                    .stroke(AppColors.coral, style: StrokeStyle(lineWidth: 6 * scale, lineCap: .round))

                // Right half (teal)
                FaceHalfShape(isLeft: false)
                    .stroke(AppColors.teal, style: StrokeStyle(lineWidth: 6 * scale, lineCap: .round))

                // Left eye
                Circle()
                    .fill(AppColors.coral)
                    .frame(width: 14 * scale, height: 14 * scale)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 6 * scale, height: 6 * scale)
                    )
                    .offset(x: -16 * scale, y: -9 * scale)

                // Right eye
                Circle()
                    .fill(AppColors.teal)
                    .frame(width: 14 * scale, height: 14 * scale)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 6 * scale, height: 6 * scale)
                    )
                    .offset(x: 16 * scale, y: -9 * scale)

                // Smile
                SmileShape()
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.coral, AppColors.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round)
                    )
                    .frame(width: 38 * scale, height: 18 * scale)
                    .offset(y: 14 * scale)
            }
            .frame(width: size * 0.7, height: size * 0.7)

            // Memory sparkles
            Circle()
                .fill(AppColors.coral.opacity(0.8))
                .frame(width: 8 * scale, height: 8 * scale)
                .offset(x: -34 * scale, y: -34 * scale)

            Circle()
                .fill(AppColors.coral.opacity(0.5))
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: -40 * scale, y: -24 * scale)

            Circle()
                .fill(AppColors.teal.opacity(0.8))
                .frame(width: 8 * scale, height: 8 * scale)
                .offset(x: 34 * scale, y: -34 * scale)

            Circle()
                .fill(AppColors.teal.opacity(0.5))
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: 40 * scale, y: -24 * scale)
        }
    }
}

// MARK: - Supporting Shapes

struct FaceHalfShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        if isLeft {
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: true
            )
        } else {
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        return path
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.3),
            control: CGPoint(x: rect.midX, y: rect.height)
        )
        return path
    }
}

// MARK: - Logo with Text

struct AppLogoWithText: View {
    var logoSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 12) {
            AppLogoView(size: logoSize)

            Text("Remet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.coral, AppColors.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

#Preview("Logo Small") {
    AppLogoView(size: 60)
}

#Preview("Logo Medium") {
    AppLogoView(size: 120)
}

#Preview("Logo Large") {
    AppLogoView(size: 200)
}

#Preview("Logo with Text") {
    AppLogoWithText(logoSize: 100)
}
