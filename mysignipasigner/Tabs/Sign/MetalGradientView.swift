//
//  MetalGradientView.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI
import MetalKit

struct MetalGradientView: UIViewRepresentable {
    @State private var startTime = Date()
    var colorScheme: Int32 = 0
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        let renderer = MetalGradientRenderer(mtkView: mtkView, colorScheme: colorScheme)
        mtkView.delegate = renderer
        context.coordinator.renderer = renderer
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.updateColorScheme(colorScheme)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: MetalGradientRenderer?
    }
}

class MetalGradientRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer
    private var startTime: CFTimeInterval
    private var colorScheme: Int32
    
    init?(mtkView: MTKView, colorScheme: Int32 = 0) {
        guard let device = mtkView.device else { return nil }
        self.device = device
        self.colorScheme = colorScheme
        
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue
        
        // Create vertex data for a full-screen quad
        let vertices: [Float] = [
            -1.0, -1.0, 0.0,  // Bottom left
             1.0, -1.0, 0.0,  // Bottom right
            -1.0,  1.0, 0.0,  // Top left
             1.0,  1.0, 0.0   // Top right
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: []) else { return nil }
        self.vertexBuffer = vertexBuffer
        
        // Load the shader library
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "gradient_animation_vertex"),
              let fragmentFunction = library.makeFunction(name: "gradient_animation_fragment") else { return nil }
        
        // Create render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            return nil
        }
        
        self.startTime = CACurrentMediaTime()
        
        super.init()
    }
    
    func updateColorScheme(_ newScheme: Int32) {
        self.colorScheme = newScheme
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes if needed
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Calculate time
        var currentTime = Float(CACurrentMediaTime() - startTime)
        
        // Calculate view size
        var viewSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        // Use the current color scheme
        var page: Int32 = colorScheme
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&currentTime, length: MemoryLayout<Float>.stride, index: 1)
        renderEncoder.setVertexBytes(&viewSize, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)
        renderEncoder.setVertexBytes(&page, length: MemoryLayout<Int32>.stride, index: 3)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}