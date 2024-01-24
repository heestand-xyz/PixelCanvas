import SwiftUI
import Canvas
import CoreGraphicsExtensions

public struct PixelCanvasView<Foreground: View, Background: View>: View {
    
    @Bindable private var pixelCanvas: PixelCanvas
    @StateObject private var canvas = CCanvas(physics: false)
    
    private let background: (_ pixels: AnyView, _ frame: CGRect) -> Background
    private let foreground: () -> Foreground
    
    @State private var size: CGSize = .one
    
    public init(
        _ pixelCanvas: PixelCanvas,
        background: @escaping (AnyView, CGRect) -> Background = { pixels, _ in pixels },
        foreground: @escaping () -> Foreground = { EmptyView() }
    ) {
        _pixelCanvas = Bindable(pixelCanvas)
        self.background = background
        self.foreground = foreground
    }
    
    public var body: some View {
        
        ZStack {
            
            background(AnyView(pixelBody), pixelCanvas.canvasContentFrame)
            
            CCanvasView(canvas: canvas)
                .read(size: $size)
            
            PixelCanvasLayout(frame: pixelCanvas.canvasContentFrame) {
                foreground()
            }
        }
        .onChange(of: canvas.coordinate) { _, newCoordinate in
            pixelCanvas.canvasCoordinate = newCoordinate
            pixelCanvas.reFrame()
        }
        .onChange(of: size) { _, newSize in
            canvas.size = newSize
            pixelCanvas.canvasContainerSize = newSize
            pixelCanvas.reFrame()
        }
        .onChange(of: pixelCanvas.content?.resolution, { _, newResolution in
            guard let newResolution else { return }
            canvas.contentAspectRatio = newResolution.aspectRatio
        })
        .onReceive(pixelCanvas.canvasZoom) { zoom in
            canvas.move(
                to: zoom.coordinate,
                animatedDuration: zoom.animated ? pixelCanvas.options.animationDuration : nil
            )
        }
    }
    
    @ViewBuilder
    private var pixelBody: some View {
        if let content: PixelCanvas.Content = pixelCanvas.content {
            PixelCanvasZoomView(
                image: content.image,
                transform: PixelCanvas.transform(
                    contentResolution: content.resolution,
                    containerSize: size,
                    coordinate: canvas.coordinate
                ),
                options: pixelCanvas.options
            )
        }
    }
}
