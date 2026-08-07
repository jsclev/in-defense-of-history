import Foundation
import Metal
import MetalKit
import QuartzCore
import CoreGraphics

@available(iOS 26.0, *)
final class Renderer: NSObject, MTKViewDelegate {

    // MARK: - Metal objects

    private let device: any MTLDevice
    private let commandQueue: any MTL4CommandQueue
    private let commandBuffer: any MTL4CommandBuffer

    private let pipelineState: any MTLRenderPipelineState
    private let imageTexture: any MTLTexture

    private let fragmentArgumentTable: any MTL4ArgumentTable
    private let vertexArgumentTable: any MTL4ArgumentTable
    private let cropUniformBuffers: [any MTLBuffer]
    private let resourceResidencySet: any MTLResidencySet

    // MARK: - Frame synchronization

    private static let maximumFramesInFlight = 3

    private let commandAllocators: [any MTL4CommandAllocator]
    private let completionEvent: any MTLSharedEvent

    /// For each allocator, the event value that must complete before reuse.
    private var allocatorCompletionValues = Array(
        repeating: UInt64(0),
        count: maximumFramesInFlight
    )

    private var currentFrameSlot = 0
    private var nextCompletionValue: UInt64 = 0

    // MARK: - Initialization

    init(
        view: MTKView,
        imageName: String
    ) throws {
        guard let device = view.device else {
            throw RendererError.noMetalDevice
        }

        guard device.supportsFamily(.metal4) else {
            throw RendererError.metal4Unsupported
        }

        guard let commandQueue = device.makeMTL4CommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }

        guard let commandBuffer = device.makeCommandBuffer() else {
            throw RendererError.commandBufferCreationFailed
        }

        guard let completionEvent = device.makeSharedEvent() else {
            throw RendererError.sharedEventCreationFailed
        }

        // Create multiple allocators so the CPU can encode another frame
        // while a previous allocator is still being used by the GPU.
        var allocators: [any MTL4CommandAllocator] = []
        allocators.reserveCapacity(Self.maximumFramesInFlight)

        for _ in 0..<Self.maximumFramesInFlight {
            guard let allocator = device.makeCommandAllocator() else {
                throw RendererError.commandAllocatorCreationFailed
            }

            allocators.append(allocator)
        }

        // Load the image directly from an entry in Assets.xcassets (an
        // image set or texture set) rather than a loose bundle file.
        let textureLoader = MTKTextureLoader(device: device)

        let imageTexture: any MTLTexture
        do {
            imageTexture = try textureLoader.newTexture(
                name: imageName,
                scaleFactor: view.contentScaleFactor,
                bundle: nil,
                options: [
                    .SRGB: true,
                    .origin: MTKTextureLoader.Origin.topLeft,
                    .generateMipmaps: false,
                    .textureUsage: NSNumber(
                        value: MTLTextureUsage.shaderRead.rawValue
                    )
                ]
            )
        } catch {
            throw RendererError.imageNotFound(imageName)
        }

        imageTexture.label = "Campaign map texture"

