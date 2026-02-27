import SwiftUI

struct FaceBoundingBoxOverlay: View {
    let box: FaceBoundingBox
    let isSelected: Bool
    let imageSize: CGSize
    let viewSize: CGSize

    // Minimum tap target size (Apple HIG recommends 44x44)
    private let minTapTarget: CGFloat = 44

    var body: some View {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Convert normalized coordinates to view coordinates
        let x = offsetX + box.x * scaledWidth
        let y = offsetY + (1 - box.y - box.height) * scaledHeight
        let width = box.width * scaledWidth
        let height = box.height * scaledHeight

        // Calculate tap target size (at least minTapTarget)
        let tapWidth = max(width, minTapTarget)
        let tapHeight = max(height, minTapTarget)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isSelected ? 3 : 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(boxColor.opacity(0.1))
                )
                .frame(width: width, height: height)

            if let name = box.personName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(boxColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .offset(y: 16)
            }
        }
        // Use larger frame for tap target while keeping visual size
        .frame(width: tapWidth, height: tapHeight)
        .contentShape(Rectangle()) // Ensure entire frame is tappable
        .position(x: x + width / 2, y: y + height / 2)
    }

    private var boxColor: Color {
        if box.isAutoAccepted {
            return .green
        } else if box.personId != nil {
            return .blue
        } else {
            return .orange
        }
    }
}

struct FaceRowView: View {
    let box: FaceBoundingBox
    let index: Int
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading) {
                if let name = box.personName {
                    Text(name)
                        .fontWeight(.medium)

                    if let confidence = box.confidence {
                        HStack(spacing: 4) {
                            Text("\(Int(confidence * 100))% match")
                            if box.isAutoAccepted {
                                Text("• Auto-accepted")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown person")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if box.personId != nil {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onTap()
            } label: {
                Image(systemName: box.personId == nil ? "plus.circle.fill" : "pencil.circle.fill")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        if box.isAutoAccepted {
            return .green
        } else if box.personId != nil {
            return .blue
        } else {
            return .orange
        }
    }
}
