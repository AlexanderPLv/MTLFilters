//
//  GaussianBlurFilter.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 05.05.2023.
//

import Metal

enum FilterError: Error {
    case makeGaussianHorizontalFunctionError
    case makeGaussianVerticalFunctionError
}

extension FilterError {
    var localizedDescription: String {
        switch self {
        case .makeGaussianHorizontalFunctionError:
            return "Failed creating a GaussianHorizontalBlur function."
        case .makeGaussianVerticalFunctionError:
            return "Failed creating a GaussianVerticalBlur function."
        }
    }
}

final class GaussianBlurFilter {
    
    private let device: MTLDevice
    private let horizontalKernel: MTLComputePipelineState
    private let verticalKernel: MTLComputePipelineState
    
    init(device: MTLDevice) {
        self.device = device
        let defaultLibrary = device.makeDefaultLibrary()
        do {
            guard let horizontalBlur = defaultLibrary?.makeFunction(name: "gaussianblurHorizontal") else {
                throw FilterError.makeGaussianHorizontalFunctionError
            }
            guard let verticalBlur = defaultLibrary?.makeFunction(name: "gaussianblurVertical") else {
                throw FilterError.makeGaussianVerticalFunctionError
            }
            horizontalKernel = try device.makeComputePipelineState(function: horizontalBlur)
            verticalKernel = try device.makeComputePipelineState(function: verticalBlur)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func heapSizeAndAlignWithInputTextureDescriptor(inDescriptor: MTLTextureDescriptor) -> MTLSizeAndAlign {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: inDescriptor.width >> 1,
            height: inDescriptor.height >> 1,
            mipmapped: false)
        return device.heapTextureSizeAndAlign(descriptor: textureDescriptor)
    }
    
    func executeWithCommandBuffer(
        commandBuffer: MTLCommandBuffer,
        inTexture: MTLTexture,
        heap: MTLHeap,
        event: EventWrapper
    ) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 0,
            height: 0,
            mipmapped: false)
        textureDescriptor.storageMode = heap.storageMode
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        (1..<inTexture.mipmapLevelCount).forEach { mipmapLevel in
            textureDescriptor.width = inTexture.width >> mipmapLevel
            textureDescriptor.height = inTexture.height >> mipmapLevel
            
            if textureDescriptor.width <= 0 {
                textureDescriptor.width = 1
            }
            if textureDescriptor.height <= 0 {
                textureDescriptor.height = 1
            }
            
            guard let intermediaryTexture = heap.makeTexture(descriptor: textureDescriptor) else {
                fatalError("Failed to allocate MTLTexture on heap")
            }
            var threadgroupSize = MTLSize(
                width: FilterConstants.threadgroupWidth,
                height: FilterConstants.threadgroupHeight,
                depth: FilterConstants.threadgroupDepth)
            var threadgroupCount = MTLSize(
                width: (intermediaryTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (intermediaryTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: FilterConstants.threadgroupDepth)
            let levels = Range(NSMakeRange(mipmapLevel, 1))!
            let slices = Range(NSMakeRange(0, 1))!
            let outTexture = inTexture.makeTextureView(
                pixelFormat: inTexture.pixelFormat,
                textureType: inTexture.textureType,
                levels: levels,
                slices: slices)
            
            event.wait(commandBuffer)
            
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState(horizontalKernel)
                computeEncoder.setTexture(inTexture, index: FilterConstants.blurTextureIndexInput)
                computeEncoder.setTexture(intermediaryTexture, index: FilterConstants.blurTextureIndexOutput)
                var encoderMipmapLevel = mipmapLevel
                computeEncoder.setBytes(
                    &encoderMipmapLevel,
                    length: MemoryLayout<Int>.stride,
                    index: FilterConstants.blurBufferIndexLOD)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                
                computeEncoder.setComputePipelineState(verticalKernel)
                computeEncoder.setTexture(intermediaryTexture, index: FilterConstants.blurTextureIndexInput)
                computeEncoder.setTexture(outTexture, index: FilterConstants.blurTextureIndexOutput)
                
                var mipMapLevelZero = 0
                computeEncoder.setBytes(&mipMapLevelZero, length: MemoryLayout<Int>.stride, index: FilterConstants.blurBufferIndexLOD)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                computeEncoder.endEncoding()
            }
            event.signal(commandBuffer)
            intermediaryTexture.makeAliasable()
        }
        return inTexture
    }
    
}
