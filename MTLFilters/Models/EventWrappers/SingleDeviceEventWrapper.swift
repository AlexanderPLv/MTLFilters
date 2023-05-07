//
//  SingleDeviceEventWrapper.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 05.05.2023.
//

import Metal

final class SingleDeviceEventWrapper: EventWrapper {
    
    var event: MTLEvent
    var signalCounter: UInt64
    
    init(device: MTLDevice) {
        guard let event = device.makeEvent() else {
            fatalError("Error. Could not create event.")
        }
        self.event = event
        self.signalCounter = 0
    }
    
    func wait(_ commandBuffer: MTLCommandBuffer) {
        assert(event.conforms(to: MTLSharedEvent.self) || commandBuffer.device === event.device)
        commandBuffer.encodeWaitForEvent(event, value: signalCounter)
    }
    
    func signal(_ commandBuffer: MTLCommandBuffer) {
        assert(event.conforms(to: MTLSharedEvent.self) || commandBuffer.device === event.device)
        signalCounter += 1
        commandBuffer.encodeSignalEvent(event, value: signalCounter)
    }
    
    
}
