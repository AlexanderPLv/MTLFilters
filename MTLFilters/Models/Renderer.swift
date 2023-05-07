//
//  Renderer.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 04.05.2023.
//

import MetalKit

final class Renderer: NSObject {
    
    static let numberOfImages = 6
    static let maxFramesPerImage = 300
    static let vertexBufferIndexVertices = 0
    static let vertexBufferIndexScale = 1
    
    static let vertexData: [Vertex] =
    [
        Vertex(position: [1.0, -1.0], texCoord: [1.0, 1.0]),
        Vertex(position: [-1.0, -1.0], texCoord: [0.0, 1.0]),
        Vertex(position: [-1.0,   1.0], texCoord: [0.0, 0.0]),
        Vertex(position: [1.0,  -1.0], texCoord: [1.0, 1.0]),
        Vertex(position: [-1.0,   1.0], texCoord: [0.0, 0.0]),
        Vertex(position: [1.0,   1.0], texCoord: [1.0, 0.0])
    ]
    
    private var parent: MetalView
    
  //  private let view: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState!
    
    private var displayTexture: MTLTexture!
    private var imageTextures = [MTLTexture]()
    private var currentImageIndex = 0
    private var imageHeap: MTLHeap!
    private var scratchHeap: MTLHeap!
    private var vertexBuffer: MTLBuffer!
    
    private var displayScale: simd_float2 = [1, 1]
    private var quadScale: simd_float2 = [1, 1]
    
    private var event: EventWrapper
    
    private var blurFrames = 0
    private let gaussianBlurFilter: GaussianBlurFilter
    private let downsampleFilter: DownsampleFilter
    
    init(parent: MetalView, context: MetalContext) {
      //  self.view = view
        self.parent = parent
        self.device = context.device
        self.commandQueue = context.commandQueue
        self.event = SingleDeviceEventWrapper(device: device)
        self.gaussianBlurFilter = GaussianBlurFilter(device: device)
        self.downsampleFilter = DownsampleFilter(device: device)
        super.init()
        makeResources()
        makePipeline()
        
        loadImages()
        
        createImageHeap()
        
        moveImagesToHeap()
    }
    
    static func alignUp(inSize: Int, align: Int) -> Int {
        assert(((align-1) & align) == 0)
        let alignmentMask = align - 1
        return ((inSize + alignmentMask) & (~alignmentMask))
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSizeWillChange(view, size)
    }
    
    func draw(in view: MTKView) {
        drawIn(view)
    }
}

private extension Renderer {
    
    func makeResources() {
        vertexBuffer = device.makeBuffer(
            bytes: Renderer.vertexData,
            length: MemoryLayout<Vertex>.stride * Renderer.vertexData.count,
            options: .storageModeShared
        )
        vertexBuffer.label = "Vertices"
        
    }
    
