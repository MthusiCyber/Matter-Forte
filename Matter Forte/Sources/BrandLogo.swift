import SwiftUI

struct BrandLogo: View {
    var scale: CGFloat = 1
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 10 * scale) {
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height

                    path.move(
                        to: CGPoint(x: w * 0.54, y: h * 0.06)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.88, y: h * 0.25)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.88, y: h * 0.78)
                    )

                    path.move(
                        to: CGPoint(x: w * 0.88, y: h * 0.25)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.50, y: h * 0.46)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.15, y: h * 0.29)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.15, y: h * 0.80)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.49, y: h * 0.96)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.40, blue: 0.21),
                            Color(
                                red: 0.65,
                                green: 0.17,
                                blue: 0.13
                            )
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 8 * scale,
                        lineCap: .square,
                        lineJoin: .miter
                    )
                )
            }
            .frame(width: 76 * scale, height: 76 * scale)

            Text("MATTER")
                .font(.system(size: 27 * scale, weight: .semibold))
                .tracking(7 * scale)
                .foregroundStyle(
                    colorScheme == .dark ? Color.primary : Color(red: 0.40, green: 0.30, blue: 0.34)
                )

            Text("FORTE")
                .font(.system(size: 11 * scale))
                .tracking(8 * scale)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Matter Forte")
    }
}

