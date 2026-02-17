import Foundation
import Observation
import SwiftUI
import Combine
import GestureCanvas
import CoreGraphicsExtensions
import TextureMap

@MainActor
public protocol PixelCanvasDelegate: AnyObject {
    
    func pixelCanvasDidTap(at location: CGPoint, with coordinate: GestureCanvasCoordinate)
    
#if !os(macOS)
    func pixelCanvasAllowPinch(_ canvas: PixelCanvas) -> Bool
#endif
}

@MainActor
@Observable
public final class PixelCanvas {
    
    public weak var delegate: PixelCanvasDelegate?
    
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
        /// Won't use shader.
        public var alwaysUseImageCanvas: Bool = false
        /// Experimental.
        ///
        /// 3x3 interpolation when zoomed out.
        public var interpolate: Bool = false
    }
    public var options = Options()
    
    struct Content {
        let id: UUID
        let image: Image
        let resolution: CGSize
    }
    var content: Content? {
        didSet {      
            zoomCoordinateOffsetUpdate.send(zoomCoordinateOffset())
        }
    }
    
    internal let zoomCoordinateOffsetUpdate = PassthroughSubject<CGPoint, Never>()
    
    /// Moving (Panning or Zooming)
    public var isMoving: Bool {
        isPanning || isZooming
    }
    
    /// Panning
    public private(set) var isPanning: Bool = false {
        didSet { isPanningContinuation?.yield(isPanning) }
    }
    @ObservationIgnored
    public private(set) lazy var isPanningStream = AsyncStream<Bool> { [weak self] continuation in
        self?.isPanningContinuation = continuation
    }
    @ObservationIgnored
    private var isPanningContinuation: AsyncStream<Bool>.Continuation?
    
    /// Zooming
    public private(set) var isZooming: Bool = false {
        didSet { isZoomingContinuation?.yield(isZooming) }
    }
    @ObservationIgnored
    public private(set) lazy var isZoomingStream = AsyncStream<Bool> { [weak self] continuation in
        self?.isZoomingContinuation = continuation
    }
    @ObservationIgnored
    private var isZoomingContinuation: AsyncStream<Bool>.Continuation?
    
    /// Container Size
    public internal(set) var containerSize: CGSize = .one {
        didSet {
            containerSizeContinuation?.yield(containerSize)
            zoomCoordinateOffsetUpdate.send(zoomCoordinateOffset())
        }
    }
    @ObservationIgnored
    public private(set) lazy var containerSizeStream = AsyncStream<CGSize> { [weak self] continuation in
        self?.containerSizeContinuation = continuation
    }
    @ObservationIgnored
    private var containerSizeContinuation: AsyncStream<CGSize>.Continuation?
    
    /// Coordinate
    public internal(set) var coordinate: GestureCanvasCoordinate = .zero {
        didSet {
            coordinateContinuation?.yield(coordinate)
        }
    }
    @ObservationIgnored
    public private(set) lazy var coordinateStream = AsyncStream<GestureCanvasCoordinate> { [weak self] continuation in
        self?.coordinateContinuation = continuation
    }
    @ObservationIgnored
    private var coordinateContinuation: AsyncStream<GestureCanvasCoordinate>.Continuation?
    
    /// Scale
    public var scale: CGFloat {
        get {
            coordinate.scale
        }
        set {
            coordinate.scale = newValue
            reFrame()
        }
    }
    /// Offset
    public var offset: CGPoint {
        get {
            coordinate.offset
        }
        set {
            coordinate.offset = newValue
            reFrame()
        }
    }
    
    /// Content Frame
    public internal(set) var contentFrame: CGRect = .one {
        didSet {
            contentFrameContinuation?.yield(contentFrame)
        }
    }
    @ObservationIgnored
    public private(set) lazy var contentFrameStream = AsyncStream<CGRect> { [weak self] continuation in
        self?.contentFrameContinuation = continuation
    }
    @ObservationIgnored
    private var contentFrameContinuation: AsyncStream<CGRect>.Continuation?
    
    /// Frame
    public var frame: CGRect {
        get {
            contentFrame
        }
        set {
            reFrame()
        }
    }

    struct Zoom {
        let coordinate: GestureCanvasCoordinate
        let animated: Bool
    }
    let canvasZoom = PassthroughSubject<Zoom, Never>()
    
    public init() {}
}

