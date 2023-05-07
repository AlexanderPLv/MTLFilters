//
//  MetalContext.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 07.05.2023.
//

import Metal

final class MetalContext: ObservableObject {
    
     let device: MTLDevice
     let commandQueue: MTLCommandQueue
 
     init() {
         guard let metalDevice = MTLCreateSystemDefaultDevice() else {
             fatalError("Unable to create a Metal device")
          }
         self.device = metalDevice
         guard let commandQueue = metalDevice.makeCommandQueue() else {
             fatalError("Unable to establish a metalCommandQueue on a Metal device")
         }
         self.commandQueue = commandQueue
     }
 }