    func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Unable to create default Metal library")
        }
        let vertexProgram = library.makeFunction(
            name: "texturedQuadVertex"
        )!
        let fragmentProgram = library.makeFunction(
            name: "texturedQuadFragment"
        )!
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "Drawable Pipeline"
     //   renderPipelineDescriptor.sampleCount view.sampleCount
        renderPipelineDescriptor.vertexFunction = vertexProgram
        renderPipelineDescriptor.fragmentFunction = fragmentProgram
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
//        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
//        renderPipelineDescriptor.stencilAttachmentPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Error while creating render pipeline state: \(error)")
        }
    }
    
    func createImageHeap() {
        let heapDescriptor = MTLHeapDescriptor()
        heapDescriptor.storageMode = .private
        heapDescriptor.size = 0
        
        (0..<Renderer.numberOfImages).forEach { index in
            let textureDescriptor = makeTextureDescriptor(
                from: imageTextures[index],
                storageMode: heapDescriptor.storageMode
            )
            var sizeAndAlign = device.heapTextureSizeAndAlign(descriptor: textureDescriptor)
            sizeAndAlign.size = Renderer.alignUp(inSize: sizeAndAlign.size, align: sizeAndAlign.align)
            heapDescriptor.size += sizeAndAlign.size
        }
        imageHeap = device.makeHeap(descriptor: heapDescriptor)
    }
    
    func makeTextureDescriptor(from texture: MTLTexture,
                               storageMode: MTLStorageMode
    ) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = texture.textureType
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.depth = texture.depth
        descriptor.mipmapLevelCount = texture.mipmapLevelCount
        descriptor.arrayLength = texture.arrayLength
        descriptor.sampleCount = texture.sampleCount
        descriptor.storageMode = storageMode
        return descriptor
    }
    
    func loadImages() {
        let textureLoader = MTKTextureLoader(device: device)
        (0..<Renderer.numberOfImages).forEach { index in
            let imageString = "Image\(index)"
            let imageUrl = Bundle.main.url(forResource: imageString, withExtension: "jpg")
            
            let supportsSRGBWrites = device.supportsFamily(.apple3)
            let options = [MTKTextureLoader.Option.SRGB: supportsSRGBWrites]
            do {
                if imageTextures.count <= index {
                    imageTextures.append(try textureLoader.newTexture(URL: imageUrl!, options: options))
                } else {
                    imageTextures[index] = try textureLoader.newTexture(URL: imageUrl!, options: options)
                }
            } catch let error {
                fatalError("Could not load texture with name: \(imageString). " + error.localizedDescription)
            }
        }
    }
    
    func moveImagesToHeap() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Error. Make command buffer error.")
        }
        commandBuffer.label = "Heap Upload Command Buffer"
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        
        (0..<Renderer.numberOfImages).forEach { imageIndex in
            let textureDescriptor = makeTextureDescriptor(from: imageTextures[imageIndex], storageMode: imageHeap.storageMode)
            guard let heapTexture = imageHeap.makeTexture(descriptor: textureDescriptor) else {
                fatalError("Could not make heap texture.")
            }
            var region = MTLRegionMake2D(0, 0, imageTextures[imageIndex].width, imageTextures[imageIndex].height)
            (0..<imageTextures[imageIndex].mipmapLevelCount).forEach { level in
                (0..<imageTextures[imageIndex].arrayLength).forEach { slice in
                    blitEncoder?.copy(
                        from: imageTextures[imageIndex],
                        sourceSlice: slice,
                        sourceLevel: level,
                        sourceOrigin: region.origin,
                        sourceSize: region.size,
                        to: heapTexture,
                        destinationSlice: slice,
                        destinationLevel: level,
                        destinationOrigin: region.origin
                    )
                }
                region.size.width /= 2
                region.size.height /= 2
                if region.size.width == 0 {
                    region.size.width = 1
                }
                if region.size.height == 0 {
                    region.size.height = 1
                }
            }
            imageTextures[imageIndex] = heapTexture
        }
        blitEncoder?.endEncoding()
        event.signal(commandBuffer)
        commandBuffer.commit()
    }
    
    func createScratchHeap(inTexture: MTLTexture) {
        let heapStorageMode: MTLStorageMode = .private
        let textureDescriptor = makeTextureDescriptor(from: inTexture, storageMode: heapStorageMode)
        
        let downsampleSizeAndAlignRequirement =
        downsampleFilter.heapSizeAndAlignWithInputTextureDescriptor(textureDescriptor)
        let gaussianBlurSizeAndAlignRequirement =
        gaussianBlurFilter.heapSizeAndAlignWithInputTextureDescriptor(inDescriptor: textureDescriptor)
        
        let requiredAligment = max(
            gaussianBlurSizeAndAlignRequirement.align,
            downsampleSizeAndAlignRequirement.align
        )
        let gaussianBlurSizeAligned = Renderer.alignUp(inSize: gaussianBlurSizeAndAlignRequirement.size, align: requiredAligment)
        let downsampleSizeAligned = Renderer.alignUp(inSize: downsampleSizeAndAlignRequirement.size, align: requiredAligment)
        let requiredSize = gaussianBlurSizeAligned + downsampleSizeAligned
        
        if scratchHeap == nil || requiredSize > scratchHeap.maxAvailableSize(alignment: requiredAligment) {
            let heapDescriptor = MTLHeapDescriptor()
            heapDescriptor.size = requiredSize
            heapDescriptor.storageMode = heapStorageMode
            scratchHeap = device.makeHeap(descriptor: heapDescriptor)
        }
    }
    
    func executeFilterGraph(inTexture: MTLTexture) -> MTLTexture {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not create command buffer.")
        }
        commandBuffer.label = "Filter Graph Commands"
        
        var resultTexture = downsampleFilter.executeWithCommandBuffer(
            commandBuffer: commandBuffer,
            inTexture: inTexture,
            heap: scratchHeap,
            event: event)
        resultTexture = gaussianBlurFilter.executeWithCommandBuffer(
            commandBuffer: commandBuffer,
            inTexture: resultTexture,
            heap: scratchHeap,
            event: event)
        commandBuffer.commit()
        return resultTexture
    }
    
    func drawIn(_ mtkView: MTKView) {
        blurFrames += 1
        
        if displayTexture == nil {
            let inTexture = imageTextures[currentImageIndex]
            createScratchHeap(inTexture: inTexture)
            displayTexture = executeFilterGraph(inTexture: inTexture)
            currentImageIndex = (currentImageIndex + 1) % Renderer.numberOfImages
            blurFrames = 0
        }
        if blurFrames >= Renderer.maxFramesPerImage {
            displayTexture.makeAliasable()
            let inTexture = imageTextures[currentImageIndex]
            createScratchHeap(inTexture: inTexture)
            displayTexture = executeFilterGraph(inTexture: inTexture)
            currentImageIndex = (currentImageIndex + 1) % Renderer.numberOfImages
            blurFrames = 0
        }
        if displayTexture.width < displayTexture.height {
            quadScale.x = displayScale.x * (Float(displayTexture.width) / Float(displayTexture.height))
            quadScale.y = displayScale.y
        } else {
            quadScale.x = displayScale.x
            quadScale.y = displayScale.y * (Float(displayTexture.height) / Float(displayTexture.width))
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not create command buffer.")
        }
        commandBuffer.label = "Drawable Commands"
        event.wait(commandBuffer)
        
        let renderPassDescriptor = mtkView.currentRenderPassDescriptor
        
        if let renderPassDescriptor = renderPassDescriptor {
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder?.label = "Drawable Render Encoder"
            renderEncoder?.pushDebugGroup("DrawQuad")
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: Renderer.vertexBufferIndexVertices)
            renderEncoder?.setVertexBytes(&quadScale, length: MemoryLayout<simd_float2>.stride, index: Renderer.vertexBufferIndexScale)
            renderEncoder?.setFragmentTexture(displayTexture, index: 0)
            
            var lod = (Float(blurFrames) / Float(Renderer.maxFramesPerImage)) * Float(displayTexture.mipmapLevelCount)
            renderEncoder?.setFragmentBytes(&lod, length: MemoryLayout<Float>.stride, index: 0)
            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder?.popDebugGroup()
            renderEncoder?.endEncoding()
            guard let drawable = mtkView.currentDrawable else {
                fatalError("Error. View current drawable were nil.")
            }
            commandBuffer.present(drawable)
        }
        event.signal(commandBuffer)
        commandBuffer.commit()
    }
    
    func drawableSizeWillChange(_ mtkView: MTKView, _ size: CGSize) {
        if size.width < size.height {
            displayScale.x = 1.0
            displayScale.y = Float(size.width) / Float(size.height)
        } else {
            displayScale.x = Float(size.height) / Float(size.width)
            displayScale.y = 1.0
        }
    }
    
}
