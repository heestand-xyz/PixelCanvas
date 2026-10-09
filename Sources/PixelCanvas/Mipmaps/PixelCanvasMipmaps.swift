import SwiftUI
import AsyncGraphics

/// Cached Lanczos reductions of an image, excluding the full-resolution original.
public struct PixelCanvasMipmaps {
    public let sourceResolution: CGSize
    private let levels: [PixelCanvasMipLevel]

    /// The generated resolutions, ordered from largest to smallest.
    public var resolutions: [CGSize] {
        levels.map(\.resolution)
    }

    /// Halves both dimensions until the longest edge reaches the cutoff or below.
    /// Stops earlier if either dimension would be too small for AsyncGraphics.
    public init(graphic: Graphic, minimumDimension: Int = 128) async throws {
        try Task.checkCancellation()
        sourceResolution = graphic.resolution
        let cutoff = CGFloat(max(2, minimumDimension))
        var current = graphic
        var levels: [PixelCanvasMipLevel] = []

        while max(current.width, current.height) > cutoff {
            let resolution = CGSize(
                width: (current.width / 2).rounded(.down),
                height: (current.height / 2).rounded(.down)
            )
            guard resolution.width > 1, resolution.height > 1 else { break }
            try Task.checkCancellation()
            current = try await current.resizedStretched(to: resolution, method: .lanczos)
            try Task.checkCancellation()
            let image = try await current.imageForSwiftUI
            try Task.checkCancellation()
            levels.append(PixelCanvasMipLevel(image: image, resolution: resolution))
        }

        self.levels = levels
    }

    /// Uses the smallest level that does not magnify pixels along either axis.
    /// Returning nil selects the original, including at native size and above.
    func image(for displayedResolution: CGSize) -> Image? {
        guard displayedResolution.width.isFinite, displayedResolution.height.isFinite,
              displayedResolution.width > 0, displayedResolution.height > 0 else { return nil }
        return levels.last {
            $0.resolution.width >= displayedResolution.width &&
            $0.resolution.height >= displayedResolution.height
        }?.image
    }
}