// MARK: - Coordinates

extension PixelCanvas {
 
    public func coordinate(contentResolution: CGSize, contentFrame: CGRect? = nil, edgeInsets: EdgeInsets? = nil) -> GestureCanvasCoordinate {
        Self.coordinate(
            contentResolution: contentResolution,
            contentFrame: contentFrame ?? CGRect(origin: .zero, size: contentResolution),
            containerSize: containerSize,
            edgeInsets: edgeInsets
        )
    }
    
    private static func coordinate(
        contentResolution: CGSize,
        contentFrame: CGRect,
        containerSize: CGSize,
        edgeInsets: EdgeInsets? = nil
    ) -> GestureCanvasCoordinate {
        
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
        let containerAspectRatio: CGFloat = containerSize.aspectRatio

        let resolutionScale = contentSize.height / contentResolution.height
        var contentCropFrame = CGRect(
            origin: contentFrame.origin * resolutionScale,
            size: contentFrame.size * resolutionScale
        )
        let contentCropAspectRatio: CGFloat = contentCropFrame.size.aspectRatio
        let cropScale: CGFloat = if contentCropAspectRatio > containerAspectRatio {
            contentCropFrame.width / contentSize.width
        } else {
            contentCropFrame.height / contentSize.height
        }
        let topLeadingPadding = CGPoint(x: edgeInsets?.leading ?? 0.0,
                                        y: edgeInsets?.top ?? 0.0)
        let bottomTrailingPadding = CGPoint(x: edgeInsets?.trailing ?? 0.0,
                                            y: edgeInsets?.bottom ?? 0.0)
        let padding: CGSize = (topLeadingPadding + bottomTrailingPadding).asSize
        contentCropFrame = CGRect(origin: contentCropFrame.origin - topLeadingPadding * cropScale,
                                  size: contentCropFrame.size + padding * cropScale)
        let contentPaddingCropAspectRatio: CGFloat = contentCropFrame.size.aspectRatio

        let containerCropFillSize = CGSize(
            width: containerAspectRatio < contentPaddingCropAspectRatio ? contentCropFrame.width : contentCropFrame.height * containerAspectRatio,
            height: containerAspectRatio > contentPaddingCropAspectRatio ? contentCropFrame.height : contentCropFrame.width / containerAspectRatio
        )
        
        let contentOrigin: CGPoint = (containerSize - contentSize).asPoint / 2
        let centerOffset: CGPoint = (containerCropFillSize - contentCropFrame.size).asPoint / 2
        
        let scale: CGFloat = if containerAspectRatio > contentPaddingCropAspectRatio {
            containerSize.height / contentCropFrame.height
        } else {
            containerSize.width / contentCropFrame.width
        }
        let offset: CGPoint = -contentOrigin - contentCropFrame.origin * scale + centerOffset * scale
        
        return GestureCanvasCoordinate(
            offset: offset,
            scale: scale
        )
    }
    
    func zoomCoordinateOffset() -> CGPoint {
        guard let content: Content else { return .zero }
        return -Self.contentOrigin(contentResolution: content.resolution, containerSize: containerSize)
    }
}

// MARK: - Frame

extension PixelCanvas {
    
    func reFrame() {
        guard let content: Content else { return }
        contentFrame = Self.frame(
            contentResolution: content.resolution,
            containerSize: containerSize,
            coordinate: coordinate
        )
    }
    
    static func frame(
        contentResolution: CGSize,
        containerSize: CGSize,
        coordinate: GestureCanvasCoordinate
    ) -> CGRect {
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
        let contentOrigin: CGPoint = contentOrigin(contentResolution: contentResolution, containerSize: containerSize)
        return CGRect(origin: contentOrigin + coordinate.offset,
                      size: contentSize * coordinate.scale)
    }
    
