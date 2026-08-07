import SwiftUI
import Metal
import MetalKit

// Fills its drawable by repeating a seamless texture at native pixel
// density. The texture loads once; rotation only changes a uvScale uniform,
// so orientation flips redraw instantly.
@available(iOS 26.0, *)
final class TiledBackgroundRenderer: NSObject, MTKViewDelegate {
    private static let maximumFramesInFlight = 3

    private let commandQueue: any MTL4CommandQueue
    private let commandBuffer: any MTL4CommandBuffer
    private let pipelineState: any MTLRenderPipelineState
    private let tileTexture: any MTLTexture
    private let fragmentArgumentTable: any MTL4ArgumentTable
    private let vertexArgumentTable: any MTL4ArgumentTable
    private let tileUniformBuffers: [any MTLBuffer]
    private let resourceResidencySet: any MTLResidencySet
    private let commandAllocators: [any MTL4CommandAllocator]
    private let completionEvent: any MTLSharedEvent

    private var allocatorCompletionValues = Array(
        repeating: UInt64(0), count: maximumFramesInFlight)
    private var currentFrameSlot = 0
    private var nextCompletionValue: UInt64 = 0

    init(view: MTKView, imageName: String) throws {
        guard let device = view.device else {
            throw TiledBackgroundError.setupFailed("no Metal device")
        }
        guard let commandQueue = device.makeMTL4CommandQueue(),
              let commandBuffer = device.makeCommandBuffer(),
              let completionEvent = device.makeSharedEvent() else {
            throw TiledBackgroundError.setupFailed("queue/buffer/event")
        }

        var allocators: [any MTL4CommandAllocator] = []
        for _ in 0..<Self.maximumFramesInFlight {
            guard let allocator = device.makeCommandAllocator() else {
                throw TiledBackgroundError.setupFailed("command allocator")
            }
            allocators.append(allocator)
        }

        let textureLoader = MTKTextureLoader(device: device)
        let tileTexture: any MTLTexture
        do {
            tileTexture = try textureLoader.newTexture(
                name: imageName,
                scaleFactor: view.contentScaleFactor,
                bundle: nil,
                options: [
                    .SRGB: true,
                    .origin: MTKTextureLoader.Origin.topLeft,
                    .generateMipmaps: false,
                    .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
                ]
            )
        } catch {
            throw TiledBackgroundError.setupFailed("texture '\(imageName)'")
        }
        tileTexture.label = "Tiled background texture"

        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "tileVertexShader"),
              let fragmentFunction = library.makeFunction(name: "tileFragmentShader") else {
            throw TiledBackgroundError.setupFailed("tile shaders")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Tiled background pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let fragmentDescriptor = MTL4ArgumentTableDescriptor()
        fragmentDescriptor.label = "Tile fragment arguments"
        fragmentDescriptor.maxTextureBindCount = 1
        let fragmentArgumentTable = try device.makeArgumentTable(descriptor: fragmentDescriptor)
        fragmentArgumentTable.setTexture(
            tileTexture.gpuResourceID,
            index: Int(TextureIndex.color.rawValue)
        )

        var uniformBuffers: [any MTLBuffer] = []
        for index in 0..<Self.maximumFramesInFlight {
            guard let buffer = device.makeBuffer(
                length: MemoryLayout<TileUniforms>.stride,
                options: .storageModeShared
            ) else {
                throw TiledBackgroundError.setupFailed("uniform buffer")
            }
            buffer.label = "Tile uniforms \(index)"
            uniformBuffers.append(buffer)
        }

        let vertexDescriptor = MTL4ArgumentTableDescriptor()
        vertexDescriptor.label = "Tile vertex arguments"
        vertexDescriptor.maxBufferBindCount = Int(BufferIndex.imageCrop.rawValue) + 1
        let vertexArgumentTable = try device.makeArgumentTable(descriptor: vertexDescriptor)

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "Tiled background resources"
        residencyDescriptor.initialCapacity = 2 + Self.maximumFramesInFlight
        let resourceResidencySet = try device.makeResidencySet(descriptor: residencyDescriptor)
        resourceResidencySet.addAllocation(tileTexture)
        resourceResidencySet.addAllocation(pipelineState)
        for buffer in uniformBuffers {
            resourceResidencySet.addAllocation(buffer)
        }
        resourceResidencySet.commit()
        resourceResidencySet.requestResidency()

        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.pipelineState = pipelineState
        self.tileTexture = tileTexture
        self.fragmentArgumentTable = fragmentArgumentTable
        self.vertexArgumentTable = vertexArgumentTable
        self.tileUniformBuffers = uniformBuffers
        self.resourceResidencySet = resourceResidencySet
        self.commandAllocators = allocators
        self.completionEvent = completionEvent
        super.init()

        commandQueue.addResidencySet(resourceResidencySet)
        guard let metalLayer = view.layer as? CAMetalLayer else {
            throw TiledBackgroundError.setupFailed("no CAMetalLayer")
        }
        commandQueue.addResidencySet(metalLayer.residencySet)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if view.isPaused {
            view.setNeedsDisplay()
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentMTL4RenderPassDescriptor else { return }

        let frameSlot = currentFrameSlot
        let allocator = commandAllocators[frameSlot]
        let requiredCompletionValue = allocatorCompletionValues[frameSlot]
        if requiredCompletionValue != 0 {
            guard completionEvent.wait(
                untilSignaledValue: requiredCompletionValue, timeoutMS: 1_000
            ) else { return }
        }
        allocator.reset()

        commandBuffer.beginCommandBuffer(allocator: allocator)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            commandBuffer.endCommandBuffer()
            return
        }

        var uniforms = TileUniforms(uvScale: SIMD2<Float>(
            Float(view.drawableSize.width) / Float(tileTexture.width),
            Float(view.drawableSize.height) / Float(tileTexture.height)
        ))
        memcpy(tileUniformBuffers[frameSlot].contents(), &uniforms,
               MemoryLayout<TileUniforms>.size)
        vertexArgumentTable.setAddress(
            tileUniformBuffers[frameSlot].gpuAddress,
            index: Int(BufferIndex.imageCrop.rawValue)
        )

        encoder.label = "Tiled background encoder"
        encoder.setRenderPipelineState(pipelineState)
        encoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
        encoder.setArgumentTable(fragmentArgumentTable, stages: .fragment)
        encoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(view.drawableSize.width),
            height: Double(view.drawableSize.height),
            znear: 0, zfar: 1
        ))
        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.endCommandBuffer()

        commandQueue.waitForDrawable(drawable)
        commandQueue.commit([commandBuffer])
        nextCompletionValue &+= 1
        commandQueue.signalEvent(completionEvent, value: nextCompletionValue)
        allocatorCompletionValues[frameSlot] = nextCompletionValue
        commandQueue.signalDrawable(drawable)
        drawable.present()
        currentFrameSlot = (currentFrameSlot + 1) % Self.maximumFramesInFlight
    }
}

@available(iOS 26.0, *)
private enum TiledBackgroundError: LocalizedError {
    case setupFailed(String)

    var errorDescription: String? {
        if case .setupFailed(let what) = self {
            return "Tiled background setup failed: \(what)."
        }
        return nil
    }
}

@available(iOS 26.0, *)
struct TiledBackgroundMetalView: UIViewRepresentable {
    let imageName: String

    final class Coordinator {
        var renderer: TiledBackgroundRenderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is unavailable on this device.")
        }
        let metalView = MTKView(frame: .zero, device: device)
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .invalid
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true

        do {
            let renderer = try TiledBackgroundRenderer(view: metalView, imageName: imageName)
            metalView.delegate = renderer
            context.coordinator.renderer = renderer
        } catch {
            fatalError("Tiled background renderer failed: " + error.localizedDescription)
        }

        metalView.setNeedsDisplay()
        return metalView
    }

    func updateUIView(_ metalView: MTKView, context: Context) {}
}
