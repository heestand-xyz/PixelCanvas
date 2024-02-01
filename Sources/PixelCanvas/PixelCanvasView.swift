import SwiftUI
import Canvas
import CoreGraphicsExtensions

public struct PixelCanvasView<Foreground: View, Background: View>: View {
    
    @ObservedObject private var pixelCanvas: PixelCanvas
    @StateObject private var canvas = CCanvas(physics: false)
    
    private let background: (_ pixels: AnyView, _ frame: CGRect) -> Background
    private let foreground: () -> Foreground
    
    @State private var size: CGSize = .one
    
    public init(
        _ pixelCanvas: PixelCanvas,
        @ViewBuilder background: @escaping (AnyView, CGRect) -> Background = { pixels, _ in pixels },
        @ViewBuilder foreground: @escaping () -> Foreground = { EmptyView() }
    ) {
        self.pixelCanvas = pixelCanvas
        self.background = background
        self.foreground = foreground
    }
    
    public var body: some View {
        
        ZStack {
            
            background(AnyView(pixelBody), pixelCanvas.canvasContentFrame)
            
            CCanvasView(canvas: canvas)
            
            PixelCanvasLayout(frame: pixelCanvas.canvasContentFrame) {
                foreground()
            }
        }
        .readGeometry(size: $size)
        .onChange(of: canvas.coordinate) { newCoordinate in
            pixelCanvas.canvasCoordinate = newCoordinate
            pixelCanvas.reFrame()
        }
        .onChange(of: size) { newSize in
            canvas.size = newSize
            pixelCanvas.canvasContainerSize = newSize
            pixelCanvas.reFrame()
        }
        .onAppear {
            guard let resolution = pixelCanvas.content?.resolution else { return }
            canvas.contentAspectRatio = resolution.aspectRatio
        }
        .onChange(of: pixelCanvas.content?.resolution) { newResolution in
            guard let newResolution else { return }
            canvas.contentAspectRatio = newResolution.aspectRatio
        }
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
            if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
                PixelCanvasZoomView(
                    image: content.image,
                    transform: PixelCanvas.transform(
                        contentResolution: content.resolution,
                        containerSize: size,
                        coordinate: canvas.coordinate
                    ),
                    options: pixelCanvas.options
                )
                .id(content.id)
            } else {
                PixelCanvasLayout(frame: pixelCanvas.canvasContentFrame) {
                    content.image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
    }
}
