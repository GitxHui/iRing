import AIStageCore
import AppKit
import CoreGraphics
import Metal
import MetalKit
import QuartzCore
import simd

/// Hosts a runtime-compiled 120Hz Metal shader overlay to animate either real `ScreenCaptureKit`
/// window snapshots or an instant zero-permission Liquid Glass window card from any Dock / radial icon
/// to the target window rect.
@MainActor
public final class MetalWindowTransitionController {
    private var panel: NSPanel?
    private var mtkView: TransitionMetalView?
    private static var fallbackImageCache: [String: CGImage] = [:]

    public init() {}

    public func playTransition(
        style: WindowPopAnimationStyle,
        image: CGImage?,
        appName: String,
        icon: NSImage,
        fromIconRectAppKit: CGRect,
        toWindowRectAppKit: CGRect,
        duration: Double,
        completion: @escaping () -> Void
    ) {
        guard style != .off, duration > 0.02 else {
            completion()
            return
        }

        let targetCenter = CGPoint(x: toWindowRectAppKit.midX, y: toWindowRectAppKit.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(targetCenter) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(toWindowRectAppKit) })
            ?? NSScreen.main

        guard let screen else {
            completion()
            return
        }
        let overlayFrame = screen.frame

        let view = ensureView(overlayFrame: overlayFrame, scale: screen.backingScaleFactor)
        guard let view else {
            completion()
            return
        }

        let resolvedImage: CGImage?
        if let image {
            resolvedImage = image
        } else {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            resolvedImage = Self.makeFallbackWindowImage(
                appName: appName,
                icon: icon,
                targetSize: toWindowRectAppKit.size,
                isDark: isDark
            )
        }

        guard let resolvedImage else {
            completion()
            return
        }

        let clampedFrom = clampRect(fromIconRectAppKit, within: overlayFrame)
        let clampedTo = clampRect(toWindowRectAppKit, within: overlayFrame)

        panel?.setFrame(overlayFrame, display: false)
        panel?.orderFrontRegardless()

