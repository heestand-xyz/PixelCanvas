import SwiftUI

/// The same zoom-dependent transparency checker used behind PixelCanvas images.
public struct PixelCanvasCheckerView: View {
    private let resolution: CGSize
    private let frame: CGRect
    private let options: PixelCanvas.Options

    public init(resolution: CGSize, frame: CGRect, options: PixelCanvas.Options = .init()) {
        self.resolution = resolution
        self.frame = frame
        self.options = options
    }

    public var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 0, geometry.size.height > 0,
               resolution.width > 0, resolution.height > 0, frame.width > 0, frame.height > 0 {
                let transform = PixelCanvas.transform(contentResolution: resolution, containerSize: geometry.size, frame: frame)
                Rectangle()
                    .colorEffect(Shader(
                        function: ShaderFunction(library: .bundle(.module), name: "canvasChecker"),
                        arguments: [
                            .float2(frame.origin),
                            .float2(frame.size),
                            .float2(resolution),
                            .float(transform.scale),
                            .float(options.checkerSize),
                            .float(options.checkerOpacity)
                        ]
                    ))
            }
        }
    }
}