        // Create the render pipeline.
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.defaultLibraryCreationFailed
        }

        guard let vertexFunction = library.makeFunction(
            name: "imageVertexShader"
        ) else {
            throw RendererError.shaderNotFound("imageVertexShader")
        }

        guard let fragmentFunction = library.makeFunction(
            name: "imageFragmentShader"
        ) else {
            throw RendererError.shaderNotFound("imageFragmentShader")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Image render pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction

        // This must match the MTKView's pixel format.
        pipelineDescriptor.colorAttachments[0].pixelFormat =
            view.colorPixelFormat

        let pipelineState = try device.makeRenderPipelineState(
            descriptor: pipelineDescriptor
        )

        // Metal 4 uses explicit argument tables for resource binding.
        let argumentDescriptor = MTL4ArgumentTableDescriptor()
        argumentDescriptor.label = "Image fragment arguments"
        argumentDescriptor.maxTextureBindCount = 1

        let fragmentArgumentTable = try device.makeArgumentTable(
            descriptor: argumentDescriptor
        )

        fragmentArgumentTable.setTexture(
            imageTexture.gpuResourceID,
            index: Int(TextureIndex.color.rawValue)
        )

        // One small uniform buffer per frame slot, so the CPU can write
        // next frame's crop rect while the GPU may still be reading a
        // previous frame's buffer.
        var cropBuffers: [any MTLBuffer] = []
        cropBuffers.reserveCapacity(Self.maximumFramesInFlight)

        for index in 0..<Self.maximumFramesInFlight {
            guard let buffer = device.makeBuffer(
                length: MemoryLayout<ImageCropUniforms>.stride,
                options: .storageModeShared
            ) else {
                throw RendererError.cropUniformBufferCreationFailed
            }

            buffer.label = "Image crop uniforms \(index)"
            cropBuffers.append(buffer)
        }

        // Argument tables allocate binding slots 0..<maxBufferBindCount,
        // so this must cover BufferIndexImageCrop's slot even though it's
        // the table's only binding.
        let vertexArgumentDescriptor = MTL4ArgumentTableDescriptor()
        vertexArgumentDescriptor.label = "Image vertex arguments"
        vertexArgumentDescriptor.maxBufferBindCount =
            Int(BufferIndex.imageCrop.rawValue) + 1

        let vertexArgumentTable = try device.makeArgumentTable(
            descriptor: vertexArgumentDescriptor
        )

        // Create a residency set for the static resources used by rendering.
        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "Image renderer resources"
        residencyDescriptor.initialCapacity = 2 + Self.maximumFramesInFlight

        let resourceResidencySet = try device.makeResidencySet(
            descriptor: residencyDescriptor
        )

        resourceResidencySet.addAllocation(imageTexture)
        resourceResidencySet.addAllocation(pipelineState)

        for buffer in cropBuffers {
            resourceResidencySet.addAllocation(buffer)
        }

        resourceResidencySet.commit()
        resourceResidencySet.requestResidency()

        self.device = device
        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocators = allocators
        self.completionEvent = completionEvent
        self.pipelineState = pipelineState
        self.imageTexture = imageTexture
        self.fragmentArgumentTable = fragmentArgumentTable
        self.vertexArgumentTable = vertexArgumentTable
        self.cropUniformBuffers = cropBuffers
        self.resourceResidencySet = resourceResidencySet

        super.init()

        // Make static resources visible to work submitted to this queue.
        commandQueue.addResidencySet(resourceResidencySet)

        // CAMetalLayer maintains a dynamic residency set containing its
        // drawable textures. Metal 4 requires that set on the queue.
        guard let metalLayer = view.layer as? CAMetalLayer else {
            throw RendererError.invalidMetalLayer
        }

        commandQueue.addResidencySet(metalLayer.residencySet)
    }

    // MARK: - MTKViewDelegate

    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize
    ) {
        // Important when the view is configured for on-demand drawing.
        if view.isPaused {
            view.setNeedsDisplay()
        }
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor =
                view.currentMTL4RenderPassDescriptor
        else {
            return
        }

        let frameSlot = currentFrameSlot
        let allocator = commandAllocators[frameSlot]
        let requiredCompletionValue =
            allocatorCompletionValues[frameSlot]

        // An allocator can't be reset until the GPU has finished executing
        // all commands previously encoded with it.
        if requiredCompletionValue != 0 {
            let completed = completionEvent.wait(
                untilSignaledValue: requiredCompletionValue,
                timeoutMS: 1_000
            )

            guard completed else {
                assertionFailure(
                    "Timed out waiting for a Metal command allocator."
                )
                return
            }
        }

        allocator.reset()

        commandBuffer.beginCommandBuffer(
            allocator: allocator
        )

        guard let encoder =
            commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor
            )
        else {
            commandBuffer.endCommandBuffer()
            return
        }

        // Recompute which sub-rect of the source image to sample, in case
        // the drawable size changed (rotation, Split View / Stage Manager
        // resize, external display, ...), then upload it to this frame
        // slot's uniform buffer.
        let cropResult = makeCropUVRect(drawableSize: view.drawableSize)

        var cropUniforms = ImageCropUniforms(
            sourceUVRect: cropResult.uvRect,
            rotateToLandscape: cropResult.rotateToLandscape ? 1 : 0
        )

        memcpy(
            cropUniformBuffers[frameSlot].contents(),
            &cropUniforms,
            MemoryLayout<ImageCropUniforms>.size
        )

        vertexArgumentTable.setAddress(
            cropUniformBuffers[frameSlot].gpuAddress,
            index: Int(BufferIndex.imageCrop.rawValue)
        )

        encoder.label = "Image render encoder"
        encoder.setRenderPipelineState(pipelineState)

        encoder.setArgumentTable(
            vertexArgumentTable,
            stages: .vertex
        )

        encoder.setArgumentTable(
            fragmentArgumentTable,
            stages: .fragment
        )

        // The image always fills the entire drawable; the crop rect
        // uploaded above controls which part of the source image is
        // visible, not the viewport.
        encoder.setViewport(
            MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(view.drawableSize.width),
                height: Double(view.drawableSize.height),
                znear: 0,
                zfar: 1
            )
        )

        encoder.drawPrimitives(
            primitiveType: .triangle,
            vertexStart: 0,
            vertexCount: 6
        )

        encoder.endEncoding()
        commandBuffer.endCommandBuffer()

        // Metal 4 requires explicit synchronization with the drawable.
        commandQueue.waitForDrawable(drawable)
        commandQueue.commit([commandBuffer])

        nextCompletionValue &+= 1

        commandQueue.signalEvent(
            completionEvent,
            value: nextCompletionValue
        )

        allocatorCompletionValues[frameSlot] =
            nextCompletionValue

        commandQueue.signalDrawable(drawable)
        drawable.present()

        currentFrameSlot =
            (currentFrameSlot + 1)
            % Self.maximumFramesInFlight
    }

    // MARK: - Crop calculation

    /// The sub-rect of the source image to sample (in normalized 0...1
    /// texture coordinates), plus whether the vertex shader needs to
    /// rotate it 90° to keep that content in a landscape orientation.
    private struct CropResult {
        var uvRect: SIMD4<Float>
        var rotateToLandscape: Bool
    }

    /// Computes the sub-rect of the source image, and rotation, that
    /// should fill the given drawable size. See `CampaignMapLayout` for
    /// the shared math (also used by the SwiftUI HUD to position nodes).
    private func makeCropUVRect(drawableSize: CGSize) -> CropResult {
        let imageSize = CGSize(
            width: imageTexture.width,
            height: imageTexture.height
        )

        let crop = CampaignMapLayout.makeCrop(
            imageSize: imageSize,
            safeRect: CampaignMapAsset.safeRect,
            viewSize: drawableSize
        )

        let uvRect = SIMD4<Float>(
            Float(crop.rect.minX / imageSize.width),
            Float(crop.rect.minY / imageSize.height),
            Float(crop.rect.maxX / imageSize.width),
            Float(crop.rect.maxY / imageSize.height)
        )

        return CropResult(
            uvRect: uvRect,
            rotateToLandscape: crop.rotated
        )
    }
}

