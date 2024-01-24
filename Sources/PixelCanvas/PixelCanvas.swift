import Foundation
import Observation
import SwiftUI
import Combine
import Canvas
import CoreGraphicsExtensions

@Observable
public final class PixelCanvas {
    
    public enum Placement: Int {
        case stretch
        case fit
        case fill
        case fixed
    }
    
    public struct Options {
        public var animationDuration: TimeInterval = 1.0 / 3.0
        public var checkerTransparency: Bool = false
        public var checkerOpacity: CGFloat = 0.5
        public var checkerSize: CGFloat = 100
        public var borderWidth: CGFloat = 1.0
        public var borderFadeRange: ClosedRange<CGFloat> = 25...50
        public var borderOpacity: CGFloat = 0.25
        public var placement: Placement = .fit
    }
    public var options = Options()
    
    struct Content {
        let image: Image
        let resolution: CGSize
    }
    var content: Content?

    var canvasContainerSize: CGSize = .one
    var canvasCoordinate: CCanvasCoordinate = .zero
    public var scale: CGFloat {
        get {
            canvasCoordinate.scale
        }
        set {
            canvasCoordinate.scale = newValue
            reFrame()
        }
    }
    public var offset: CGPoint {
        get {
            canvasCoordinate.offset
        }
        set {
            canvasCoordinate.offset = newValue
            reFrame()
        }
    }
    var canvasContentFrame: CGRect = .one
    public var frame: CGRect {
        get {
            canvasContentFrame
        }
        set {
            guard let content: Content else { return }
            canvasCoordinate = Self.coordinate(
                contentResolution: content.resolution,
                contentFrame: newValue,
                containerSize: canvasContainerSize
            )
        }
    }

    struct Zoom {
        let coordinate: CCanvasCoordinate
        let animated: Bool
    }
    let canvasZoom = PassthroughSubject<Zoom, Never>()
    
    public init() {}
}

// MARK: - Coordinates

extension PixelCanvas {
 
    func coordinate(contentResolution: CGSize, contentFrame: CGRect? = nil, padding: CGSize) -> CCanvasCoordinate {
        Self.coordinate(
            contentResolution: contentResolution,
            contentFrame: contentFrame ?? CGRect(origin: .zero, size: contentResolution),
            containerSize: canvasContainerSize,
            padding: padding
        )
    }
    
    private static func coordinate(
        contentResolution: CGSize,
        contentFrame: CGRect,
        containerSize: CGSize,
        padding: CGSize = .zero
    ) -> CCanvasCoordinate {
        
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit)
        let resolutionScale = contentSize.height / contentResolution.height
        let contentCropFrame = CGRect(
            origin: contentFrame.origin * resolutionScale - padding,
            size: contentFrame.size * resolutionScale + padding * 2
        )
        
        let containerAspectRatio: CGFloat = containerSize.aspectRatio
        let contentCropAspectRatio: CGFloat = contentCropFrame.size.aspectRatio
        
        let containerCropFillSize = CGSize(
            width: containerAspectRatio < contentCropAspectRatio ? contentCropFrame.width : contentCropFrame.height * containerAspectRatio,
            height: containerAspectRatio > contentCropAspectRatio ? contentCropFrame.height : contentCropFrame.width / containerAspectRatio
        )
        
        let contentOrigin: CGPoint = (containerSize - contentSize).asPoint / 2
        let centerOffset: CGPoint = (containerCropFillSize - contentCropFrame.size).asPoint / 2
        
        let scale: CGFloat = if containerAspectRatio > contentCropAspectRatio {
            containerSize.height / contentCropFrame.height
        } else {
            containerSize.width / contentCropFrame.width
        }
        
        let offset: CGPoint = -contentOrigin - contentCropFrame.origin * scale + centerOffset * scale
        
        return CCanvasCoordinate(
            offset: offset,
            scale: scale,
            angle: .zero
        )
    }
}

// MARK: - Frame

extension PixelCanvas {
    
