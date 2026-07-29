import SwiftUI

struct MossWindowBackground: View {
    @AppStorage("backgroundImageEnabled") private var isEnabled = false
    @AppStorage("backgroundImageFileName") private var fileName = ""
    @AppStorage("backgroundBlurRadius") private var blurRadius = 24.0
    @AppStorage("backgroundImageOpacity") private var imageOpacity = 0.34

    private var image: NSImage? {
        guard isEnabled else { return nil }
        return BackgroundImageStore.image(fileName: fileName)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MossTheme.paper

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.08)
                        .blur(radius: blurRadius)
                        .opacity(imageOpacity)
                        .clipped()

                    MossTheme.paper.opacity(0.30)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