// MARK: - Errors

@available(iOS 26.0, *)
private enum RendererError: LocalizedError {
    case noMetalDevice
    case metal4Unsupported
    case commandQueueCreationFailed
    case commandBufferCreationFailed
    case commandAllocatorCreationFailed
    case cropUniformBufferCreationFailed
    case sharedEventCreationFailed
    case defaultLibraryCreationFailed
    case shaderNotFound(String)
    case imageNotFound(String)
    case invalidMetalLayer

    var errorDescription: String? {
        switch self {
        case .noMetalDevice:
            return "The MTKView has no Metal device."

        case .metal4Unsupported:
            return "This GPU does not support Metal 4."

        case .commandQueueCreationFailed:
            return "Could not create an MTL4CommandQueue."

        case .commandBufferCreationFailed:
            return "Could not create an MTL4CommandBuffer."

        case .commandAllocatorCreationFailed:
            return "Could not create an MTL4CommandAllocator."

        case .cropUniformBufferCreationFailed:
            return "Could not create an image-crop uniform buffer."

        case .sharedEventCreationFailed:
            return "Could not create an MTLSharedEvent."

        case .defaultLibraryCreationFailed:
            return "Could not load the default Metal shader library."

        case .shaderNotFound(let name):
            return "The Metal shader '\(name)' was not found."

        case .imageNotFound(let name):
            return "The image '\(name)' was not found in the asset catalog."

        case .invalidMetalLayer:
            return "The MTKView does not have a CAMetalLayer."
        }
    }
}
