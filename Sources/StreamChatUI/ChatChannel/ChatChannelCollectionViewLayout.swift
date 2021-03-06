//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation
import UIKit

/// This layout flips items such that item at indexPath 0-0 appears at the bottom of collectionView,
/// while last item appears first.
///
/// Such approach comes with self-sizing cell issue: when you scroll to "estimated" cell bottom anchor, cell size calculated
/// and you may jump right into middle of cell, because `collectionViewContentSize` have been changed,
/// while `contentOffset` stay same.
/// To fight it we lock `collectionViewContentSize`, now newly calculated cell "expands" up into invisible yet area, removing jumps.
open class ChatChannelCollectionViewLayout: UICollectionViewFlowLayout {
    // MARK: - Init & Deinit
    
    override public required init() {
        super.init()
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        minimumInteritemSpacing = 0
        minimumLineSpacing = 4
    }

    var bottomContentOffsetBeforeInvalidation: CGFloat?
    /// Use this flag to signal that all cells layout have been calculated and it's safe to remove "infinite scroll" hack.
    /// e.g. set to `true` when showing top most cell, set to `false` when new cell appears
    var layoutCached: Bool = false {
        willSet {
            guard newValue != layoutCached else { return }
            let offsetY = collectionView?.contentOffset.y ?? 0
            bottomContentOffsetBeforeInvalidation = collectionViewContentSize.height - offsetY
        }
        didSet {
            guard oldValue != layoutCached else { return }
            let context = UICollectionViewFlowLayoutInvalidationContext()
            context.invalidateFlowLayoutAttributes = true
            invalidateLayout(with: context)
        }
    }

    open var zeroOffset: CGPoint {
        CGPoint(
            x: 0,
            y: collectionViewContentSize.height - realContentSize.height
        )
    }

    open var realContentSize: CGSize {
        super.collectionViewContentSize
    }
    
    // MARK: - Overrides

    override open var collectionViewContentSize: CGSize {
        let size = super.collectionViewContentSize
        if layoutCached {
            return size
        }
        return CGSize(width: size.width, height: 100_000)
    }
    
    override open func prepare() {
        super.prepare()
        
        estimatedItemSize = .init(
            width: collectionView?.bounds.width ?? 0,
            height: 60
        )

        if let offset = bottomContentOffsetBeforeInvalidation {
            collectionView?.contentOffset = CGPoint(
                x: 0,
                y: collectionViewContentSize.height - offset
            )
            bottomContentOffsetBeforeInvalidation = nil
        }
    }

    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let contentSize = collectionViewContentSize
        let portalRect = CGRect(
            x: rect.origin.x,
            y: contentSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        return super.layoutAttributesForElements(in: portalRect)?
            .map(flip(_:))
    }

    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        super.layoutAttributesForItem(at: indexPath).map(flip(_:))
    }

    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        if layoutCached {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
        }
        // Content offset may be zero only when view just loaded for first time and needs to be scrolled to bottom
        if proposedContentOffset == .zero {
            let insets = collectionView?.contentInset ?? .zero
            return CGPoint(
                x: 0,
                y: collectionViewContentSize.height - (collectionView?.bounds.height ?? 0) + insets.top + insets.bottom
            )
        }
        if proposedContentOffset.y < zeroOffset.y {
            return zeroOffset
        }
        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }

    override open func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        if layoutCached {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        if proposedContentOffset.y < zeroOffset.y {
            return zeroOffset
        }
        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
    }

    // MARK: - Dark Magic

    private func flip(_ attribute: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let contentSize = collectionViewContentSize
        attribute.frame = CGRect(
            x: attribute.frame.origin.x,
            y: contentSize.height - attribute.frame.origin.y - attribute.frame.height,
            width: attribute.frame.width,
            height: attribute.frame.height
        )
        return attribute
    }
}
