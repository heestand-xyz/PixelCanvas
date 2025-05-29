import SwiftUI
import GestureCanvas
import CoreGraphicsExtensions
import DisplayLink

public struct PixelCanvasView<Foreground: View, Background: View>: View {
    
    @Bindable private var pixelCanvas: PixelCanvas
    @State private var gestureCanvas = GestureCanvas()
        
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
            background(AnyView(pixelBody), pixelCanvas.contentFrame)
            GestureCanvasView(canvas: gestureCanvas) { $0 } content: {
                PixelCanvasLayout(frame: pixelCanvas.contentFrame) {
                    foreground()
                }
            }
        }
        .readGeometry(size: $size)
        .onAppear {
            gestureCanvas.minimumScale = 0.1
            gestureCanvas.maximumScale = nil
            gestureCanvas.delegate = pixelCanvas
        }
        .onChange(of: gestureCanvas.coordinate) { _, newCoordinate in
            pixelCanvas.coordinate = newCoordinate
            pixelCanvas.reFrame()
        }
        .onChange(of: size) { _, newSize in
            pixelCanvas.containerSize = newSize
            pixelCanvas.reFrame()
        }
#if !os(macOS)
        .onReceive(pixelCanvas.pinchCoordinateOffsetUpdate) { offset in
            gestureCanvas.pinchCoordinateOffset = offset
        }
#endif
        .onChange(of: pixelCanvas.content?.resolution) { _, resolution in
            if let resolution: CGSize {
                gestureCanvas.maximumScale = max(resolution.width, resolution.height) / 2
            } else {
                gestureCanvas.maximumScale = nil
            }
        }
        .onReceive(pixelCanvas.canvasZoom) { zoom in
            gestureCanvas.move(to: zoom.coordinate, animated: zoom.animated)
        }
    }
    
    @ViewBuilder
    private var pixelBody: some View {
        if let content: PixelCanvas.Content = pixelCanvas.content {
            if !pixelCanvas.options.alwaysUseImageCanvas {
                PixelCanvasZoomView(
                    image: content.image,
                    transform: PixelCanvas.transform(
                        contentResolution: content.resolution,
                        containerSize: size,
                        coordinate: gestureCanvas.coordinate
                    ),
                    options: pixelCanvas.options
                )
                .id(content.id)
            } else {
                PixelCanvasLayout(frame: pixelCanvas.contentFrame) {
                    content.image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
    }
}
