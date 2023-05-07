//
//  DownsampleFilter.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 05.05.2023.
//

import Metal

final class DownsampleFilter {
    private let device: MTLDevice
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func heapSizeAndAlignWithInputTextureDescriptor(_ inDescriptor: MTLTextureDescriptor) -> MTLSizeAndAlign {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inDescriptor.pixelFormat,
            width: inDescriptor.width,
            height: inDescriptor.height,
            mipmapped: true
        )
        return device.heapTextureSizeAndAlign(descriptor: textureDescriptor)
    }
    
    func executeWithCommandBuffer(
        commandBuffer: MTLCommandBuffer,
        inTexture: MTLTexture,
        heap: MTLHeap,
        event: EventWrapper
    ) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inTexture.pixelFormat,
            width: inTexture.width,
            height: inTexture.height,
            mipmapped: true)
        textureDescriptor.storageMode = heap.storageMode
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let outTexture = heap.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Error. Failed to allocate texture on heap.")
        }
        event.wait(commandBuffer)
        
        if let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitCommandEncoder.copy(
                from: inTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: inTexture.width, height: inTexture.height, depth: inTexture.depth),
                to: outTexture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blitCommandEncoder.generateMipmaps(for: outTexture)
            blitCommandEncoder.endEncoding()
        }
        event.signal(commandBuffer)
        return outTexture
    }
    
}
