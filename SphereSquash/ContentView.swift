//
//  ContentView.swift
//  SphereSquash
//
//  Created by Lucas, Ben on 2/26/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var inputImage: CIImage?
    @State private var outputImage: NSImage?
    
    // Projection parameters
    @State private var mode: ProjectionMode = .equirectangular       // 0: Equirectangular, 1: Stereographic, 2: Perspective, 3: Quincuncial
    @State private var theta: Float = 0.0  // In degrees, range: -180...180
    @State private var phi: Float = 0.0    // In degrees, range: -90...90

    @State private var panStartTheta: Float? = nil
    @State private var panStartPhi: Float? = nil
    @StateObject private var shiftMonitor = ShiftKeyMonitor()

    @State private var fovValues: [ProjectionMode: Float] = [
        .equirectangular: 180,
        .stereographic: 180,
        .perspective: 90,
        .quincuncial: 180
    ]
    
    // A binding that returns the FOV for the current mode.
    private var currentFov: Binding<Float> {
        Binding<Float>(
            get: { self.fovValues[self.mode] ?? 180 },
            set: { self.fovValues[self.mode] = $0 }
        )
    }
    
    
    let ciContext = CIContext()
    
    // Function to load an image from disk using NSOpenPanel
    func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "tiff"]
        if panel.runModal() == .OK, let url = panel.url,
           let ciImage = CIImage(contentsOf: url) {
            inputImage = ciImage
            applyFilter()
        }
    }
    
    // Function to apply your custom panoramic filter
    func applyFilter() {
        guard let inputImage = inputImage else { return }
        let filter = PanoramicFilter()  // Your custom filter class
        filter.inputImage = inputImage
        filter.setMode(mode)
        filter.setTheta(theta)
        filter.setPhi(phi)
        filter.setFoV(currentFov.wrappedValue)

        // Obtain the output CIImage and convert it to an NSImage for display
        if let outputCIImage = filter.outputImage,
           let cgImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) {
            outputImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
    
    // Function to save the output image using NSSavePanel
    func saveImage() {
        guard let outputImage = outputImage else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png", "jpg"]
        panel.nameFieldStringValue = "panorama.jpg"
        if panel.runModal() == .OK, let url = panel.url {
            if let tiffData = outputImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }

    
    
    var body: some View {
        VStack {
            if let outputImage = outputImage {
                Image(nsImage: outputImage)
                    .resizable()
                    .scaledToFit()
                    .frame(minWidth: 600, minHeight: 400)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                // If this is the first update, record the starting values.
                                if panStartTheta == nil || panStartPhi == nil {
                                    panStartTheta = theta
                                    panStartPhi = phi
                                }
                                let isHorizontalOnly = shiftMonitor.shiftDown && (gesture.translation.width > gesture.translation.height)
                                let isVerticalOnly = shiftMonitor.shiftDown && (gesture.translation.width < gesture.translation.height)
                                
                                let scale: Float = 1.0
                                theta = (panStartTheta ?? theta) + (isVerticalOnly ? 0.0 : Float(gesture.translation.width)) * scale
                                phi = (panStartPhi ?? phi) - (isHorizontalOnly ? 0.0 : Float(gesture.translation.height)) * scale
                                
                                // Clamp phi to its range.
                                phi = min(max(phi, -90), 90)
                                
                                applyFilter()
                            }
                            .onEnded { _ in
                                // Reset the starting values when the gesture ends.
                                panStartTheta = nil
                                panStartPhi = nil
                            })
                HStack {
                    Button("Load Image") { loadImage() }
                    Button("Save Image") { saveImage() }
                    Spacer()
                }
                .padding()
                
                // Projection mode selection
                Picker("Projection Mode", selection: $mode) {
                    Text("Equirectangular").tag(ProjectionMode.equirectangular)
                    Text("Stereographic").tag(ProjectionMode.stereographic)
                    Text("Perspective").tag(ProjectionMode.perspective)
                    Text("Quincuncial").tag(ProjectionMode.quincuncial)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: mode, perform: { _ in applyFilter() })
                
                // Parameter sliders for theta, phi, and fov
                VStack {
                    if self.mode != .equirectangular {
                        HStack {
                            Text("FoV")
                            Slider(value: Binding(
                                get: { self.currentFov.wrappedValue },
                                set: { newValue in
                                    self.currentFov.wrappedValue = newValue
                                    applyFilter()
                                }
                            ), in: 0...180)
                            Text("\(Int(currentFov.wrappedValue))°")
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .padding()
            } else {
                Button(action: { loadImage() }){
                    Text("Click here to load a panorama")
                        .frame(width: 600, height: 400)
                        .border(Color.gray)
                }
            }

        }
        .frame(minWidth: 800, minHeight: 700)
    }
}

#Preview {
    ContentView()
}
