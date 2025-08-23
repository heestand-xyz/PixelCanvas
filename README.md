# Pixel Canvas

Pan and zoom images down to pixel level.

```swift
import SwiftUI
import PixelCanvas

struct ContentView: View {
    
    @StateObject private var pixelCanvas = PixelCanvas()
    
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