        let started = view.startAnimation(
            style: style,
            image: resolvedImage,
            overlayFrameAppKit: overlayFrame,
            fromRectAppKit: clampedFrom,
            toRectAppKit: clampedTo,
            duration: duration
        ) { [weak self] in
            completion()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
                self?.panel?.orderOut(nil)
            }
        }

        if !started {
            panel?.orderOut(nil)
            completion()
        }
    }

    /// Generates and caches a crisp macOS Liquid Glass window card when Screen Recording snapshots are unavailable.
    public static func makeFallbackWindowImage(
        appName: String,
        icon: NSImage,
        targetSize: CGSize,
        isDark: Bool
    ) -> CGImage? {
        let aspect = max(0.65, min(2.2, targetSize.width / max(240, targetSize.height)))
        let key = "\(appName)-\(isDark)-\(Int(aspect * 10))"
        if let cached = fallbackImageCache[key] {
            return cached
        }

        let cardW: CGFloat = min(980, max(640, round(620 * aspect)))
        let cardH: CGFloat = round(cardW / aspect)
        let pixelScale: CGFloat = 2.0
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(cardW * pixelScale),
            pixelsHigh: Int(cardH * pixelScale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep, let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext
        cg.scaleBy(x: pixelScale, y: pixelScale)

        let bounds = CGRect(x: 0, y: 0, width: cardW, height: cardH)
        let accent = dominantAccent(from: icon)

        // Base window glass backdrop
        let baseTop = isDark
            ? NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.18, alpha: 0.94)
            : NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 0.95)
        let baseBot = isDark
            ? NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 0.96)
            : NSColor(calibratedRed: 0.89, green: 0.91, blue: 0.95, alpha: 0.96)
        if let grad = NSGradient(colors: [baseTop, baseBot]) {
            grad.draw(in: bounds, angle: -90)
        }

        // Ambient icon-tinted radial glow behind center emblem
        let glowCenter = CGPoint(x: cardW * 0.5, y: cardH * 0.5)
        if let radial = NSGradient(colors: [
            accent.withAlphaComponent(isDark ? 0.34 : 0.24),
            accent.withAlphaComponent(0.0)
        ]) {
            radial.draw(fromCenter: glowCenter, radius: 18, toCenter: glowCenter, radius: min(cardW, cardH) * 0.48, options: [])
        }

        // Translucent macOS titlebar separator & traffic lights
        let titleBarH: CGFloat = 36
        let titleBarRect = CGRect(x: 0, y: cardH - titleBarH, width: cardW, height: titleBarH)
        (isDark ? NSColor.white.withAlphaComponent(0.04) : NSColor.black.withAlphaComponent(0.03)).setFill()
        NSBezierPath(rect: titleBarRect).fill()

        let dotColors: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.37, blue: 0.34, alpha: 0.92),
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.18, alpha: 0.92),
            NSColor(calibratedRed: 0.16, green: 0.80, blue: 0.35, alpha: 0.92)
        ]
        for (idx, dotColor) in dotColors.enumerated() {
            dotColor.setFill()
            let dotRect = CGRect(x: 18 + CGFloat(idx) * 20, y: cardH - 24, width: 12, height: 12)
            NSBezierPath(ovalIn: dotRect).fill()
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.68) : NSColor.black.withAlphaComponent(0.58)
        ]
        let titleStr = NSAttributedString(string: appName, attributes: titleAttrs)
        let titleSize = titleStr.size()
        titleStr.draw(at: CGPoint(x: (cardW - titleSize.width) * 0.5, y: cardH - 26))

        // Large high-res centered app icon
        let iconSide: CGFloat = min(144, min(cardW, cardH) * 0.28)
        let iconRect = CGRect(
            x: (cardW - iconSide) * 0.5,
            y: (cardH - iconSide) * 0.5 + 8,
            width: iconSide,
            height: iconSide
        )
        icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        // App title caption beneath icon
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.92) : NSColor.black.withAlphaComponent(0.84)
        ]
        let nameStr = NSAttributedString(string: appName, attributes: nameAttrs)
        let nameSize = nameStr.size()
        nameStr.draw(at: CGPoint(x: (cardW - nameSize.width) * 0.5, y: iconRect.minY - nameSize.height - 14))

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else { return nil }
        if fallbackImageCache.count > 24 {
            fallbackImageCache.removeAll()
        }
        fallbackImageCache[key] = cgImage
        return cgImage
    }

    private static func dominantAccent(from image: NSImage) -> NSColor {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return .systemBlue }
        let sampleX = max(0, rep.pixelsWide / 2)
        let sampleY = max(0, rep.pixelsHigh / 2)
        return rep.colorAt(x: sampleX, y: sampleY)?.usingColorSpace(.sRGB) ?? .systemBlue
    }

    private func clampRect(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        let minX = max(bounds.minX, min(bounds.maxX - 8, rect.minX))
        let minY = max(bounds.minY, min(bounds.maxY - 8, rect.minY))
        let maxX = min(bounds.maxX, max(minX + 8, rect.maxX))
        let maxY = min(bounds.maxY, max(minY + 8, rect.maxY))
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func ensureView(overlayFrame: CGRect, scale: CGFloat) -> TransitionMetalView? {
        let pixelScale = max(1.0, scale)
        if let mtkView {
            mtkView.frame = CGRect(origin: .zero, size: overlayFrame.size)
            mtkView.layer?.contentsScale = pixelScale
            mtkView.drawableSize = CGSize(
                width: overlayFrame.width * pixelScale,
                height: overlayFrame.height * pixelScale
            )
            return mtkView
        }

        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        let view = TransitionMetalView(frame: CGRect(origin: .zero, size: overlayFrame.size), device: device)
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.contentsScale = pixelScale
        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.pixelFormat = .bgra8Unorm
        }
        view.drawableSize = CGSize(
            width: overlayFrame.width * pixelScale,
            height: overlayFrame.height * pixelScale
        )

        let newPanel = NSPanel(
            contentRect: overlayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.ignoresMouseEvents = true
        newPanel.level = .screenSaver
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = view

        self.panel = newPanel
        self.mtkView = view
        return view
    }
}

private struct TransitionUniforms {
    var fromRectNorm: SIMD4<Float> // minX, minY, maxX, maxY in [0..1] overlay AppKit space
    var toRectNorm: SIMD4<Float>   // minX, minY, maxX, maxY in [0..1] overlay AppKit space
    var windowMeta: SIMD4<Float>   // widthPt, heightPt, cornerRadiusPt, alpha
    var progress: Float
    var style: Int32               // 1=genie, 2=scale, 3=flash
    var pullAxis: Int32            // 0=top, 1=bottom, 2=left, 3=right
    var padding: Int32 = 0
}

