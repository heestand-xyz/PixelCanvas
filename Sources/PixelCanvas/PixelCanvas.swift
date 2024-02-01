import Foundation
import Observation
import SwiftUI
import Combine
import Canvas
import CoreGraphicsExtensions

public final class PixelCanvas: ObservableObject {
    
    public enum Placement: Int {
        case stretch
        case fit
        case fill
        case fixed
    }
    
    public struct Options {
        public var animationDuration: TimeInterval = 1.0 / 3.0
        public var checkerTransparency: Bool = true
        public var checkerOpacity: CGFloat = 0.5
        public var checkerSize: CGFloat = 64
        public var borderWidth: CGFloat = 1.0
        public var borderFadeRange: ClosedRange<CGFloat> = 25...50
        public var borderOpacity: CGFloat = 0.25
        public var placement: Placement = .fit
    }
    public var options = Options()
    
    struct Content {
        let id: UUID
        let image: Image
        let resolution: CGSize
    }
    @Published var content: Content?

    @Published public internal(set) var canvasContainerSize: CGSize = .one
    @Published public internal(set) var canvasCoordinate: CCanvasCoordinate = .zero
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
    @Published var canvasContentFrame: CGRect = .one
    public var frame: CGRect {
        get {
            canvasContentFrame
        }
        set {
            reFrame()
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
 
    public func coordinate(contentResolution: CGSize, contentFrame: CGRect? = nil, edgeInsets: EdgeInsets? = nil) -> CCanvasCoordinate {
        Self.coordinate(
            contentResolution: contentResolution,
            contentFrame: contentFrame ?? CGRect(origin: .zero, size: contentResolution),
            containerSize: canvasContainerSize,
            edgeInsets: edgeInsets
        )
    }
    
    private static func coordinate(
        contentResolution: CGSize,
        contentFrame: CGRect,
        containerSize: CGSize,
        edgeInsets: EdgeInsets? = nil
    ) -> CCanvasCoordinate {
        
        let paddingOrigin = CGPoint(x: edgeInsets?.leading ?? 0.0,
                                        y: edgeInsets?.top ?? 0.0)
        let paddingFar = CGPoint(x: edgeInsets?.trailing ?? 0.0,
                                            y: edgeInsets?.bottom ?? 0.0)
        let paddingSize: CGSize = (paddingOrigin + paddingFar).asSize
        
        let containerPaddingSize: CGSize = containerSize - paddingSize
        let containerPaddingScale: CGSize = containerPaddingSize / containerSize
        
        let containerPaddingCenter: CGPoint = paddingOrigin + containerPaddingSize / 2
        
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
        let contentPaddingSize: CGSize = contentResolution.place(in: containerPaddingSize, placement: .fit, roundToPixels: false)
        let containerPaddingAspectRatio: CGFloat = containerPaddingSize.aspectRatio

        let resolutionScale = contentPaddingSize.height / contentResolution.height
        
        let contentCropAspectRatio: CGFloat = contentFrame.size.aspectRatio
        let contentCropFrame = CGRect(
            origin: contentFrame.origin * resolutionScale,
            size: contentFrame.size * resolutionScale
        )
        
        let scale: CGFloat = if containerPaddingAspectRatio > contentCropAspectRatio {
            (containerPaddingSize.height / contentCropFrame.height) * containerPaddingScale.height
        } else {
            (containerPaddingSize.width / contentCropFrame.width) * containerPaddingScale.width
        }
        let homeScale: CGFloat = if containerPaddingAspectRatio > contentCropAspectRatio {
            (containerPaddingSize.height / contentPaddingSize.height) * containerPaddingScale.height
        } else {
            (containerPaddingSize.width / contentPaddingSize.width) * containerPaddingScale.width
        }
        let relativityScale: CGFloat = scale / homeScale
                
        var offset: CGPoint = .zero
        let relativeContentPaddingSize: CGSize = contentPaddingSize.place(in: contentSize, placement: .fit, roundToPixels: false)
        offset += ((relativeContentPaddingSize - contentPaddingSize * relativityScale) / 2)
        offset += containerPaddingCenter.asSize - containerSize / 2

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
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
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
        let relativeSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
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
    @MainActor
    public func load(image: NSImage) {
        load(image: Image(nsImage: image),
             resolution: image.size * image.scale)
    }
    #else
    @MainActor
    public func load(image: UIImage) {
        load(image: Image(uiImage: image),
             resolution: image.size * image.scale)
    }
    #endif

    @MainActor
    public func load(image: Image, resolution: CGSize) {
        self.content = Content(id: UUID(), image: image, resolution: resolution)
        self.reFrame()
    }
    
    public func unload() {
        self.content = nil
    }
}

// MARK: - Zoom

extension PixelCanvas {
    
    @MainActor
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
    
    @MainActor
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
    @MainActor
    public func zoomToFill(
        edgeInsets: EdgeInsets? = nil,
        animated: Bool = true
    ) {
        guard let content: Content else { return }
        zoom(
            to: coordinate(
                contentResolution: content.resolution,
                edgeInsets: edgeInsets
            ),
            animated: animated
        )
    }
    
    /// Zoom to Frame
    /// - Parameters:
    ///   - contentFrame: A frame in pixels, top left is zero.
    ///   - padding: Padding in view points.
    @MainActor
    public func zoomToFrame(
        contentFrame: CGRect,
        edgeInsets: EdgeInsets? = nil,
        animated: Bool = true
    ) {
        guard let content: Content else { return }
        zoom(
            to: coordinate(
                contentResolution: content.resolution,
                contentFrame: contentFrame,
                edgeInsets: edgeInsets
            ),
            animated: animated
        )
    }
}
