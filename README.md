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

## Opt-in mipmaps

Prepare Lanczos levels once while loading an image, then retain them with that
image to reuse when switching selections. The original image remains the source
for native-size pixel inspection. Mipmaps are disabled by default.

```swift
import AsyncGraphics

let image = try await graphic.imageForSwiftUI
let mipmaps = try await PixelCanvasMipmaps(graphic: graphic, minimumDimension: 128)
pixelCanvas.options.usesMipmaps = true
pixelCanvas.load(image: image, resolution: graphic.resolution, mipmaps: mipmaps)
```

Each level halves both dimensions, stopping when the longest edge is 128 pixels
or below (or earlier if a dimension would fall below 2 pixels). The shader hard
switches to the smallest level that covers the displayed size in physical pixels;
there is no crossfade. The original dimensions still control placement, checkers,
and pixel borders. The image-canvas fallback continues to use the original.

`PixelCanvasImageView` also accepts the prepared `mipmaps` alongside options with
`usesMipmaps` enabled. Preparing levels is explicit: `load(image:resolution:)`
alone keeps its existing behavior, and generation errors can fall back to that
original-only loading path.
