//
//  EventWrapper.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 05.05.2023.
//

import Metal

protocol EventWrapper: AnyObject {
    func wait(_ commandBuffer: MTLCommandBuffer)
    func signal(_ commandBuffer: MTLCommandBuffer)
}