private final class TransitionMetalView: MTKView, MTKViewDelegate {
    private let gridDivisions = 36
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var samplerState: MTLSamplerState?
    private var meshBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount: Int = 0
    private var textureLoader: MTKTextureLoader?

    private var currentTexture: MTLTexture?
    private var currentUniforms = TransitionUniforms(
        fromRectNorm: .zero,
        toRectNorm: .zero,
        windowMeta: .zero,
        progress: 0,
        style: 1,
        pullAxis: 0
    )
    private var animStartTime: TimeInterval = 0
    private var animDuration: Double = 0.42
    private var completionHandler: (() -> Void)?
    private var isAnimating: Bool = false

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms {
        float4 fromRectNorm;
        float4 toRectNorm;
        float4 windowMeta;
        float progress;
        int style;
        int pullAxis;
        int padding;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
        float alpha;
        float sheen;
        float rimGlow;
    };

    vertex VertexOut transitionVertex(
        uint vid [[vertex_id]],
        constant float2 *gridUV [[buffer(0)]],
        constant Uniforms &u [[buffer(1)]]
    ) {
        float2 uv = gridUV[vid];
        float t = clamp(u.progress, 0.0, 1.0);

        float fMinX = u.fromRectNorm.x;
        float fMinY = u.fromRectNorm.y;
        float fMaxX = u.fromRectNorm.z;
        float fMaxY = u.fromRectNorm.w;

        float tMinX = u.toRectNorm.x;
        float tMinY = u.toRectNorm.y;
        float tMaxX = u.toRectNorm.z;
        float tMaxY = u.toRectNorm.w;

        float xNorm = 0.0;
        float yNorm = 0.0;
        float alpha = 1.0;
        float sheen = 0.0;
        float rimGlow = sin(t * 3.14159265) * 0.55;

        if (u.style == 1) {
            // Vivid 4-directional macOS Genie hourglass funnel
            float distFromIcon = 1.0;
            if (u.pullAxis == 0) {
                distFromIcon = uv.y;         // from top (notch/island)
            } else if (u.pullAxis == 1) {
                distFromIcon = 1.0 - uv.y;   // from bottom dock
            } else if (u.pullAxis == 2) {
                distFromIcon = uv.x;         // from left edge
            } else {
                distFromIcon = 1.0 - uv.x;   // from right edge
            }

            float funnelPhase = clamp(t * 1.58 + (distFromIcon - 1.0) * 0.58, 0.0, 1.0);
            float funnelSmooth = funnelPhase * funnelPhase * (3.0 - 2.0 * funnelPhase);
            // Pinch neck sharply in early frames for dramatic genie spout silhouette
            float pinchEnvelope = mix(funnelSmooth * funnelSmooth, funnelSmooth, smoothstep(0.30, 0.88, t));

            float leadT = 1.0 - pow(1.0 - clamp(t / 0.78, 0.0, 1.0), 2.8);
            float trailT = smoothstep(0.18, 1.0, t);

            if (u.pullAxis == 0 || u.pullAxis == 1) {
                float topT = (u.pullAxis == 0) ? trailT : leadT;
                float botT = (u.pullAxis == 0) ? leadT : trailT;
                float curTopY = mix(fMaxY, tMaxY, topT);
                float curBotY = mix(fMinY, tMinY, botT);
                yNorm = mix(curTopY, curBotY, uv.y);

                float leftX = mix(fMinX, tMinX, pinchEnvelope);
                float rightX = mix(fMaxX, tMaxX, pinchEnvelope);
                xNorm = mix(leftX, rightX, uv.x);
            } else {
                float leftT = (u.pullAxis == 2) ? trailT : leadT;
                float rightT = (u.pullAxis == 2) ? leadT : trailT;
                float curLeftX = mix(fMinX, tMinX, leftT);
                float curRightX = mix(fMaxX, tMaxX, rightT);
                xNorm = mix(curLeftX, curRightX, uv.x);

                float botY = mix(fMinY, tMinY, pinchEnvelope);
                float topY = mix(fMaxY, tMaxY, pinchEnvelope);
                yNorm = mix(topY, botY, uv.y);
            }
            alpha = smoothstep(0.0, 0.14, t);
            sheen = sin(clamp((t * 1.4 - (uv.x + uv.y) * 0.35), 0.0, 1.0) * 3.14159265) * 0.06;
        } else if (u.style == 2) {
            // Expressive Elastic Scale with visible bounce overshoot
            float spring = 1.0 - exp(-6.4 * t) * cos(10.5 * t);
            float settle = smoothstep(0.84, 1.0, t);
            float s = mix(spring, 1.0, settle);

            float minX = mix(fMinX, tMinX, s);
            float maxX = mix(fMaxX, tMaxX, s);
            float minY = mix(fMinY, tMinY, s);
            float maxY = mix(fMaxY, tMaxY, s);
            xNorm = mix(minX, maxX, uv.x);
            yNorm = mix(maxY, minY, uv.y);
            alpha = smoothstep(0.0, 0.16, t);
        } else {
            // Luminous Flash materialize with sweeping highlight band
            float ease = 1.0 - pow(1.0 - t, 3.6);
            float2 fCenter = float2((fMinX + fMaxX) * 0.5, (fMinY + fMaxY) * 0.5);
            float2 tCenter = float2((tMinX + tMaxX) * 0.5, (tMinY + tMaxY) * 0.5);
            float2 curCenter = mix(fCenter, tCenter, ease);
            float2 tSize = float2(tMaxX - tMinX, tMaxY - tMinY);
            float2 fSize = float2(fMaxX - fMinX, fMaxY - fMinY);
            float2 curSize = mix(max(fSize, tSize * 0.42), tSize, ease);

            xNorm = curCenter.x + (uv.x - 0.5) * curSize.x;
            yNorm = curCenter.y + (0.5 - uv.y) * curSize.y;
            alpha = smoothstep(0.0, 0.22, t);
            float band = max(0.0, 1.0 - abs((uv.x + uv.y) * 0.5 - t * 1.35) * 4.5);
            sheen = band * 0.14 * (1.0 - t);
        }

        VertexOut out;
        out.position = float4(xNorm * 2.0 - 1.0, yNorm * 2.0 - 1.0, 0.0, 1.0);
        out.uv = uv;
        out.alpha = alpha;
        out.sheen = sheen;
        out.rimGlow = rimGlow;
        return out;
    }

