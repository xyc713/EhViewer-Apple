//
//  ZoomableImageView.swift
//  ehviewer apple
//
//  可缩放图片视图 — 对齐 Android GalleryView 的缩放/平移逻辑
//  使用 UIScrollView (iOS) / NSScrollView (macOS) 实现原生级缩放体验
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - iOS 实现

#if os(iOS)
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let scaleMode: ScaleMode
    let startPosition: StartPosition
    /// 是否允许在 1x 缩放时拦截水平滑动 (翻页模式需要 false 以允许 TabView 翻页)
    var allowsHorizontalScrollAtMinZoom: Bool = false
    /// 单击回调 (用于切换 overlay)
    var onSingleTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap)
    }

    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView(frame: .zero)
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.scaleMode = scaleMode
        scrollView.startPosition = startPosition

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleToFill  // 手动设置 frame，不依赖 contentMode
        imageView.clipsToBounds = false
        imageView.tag = 1001
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        context.coordinator.allowsHorizontalScrollAtMinZoom = allowsHorizontalScrollAtMinZoom

        // 双击缩放手势 (对齐 Android GalleryView 双击缩放)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        // 单击手势 — 仅在有回调时启用 (翻页模式由 tapZones 处理，避免边缘误触)
        if onSingleTap != nil {
            let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
            singleTap.numberOfTapsRequired = 1
            singleTap.require(toFail: doubleTap)
            scrollView.addGestureRecognizer(singleTap)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(1001) as? UIImageView else { return }

        let imageChanged = imageView.image !== image
        let scaleModeChanged = scrollView.scaleMode != scaleMode
        let startPositionChanged = scrollView.startPosition != startPosition

        if imageChanged {
            imageView.image = image
            scrollView.zoomScale = scrollView.minimumZoomScale
            scrollView.needsStartPositionApply = true
        }

        if scaleModeChanged {
            scrollView.scaleMode = scaleMode
            scrollView.needsStartPositionApply = true
        }

        if startPositionChanged {
            scrollView.startPosition = startPosition
            scrollView.needsStartPositionApply = true
        }

        if imageChanged || scaleModeChanged || startPositionChanged {
            scrollView.lastLayoutBoundsSize = .zero
        }

        context.coordinator.allowsHorizontalScrollAtMinZoom = allowsHorizontalScrollAtMinZoom
        context.coordinator.onSingleTap = onSingleTap
        scrollView.setNeedsLayout()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: ZoomableScrollView?
        var onSingleTap: (() -> Void)?
        var allowsHorizontalScrollAtMinZoom: Bool = false

        init(onSingleTap: (() -> Void)?) {
            self.onSingleTap = onSingleTap
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // 始终钳制水平偏移，防止任何横向漂移/黑边 (对齐 Android GalleryView: 不允许水平越界)
            let contentW = scrollView.contentSize.width
            let boundsW = scrollView.bounds.width
            guard contentW > 0 && boundsW > 0 else { return }

            var targetX = scrollView.contentOffset.x
            if contentW <= boundsW + 1 {
                // 内容宽度 ≤ 视口: 锁定到居中位置，完全禁止水平移动
                targetX = max(0, (contentW - boundsW) / 2)
            } else {
                // 内容宽度 > 视口 (放大时): 钳制到有效范围 [0, maxOffset]，防止过度滚动
                let maxX = contentW - boundsW
                targetX = min(max(0, targetX), maxX)
            }
            if abs(scrollView.contentOffset.x - targetX) > 0.1 {
                scrollView.contentOffset.x = targetX
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            // 居中图片 (对齐 Android GalleryView.layout)
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter

            // 缩放过程中也钳制水平偏移，防止缩放时横向漂移
            if let zoomScrollView = scrollView as? ZoomableScrollView {
                zoomScrollView.clampHorizontalOffset()

                // 在 1x 缩放时: 根据内容是否溢出决定是否启用滚动
                let isZoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
                let contentOverflows = scrollView.contentSize.width > boundsSize.width + 1 ||
                                        scrollView.contentSize.height > boundsSize.height + 1
                zoomScrollView.isScrollEnabled = isZoomed || contentOverflows || allowsHorizontalScrollAtMinZoom
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if scale <= scrollView.minimumZoomScale + 0.01 {
                if let zoomScrollView = scrollView as? ZoomableScrollView {
                    let contentOverflows = scrollView.contentSize.width > scrollView.bounds.width + 1 ||
                                            scrollView.contentSize.height > scrollView.bounds.height + 1
                    zoomScrollView.isScrollEnabled = contentOverflows || allowsHorizontalScrollAtMinZoom
                }
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                // 已放大 → 缩小回 1x (对齐 Android GalleryView: 双击回 fitScale)
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // 在点击位置放大到 2.5x (对齐 Android GalleryView 双击缩放目标)
                let pointInView = gesture.location(in: imageView)
                let targetScale: CGFloat = 2.5
                let zoomWidth = scrollView.bounds.width / targetScale
                let zoomHeight = scrollView.bounds.height / targetScale
                let zoomRect = CGRect(
                    x: pointInView.x - zoomWidth / 2,
                    y: pointInView.y - zoomHeight / 2,
                    width: zoomWidth,
                    height: zoomHeight
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            onSingleTap?()
        }

    }
}

/// 自定义 UIScrollView — 实现完整的 ScaleMode 布局逻辑 (对齐 Android ImageView.setScaleOffset)
/// 在 fit/fitWidth 模式的 1x 缩放时不拦截水平手势，让父 TabView 正常翻页
class ZoomableScrollView: UIScrollView {
    /// 用于检测 bounds 是否变化，避免冗余布局
    var lastLayoutBoundsSize: CGSize = .zero
    /// 缩放模式 (对齐 Android ImageView.SCALE_*)
    var scaleMode: ScaleMode = .fit
    /// 起始位置 (对齐 Android ImageView.START_POSITION_*)
    var startPosition: StartPosition = .center
    /// 是否需要在下次布局时应用起始位置
    var needsStartPositionApply = true

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        // 每次布局都钳制水平偏移，阻止 UIScrollView bounce 导致的横向黑边
        clampHorizontalOffset()

        // 仅在 1x (未缩放) 且 bounds 发生变化时重新计算
        guard zoomScale <= minimumZoomScale + 0.01 else {
            centerImageView()
            return
        }
        guard bounds.size != lastLayoutBoundsSize else { return }
        lastLayoutBoundsSize = bounds.size

        guard let imageView = viewWithTag(1001) as? UIImageView,
              let image = imageView.image else { return }
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }

        let wScale = bounds.width / imgSize.width
        let hScale = bounds.height / imgSize.height

        // 对齐 Android ImageView.setScaleOffset: 根据 scaleMode 计算缩放比例
        var fitScale: CGFloat
        switch scaleMode {
        case .origin:
            fitScale = 1.0
        case .fitWidth:
            fitScale = wScale
        case .fitHeight:
            fitScale = hScale
        case .fit:
            fitScale = min(wScale, hScale)
        case .fixed:
            fitScale = 1.0
        }

        let scaledW = imgSize.width * fitScale
        let scaledH = imgSize.height * fitScale

        // 设置 imageView 尺寸
        imageView.frame = CGRect(x: 0, y: 0, width: scaledW, height: scaledH)
        contentSize = CGSize(width: scaledW, height: scaledH)

        // 居中或边缘对齐 (对齐 Android ImageView.adjustPosition)
        centerImageView()

        // 应用起始位置 (对齐 Android ImageView startPosition)
        if needsStartPositionApply {
            applyStartPosition(scaledW: scaledW, scaledH: scaledH)
            needsStartPositionApply = false
        }
    }

    /// 居中图片: 小于屏幕时居中，大于屏幕时对齐边缘 (对齐 Android ImageView.adjustPosition)
    private func centerImageView() {
        guard let imageView = viewWithTag(1001) as? UIImageView else { return }
        var f = imageView.frame
        f.origin.x = f.width < bounds.width ? (bounds.width - f.width) / 2 : 0
        f.origin.y = f.height < bounds.height ? (bounds.height - f.height) / 2 : 0
        imageView.frame = f
    }

    /// 钳制水平偏移到有效范围，防止横向漂移/黑边 (对齐 Android: 图片不允许水平越界)
    func clampHorizontalOffset() {
        let contentW = contentSize.width
        let boundsW = bounds.width
        guard contentW > 0 && boundsW > 0 else { return }

        var targetX = contentOffset.x
        if contentW <= boundsW + 1 {
            // 内容宽度 ≤ 视口: 锁定居中
            targetX = max(0, (contentW - boundsW) / 2)
        } else {
            // 放大时: 钳制到 [0, maxOffset]
            let maxX = contentW - boundsW
            targetX = min(max(0, targetX), maxX)
        }
        if abs(contentOffset.x - targetX) > 0.1 {
            contentOffset.x = targetX
        }
    }

    /// 设置初始滚动偏移 (对齐 Android ImageView startPosition 逻辑)
    private func applyStartPosition(scaledW: CGFloat, scaledH: CGFloat) {
        let maxOffsetX = max(0, scaledW - bounds.width)
        let maxOffsetY = max(0, scaledH - bounds.height)

        var offset: CGPoint
        switch startPosition {
        case .topLeft:
            offset = CGPoint(x: 0, y: 0)
        case .topRight:
            offset = CGPoint(x: maxOffsetX, y: 0)
        case .bottomLeft:
            offset = CGPoint(x: 0, y: maxOffsetY)
        case .bottomRight:
            offset = CGPoint(x: maxOffsetX, y: maxOffsetY)
        case .center:
            offset = CGPoint(x: maxOffsetX / 2, y: maxOffsetY / 2)
        }
        contentOffset = offset
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
           zoomScale <= minimumZoomScale + 0.01 {
            let velocity = panGesture.velocity(in: self)

            // 允许从屏幕左边缘开始的右滑手势 (返回导航)
            if let window = self.window {
                let locationInWindow = panGesture.location(in: window)
                if locationInWindow.x < 30 && velocity.x > 0 && abs(velocity.x) > abs(velocity.y) {
                    return false
                }
            }

            // 只在 fit/fitWidth 模式下拦截水平手势 (这些模式下图片宽度 ≤ 屏幕宽度，无需水平滚动)
            // fitHeight/origin 模式可能需要水平滚动，不拦截
            if abs(velocity.x) > abs(velocity.y) && (scaleMode == .fit || scaleMode == .fitWidth) {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

#else

// MARK: - macOS 实现

struct ZoomableImageView: NSViewRepresentable {
    let image: NSImage
    let scaleMode: ScaleMode
    let startPosition: StartPosition
    var allowsHorizontalScrollAtMinZoom: Bool = false
    var onSingleTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 5.0
        scrollView.backgroundColor = .black

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleNone  // 手动控制尺寸，不依赖 AppKit 自动缩放
        scrollView.documentView = imageView
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        context.coordinator.scaleMode = scaleMode

        // 单击手势
        let singleTap = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfClicksRequired = 1
        scrollView.addGestureRecognizer(singleTap)

        // 双击手势
        let doubleTap = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfClicksRequired = 2
        singleTap.delaysPrimaryMouseButtonEvents = true
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let imageView = scrollView.documentView as? NSImageView else { return }
        let needsLayout = imageView.image !== image || context.coordinator.scaleMode != scaleMode
        if imageView.image !== image {
            imageView.image = image
            scrollView.magnification = 1.0
        }
        context.coordinator.scaleMode = scaleMode
        context.coordinator.onSingleTap = onSingleTap
        if needsLayout {
            layoutImage(in: scrollView, imageView: imageView)
        }
    }

    /// 对齐 Android ImageView.setScaleOffset 的缩放布局
    private func layoutImage(in scrollView: NSScrollView, imageView: NSImageView) {
        guard let image = imageView.image else { return }
        let imgSize = image.size
        let viewSize = scrollView.bounds.size
        guard imgSize.width > 0, imgSize.height > 0, viewSize.width > 0, viewSize.height > 0 else { return }

        let wScale = viewSize.width / imgSize.width
        let hScale = viewSize.height / imgSize.height

        var fitScale: CGFloat
        switch scaleMode {
        case .origin:    fitScale = 1.0
        case .fitWidth:  fitScale = wScale
        case .fitHeight: fitScale = hScale
        case .fit:       fitScale = min(wScale, hScale)
        case .fixed:     fitScale = 1.0
        }

        let scaledW = imgSize.width * fitScale
        let scaledH = imgSize.height * fitScale

        // 居中 (对齐 Android adjustPosition: 小于视口时居中)
        let x = max(0, (viewSize.width - scaledW) / 2)
        let y = max(0, (viewSize.height - scaledH) / 2)
        imageView.frame = CGRect(x: x, y: y, width: scaledW, height: scaledH)
    }

    class Coordinator: NSObject {
        weak var imageView: NSImageView?
        weak var scrollView: NSScrollView?
        var onSingleTap: (() -> Void)?
        var scaleMode: ScaleMode = .fit

        init(onSingleTap: (() -> Void)?) {
            self.onSingleTap = onSingleTap
        }

        @objc func handleDoubleTap(_ gesture: NSClickGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.magnification > 1.1 {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    scrollView.animator().magnification = 1.0
                }
            } else {
                let point = gesture.location(in: scrollView.documentView)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    scrollView.animator().setMagnification(2.5, centeredAt: point)
                }
            }
        }

        @objc func handleSingleTap(_ gesture: NSClickGestureRecognizer) {
            onSingleTap?()
        }
    }
}

#endif
