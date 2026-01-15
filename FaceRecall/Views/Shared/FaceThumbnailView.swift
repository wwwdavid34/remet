import SwiftUI

struct FaceThumbnailView: View {
    let imageData: Data?
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let data = imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    FaceThumbnailView(imageData: nil)
}
