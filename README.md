# Pixel Canvas

```swift
import SwiftUI
import PixelCanvas

struct ContentView: View {
    
    @State private var pixelCanvas = PixelCanvas()
    
    var body: some View {
        ZStack {
            PixelCanvasView(
                pixelCanvas,
                background: { pixels, frame in
                    ZStack {
                        pixels
                        pixels
                            .colorInvert()
                            .mask {
                                PixelCanvasLayout(frame: frame) {
                                    Rectangle()
                                }
                            }
                    }
                },
                foreground: {
                    ZStack {
                        Color.clear
                            .border(Color.red)
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(.red)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.red)
                    }
                }
            )
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    Button {
                        pixelCanvas.zoomToFill()
                    } label: {
                        Text("Zoom to Fill")
                    }
                }
                .padding()
                .background(.thinMaterial)
                .padding()
            }
        }
        .onAppear {
            pixelCanvas.load(
                image: Image("Kite"),
                resolution: CGSize(width: 3872, height: 2592)
            )
        }
    }
}

#Preview {
    ContentView()
}
```
