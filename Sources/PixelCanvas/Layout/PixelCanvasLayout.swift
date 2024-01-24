import SwiftUI
import CoreGraphicsExtensions

public struct PixelCanvasLayout: Layout {
    
    private let frame: CGRect
    
    public init(frame: CGRect) {
        self.frame = frame
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(
            width: proposal.width ?? 0.0,
            height: proposal.height ?? 0.0
        )
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(
                at: bounds.origin + frame.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: frame.width,
                    height: frame.height
                )
            )
        }
    }
}
