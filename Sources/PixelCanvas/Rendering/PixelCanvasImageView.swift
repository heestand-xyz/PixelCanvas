import SwiftUI

/// Renders native image pixels using a frame supplied by an external canvas.
/// The view stays viewport-sized even when the image is magnified far beyond it.
public struct PixelCanvasImageView: View {
    @Environment(\.displayScale) private var displayScale
    private let image: Image
    private let mipmaps: PixelCanvasMipmaps?
    private let resolution: CGSize
    private let frame: CGRect
    private let options: PixelCanvas.Options

    public init(
        image: Image,
        resolution: CGSize,
        frame: CGRect,
        options: PixelCanvas.Options = .init(),
        mipmaps: PixelCanvasMipmaps? = nil
    ) {
        self.image = image
        self.mipmaps = mipmaps
        self.resolution = resolution
        self.frame = frame
        var options = options
        options.placement = .fit
        self.options = options
    }

    public var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 0, geometry.size.height > 0,
               resolution.width > 0, resolution.height > 0, frame.width > 0, frame.height > 0 {
                PixelCanvasZoomView(
                    image: image,
                    mipmaps: mipmaps,
                    transform: PixelCanvas.transform(
                        contentResolution: resolution,
                        containerSize: geometry.size,
                        frame: frame,
                        displayScale: displayScale
                    ),
                    options: options
                )
            }
        }
    }
}
