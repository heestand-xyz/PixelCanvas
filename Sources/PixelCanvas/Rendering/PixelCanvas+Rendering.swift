import SwiftUI
import GestureCanvas
import CoreGraphicsExtensions

extension PixelCanvas {
    /// Adapts a frame in view points to the fitted coordinates used by the renderer.
    static func transform(
        contentResolution: CGSize,
        containerSize: CGSize,
        frame: CGRect,
        displayScale: CGFloat
    ) -> Transform {
        let fittedSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
        let fittedOrigin = contentOrigin(contentResolution: contentResolution, containerSize: containerSize)
        return transform(
            contentResolution: contentResolution,
            containerSize: containerSize,
            coordinate: GestureCanvasCoordinate(
                offset: frame.origin - fittedOrigin,
                scale: frame.height / fittedSize.height
            ),
            displayScale: displayScale
        )
    }
}
