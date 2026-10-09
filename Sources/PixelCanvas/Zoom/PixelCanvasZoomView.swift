import SwiftUI
import CoreGraphicsExtensions

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
struct PixelCanvasZoomView: View {
    
    let image: Image
    let mipmaps: PixelCanvasMipmaps?
    let transform: PixelCanvas.Transform
    let options: PixelCanvas.Options

    private var renderedImage: Image {
        guard options.usesMipmaps, let mipmaps,
              mipmaps.sourceResolution == transform.contentResolution else { return image }

        let placedResolution: CGSize
        switch options.placement {
        case .stretch:
            placedResolution = transform.containerResolution
        case .fit:
            placedResolution = transform.contentResolution.place(
                in: transform.containerResolution, placement: .fit, roundToPixels: false
            )
        case .fill:
            placedResolution = transform.contentResolution.place(
                in: transform.containerResolution, placement: .fill, roundToPixels: false
            )
        case .fixed:
            placedResolution = transform.contentResolution
        }
        return mipmaps.image(for: placedResolution * transform.scale) ?? image
    }
    
    private var shader: Shader {
        let function = ShaderFunction(library: .bundle(.module), name: "zoom")
        return Shader(function: function, arguments: [
            .image(renderedImage),
            .float(options.interpolate ? 1.0 : 0.0),
            .float(CGFloat(options.placement.rawValue)),
            .float2(transform.containerResolution),
            .float2(transform.contentResolution),
            .float(transform.scale),
            .float2(transform.offset),
            .float(options.checkerTransparency ? 1.0 : 0.0),
            .float(options.checkerSize),
            .float(options.checkerOpacity),
            .float(options.borderWidth),
            .float(options.borderOpacity),
            .float2(CGPoint(x: options.borderFadeRange.lowerBound,
                            y: options.borderFadeRange.upperBound)),
            .float(transform.displayScale)
        ])
    }
    
    var body: some View {
        Rectangle()
            .layerEffect(shader, maxSampleOffset: .zero, isEnabled: true)
    }
}