    func reFrame() {
        guard let content: Content else { return }
        canvasContentFrame = Self.frame(
            contentResolution: content.resolution,
            containerSize: canvasContainerSize,
            coordinate: canvasCoordinate
        )
    }
    
    static func frame(
        contentResolution: CGSize,
        containerSize: CGSize,
        coordinate: CCanvasCoordinate
    ) -> CGRect {
        let containerAspectRatio: CGFloat = containerSize.aspectRatio
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit)
        let contentAspectRatio: CGFloat = contentSize.aspectRatio
        let contentOrigin: CGPoint = {
            if containerAspectRatio > contentAspectRatio {
                return CGPoint(x: (containerSize.width - contentSize.width) / 2, y: 0.0)
            } else if containerAspectRatio < contentAspectRatio {
                return CGPoint(x: 0.0, y: (containerSize.height - contentSize.height) / 2)
            }
            return .zero
        }()
        return CGRect(origin: contentOrigin + coordinate.offset,
                      size: contentSize * coordinate.scale)
    }
}

// MARK: - Transform

extension PixelCanvas {
    
    struct Transform {
        let containerResolution: CGSize
        let contentResolution: CGSize
        let offset: CGPoint
        let scale: CGFloat
    }
    
    static func transform(
        contentResolution: CGSize,
        containerSize: CGSize,
        coordinate: CCanvasCoordinate
    ) -> Transform {
        let containerResolution: CGSize = containerSize * .pixelsPerPoint
        var offset = coordinate.offset
        offset /= coordinate.scale
        let relativeSize: CGSize = contentResolution.place(in: containerSize, placement: .fit)
        var inspectOffset: CGPoint = ((offset + relativeSize / 2) * coordinate.scale - relativeSize / 2)
        inspectOffset /= relativeSize / containerSize
        inspectOffset /= coordinate.scale
        inspectOffset *= .pixelsPerPoint
        return Transform(
            containerResolution: containerResolution,
            contentResolution: contentResolution,
            offset: inspectOffset,
            scale: coordinate.scale
        )
    }
}

// MARK: - Load

extension PixelCanvas {
 
    #if os(macOS)
    public func load(image: NSImage) {
        load(image: Image(nsImage: image),
             resolution: image.size * image.scale)
    }
    #else
    public func load(image: UIImage) {
        load(image: Image(uiImage: image),
             resolution: image.size * image.scale)
    }
    #endif

    public func load(image: Image, resolution: CGSize) {
        self.content = Content(image: image, resolution: resolution)
        reFrame()
    }
    
    public func unload() {
        self.content = nil
    }
}

// MARK: - Zoom

extension PixelCanvas {
    
    private func zoom(
        to coordinate: CCanvasCoordinate,
        animated: Bool = true
    ) {
        let zoom = Zoom(
            coordinate: coordinate,
            animated: animated
        )
        canvasZoom.send(zoom)
    }
    
    public func zoomToLocation(
        offset: CGPoint,
        scale: CGFloat,
        animated: Bool = true
    ) {
        let coordinate = CCanvasCoordinate(
            offset: offset,
            scale: scale,
            angle: .zero
        )
        zoom(
            to: coordinate,
            animated: animated
        )
    }
    
    /// Zoom to Fill
    /// - Parameters:
    ///   - padding: Padding in view points.
    public func zoomToFill(
        padding: CGSize = .zero,
        animated: Bool = true
    ) {
        guard let content: Content else { return }
        zoom(
            to: coordinate(
                contentResolution: content.resolution,
                padding: padding
            ),
            animated: animated
        )
    }
    
    /// Zoom to Frame
    /// - Parameters:
    ///   - contentFrame: A frame in pixels, top left is zero.
    ///   - padding: Padding in view points.
    public func zoomToFrame(
        contentFrame: CGRect,
        padding: CGSize = .zero,
        animated: Bool = true
    ) {
        guard let content: Content else { return }
        zoom(
            to: coordinate(
                contentResolution: content.resolution,
                contentFrame: contentFrame,
                padding: padding
            ),
            animated: animated
        )
    }
}
