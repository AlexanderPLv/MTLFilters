//
//  MetalView.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 06.05.2023.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    
    @EnvironmentObject var metalContext: MetalContext
    
    func makeCoordinator() -> Renderer {
        Renderer(parent: self, context: metalContext)
    }
    
    func makeUIView(context: UIViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.device = metalContext.device
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        mtkView.isPaused = false
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalView>) {
    }
}

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