    static func contentOrigin(
        contentResolution: CGSize,
        containerSize: CGSize
    ) -> CGPoint {
        let containerAspectRatio: CGFloat = containerSize.aspectRatio
        let contentSize: CGSize = contentResolution.place(in: containerSize, placement: .fit, roundToPixels: false)
        let contentAspectRatio: CGFloat = contentSize.aspectRatio
        if containerAspectRatio > contentAspectRatio {
            return CGPoint(x: (containerSize.width - contentSize.width) / 2, y: 0.0)
        } else if containerAspectRatio < contentAspectRatio {
            return CGPoint(x: 0.0, y: (containerSize.height - contentSize.height) / 2)
        }
        return .zero
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
        coordinate: GestureCanvasCoordinate
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
    
    @MainActor
    public func unload() {
        self.content = nil
    }
}

// MARK: - Zoom

extension PixelCanvas {
    
    @MainActor
    private func zoom(
        to coordinate: GestureCanvasCoordinate,
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
        let coordinate = GestureCanvasCoordinate(
            offset: offset,
            scale: scale
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

// MARK: Gesture Canvas Delegate

extension PixelCanvas: GestureCanvasDelegate {
    
    public func gestureCanvasChanged(_ canvas: GestureCanvas, coordinate: GestureCanvasDynamicCoordinate) {}
    
    public func gestureCanvasBackgroundTap(_ canvas: GestureCanvas, at location: CGPoint) {
        delegate?.pixelCanvasDidTap(at: location, with: coordinate)
    }
    public func gestureCanvasBackgroundDoubleTap(_ canvas: GestureCanvas, at location: CGPoint) {}
    
    public func gestureCanvasDragSelectionStarted(_ canvas: GestureCanvas, at location: CGPoint) {}
    public func gestureCanvasDragSelectionUpdated(_ canvas: GestureCanvas, at location: CGPoint) {}
    public func gestureCanvasDragSelectionEnded(_ canvas: GestureCanvas, at location: CGPoint) {}
    
#if os(macOS)
    public func gestureCanvasTrackpadLightMultiTap(_ canvas: GestureCanvas, tapCount: Int, at location: CGPoint) {}

    public func gestureCanvasScrollStarted(_ canvas: GestureCanvas) {}
    public func gestureCanvasScrollEnded(_ canvas: GestureCanvas) {}

    @MainActor
    public func gestureCanvasContextMenu(_ canvas: GestureCanvas, at location: CGPoint) -> NSMenu? { nil }
#else
    public func gestureCanvasContext(at location: CGPoint) -> Bool { false }
    public func gestureCanvasEditMenuInteractionDelegate() -> UIEditMenuInteractionDelegate? { nil }

    public func gestureCanvasAllowPinch(_ canvas: GestureCanvas) -> Bool {
        delegate?.pixelCanvasAllowPinch(self) ?? true
    }
#endif
    
    public func gestureCanvasDidStartPan(_ canvas: GestureCanvas, at location: CGPoint) {
        isPanning = true
    }
    
    public func gestureCanvasDidUpdatePan(_ canvas: GestureCanvas, at location: CGPoint) {}
    
    public func gestureCanvasDidEndPan(_ canvas: GestureCanvas, at location: CGPoint) {
        isPanning = false
    }
    
    public func gestureCanvasDidCancelPan(_ canvas: GestureCanvas) {
        isPanning = false
    }
    
    public func gestureCanvasDidStartZoom(_ canvas: GestureCanvas, at location: CGPoint) {
        isZooming = true
    }
    
    public func gestureCanvasDidUpdateZoom(_ canvas: GestureCanvas, at location: CGPoint) {}
    
    public func gestureCanvasWillEndZoom(_ canvas: GestureCanvas, at location: CGPoint) {}
    
    public func gestureCanvasDidEndZoom(_ canvas: GestureCanvas, at location: CGPoint) {
        isZooming = false
    }
    
    public func gestureCanvasDidCancelZoom(_ canvas: GestureCanvas) {
        isZooming = false
    }
}