    fragment float4 transitionFragment(
        VertexOut in [[stage_in]],
        texture2d<float> windowTex [[texture(0)]],
        sampler texSampler [[sampler(0)]],
        constant Uniforms &u [[buffer(1)]]
    ) {
        float2 sizePt = max(u.windowMeta.xy, float2(40.0, 40.0));
        float2 p = (in.uv - 0.5) * sizePt;
        float2 halfSize = sizePt * 0.5;
        float radius = clamp(u.windowMeta.z, 2.0, min(halfSize.x, halfSize.y) - 1.0);
        float2 q = abs(p) - (halfSize - float2(radius));
        float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
        float cornerMask = 1.0 - smoothstep(-1.0, 1.0, dist);
        float borderBand = (1.0 - smoothstep(0.0, 2.2, abs(dist + 1.0))) * in.rimGlow;

        float4 color = windowTex.sample(texSampler, in.uv);
        color.rgb += in.sheen + borderBand * float3(0.45, 0.72, 1.0);
        float finalAlpha = saturate(color.a * cornerMask * in.alpha * u.windowMeta.w);
        return float4(color.rgb * finalAlpha, finalAlpha);
    }
    """

    override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
        super.init(frame: frameRect, device: device)
        configureMetal(device: device)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureMetal(device: (any MTLDevice)?) {
        guard let device else { return }
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        colorPixelFormat = .bgra8Unorm
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = false
        preferredFramesPerSecond = 120
        framebufferOnly = false
        wantsLayer = true
        layer?.isOpaque = false
        delegate = self

        commandQueue = device.makeCommandQueue()
        textureLoader = MTKTextureLoader(device: device)

        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "transitionVertex")
            desc.fragmentFunction = library.makeFunction(name: "transitionFragment")
            desc.colorAttachments[0].pixelFormat = colorPixelFormat
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].sourceRGBBlendFactor = .one
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .one
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            NSLog("[AIStage] Metal shader compile failed: \(error.localizedDescription)")
        }

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDesc)

        buildGridBuffers(device: device)
    }

    private func buildGridBuffers(device: any MTLDevice) {
        let cols = gridDivisions + 1
        var vertices: [SIMD2<Float>] = []
        vertices.reserveCapacity(cols * cols)
        for row in 0...gridDivisions {
            let v = Float(row) / Float(gridDivisions)
            for col in 0...gridDivisions {
                let u = Float(col) / Float(gridDivisions)
                vertices.append(SIMD2<Float>(u, v))
            }
        }

        var indices: [UInt16] = []
        indices.reserveCapacity(gridDivisions * gridDivisions * 6)
        for row in 0..<gridDivisions {
            for col in 0..<gridDivisions {
                let tl = UInt16(row * cols + col)
                let tr = tl + 1
                let bl = tl + UInt16(cols)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }
        indexCount = indices.count
        meshBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD2<Float>>.stride * vertices.count,
            options: .storageModeShared
        )
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        )
    }

    func startAnimation(
        style: WindowPopAnimationStyle,
        image: CGImage,
        overlayFrameAppKit: CGRect,
        fromRectAppKit: CGRect,
        toRectAppKit: CGRect,
        duration: Double,
        completion: @escaping () -> Void
    ) -> Bool {
        guard pipelineState != nil,
              let textureLoader,
              overlayFrameAppKit.width > 10,
              overlayFrameAppKit.height > 10
        else { return false }

        do {
            currentTexture = try textureLoader.newTexture(
                cgImage: image,
                options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue]
            )
        } catch {
            return false
        }

        let w = Float(overlayFrameAppKit.width)
        let h = Float(overlayFrameAppKit.height)
        let fromNorm = SIMD4<Float>(
            Float(fromRectAppKit.minX - overlayFrameAppKit.minX) / w,
            Float(fromRectAppKit.minY - overlayFrameAppKit.minY) / h,
            Float(fromRectAppKit.maxX - overlayFrameAppKit.minX) / w,
            Float(fromRectAppKit.maxY - overlayFrameAppKit.minY) / h
        )
        let toNorm = SIMD4<Float>(
            Float(toRectAppKit.minX - overlayFrameAppKit.minX) / w,
            Float(toRectAppKit.minY - overlayFrameAppKit.minY) / h,
            Float(toRectAppKit.maxX - overlayFrameAppKit.minX) / w,
            Float(toRectAppKit.maxY - overlayFrameAppKit.minY) / h
        )

        let styleCode: Int32
        switch style {
        case .off: return false
        case .genie: styleCode = 1
        }

        // Determine dominant pull direction relative to window center (4-way Genie)
        let dx = fromRectAppKit.midX - toRectAppKit.midX
        let dy = fromRectAppKit.midY - toRectAppKit.midY
        let pullAxis: Int32
        if abs(dx) > abs(dy) * 1.15 {
            pullAxis = dx < 0 ? 2 : 3 // 2=left, 3=right
        } else {
            pullAxis = dy >= 0 ? 0 : 1 // 0=top, 1=bottom
        }

        currentUniforms = TransitionUniforms(
            fromRectNorm: fromNorm,
            toRectNorm: toNorm,
            windowMeta: SIMD4<Float>(Float(toRectAppKit.width), Float(toRectAppKit.height), 12.0, 1.0),
            progress: 0.0,
            style: styleCode,
            pullAxis: pullAxis
        )

        if let prior = completionHandler {
            completionHandler = nil
            prior()
        }

        completionHandler = completion
        animStartTime = ProcessInfo.processInfo.systemUptime
        animDuration = max(0.05, duration)
        isAnimating = true
        isPaused = false
        draw()
        return true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard isAnimating else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - animStartTime
        let progress = min(1.0, max(0.0, elapsed / animDuration))
        currentUniforms.progress = Float(progress)

        guard let pipelineState,
              let commandQueue,
              let currentTexture,
              let samplerState,
              let meshBuffer,
              let indexBuffer,
              let descriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            finishIfNeeded(progress: progress)
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setCullMode(.none)
        encoder.setVertexBuffer(meshBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&currentUniforms, length: MemoryLayout<TransitionUniforms>.stride, index: 1)
        encoder.setFragmentTexture(currentTexture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setFragmentBytes(&currentUniforms, length: MemoryLayout<TransitionUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        finishIfNeeded(progress: progress)
    }

    private func finishIfNeeded(progress: Double) {
        guard progress >= 1.0, isAnimating else { return }
        isAnimating = false
        isPaused = true
        let cb = completionHandler
        completionHandler = nil
        cb?()
    }
}
