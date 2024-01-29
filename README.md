# Pixel Canvas

Pan and zoom images down to pixel level.

For iOS (v16), macOS (v13) and visionOS (v1).

Note that pixel level detail with a SwiftUI shader is only available for iOS (v17), macOS (v14) and visionOS (v1).

```swift
import SwiftUI
import PixelCanvas

struct ContentView: View {
    
    @State private var pixelCanvas = PixelCanvas()
    
    var body: some View {
        PixelCanvasView(
            pixelCanvas,
            background: { pixels, frame in
                ZStack {
                    pixels
                    PixelCanvasLayout(frame: frame) {
                        // Background
                    }
                }
            },
            foreground: {
                // Foreground
            }
        )
        .onAppear {
            pixelCanvas.load(
                image: Image("..."),
                resolution: CGSize(width: 3_000, height: 2_000)
            )
        }
    }
}

#Preview {
    ContentView()
}
```
