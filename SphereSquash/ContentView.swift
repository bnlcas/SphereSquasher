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
    @State private var fov: Float = 180.0  // In degrees, range: 0...180
    
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
        filter.setFoV(fov)
        
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
                HStack{
                    HStack{
                        VStack{
                            Spacer()
                            Text("Phi: \(Int(phi))°")
                                .rotationEffect(.degrees(-90))
                        }
                        DialSliderView(value: Binding(
                            get: { Double(phi) },
                            set: { newValue in phi = Float(newValue); applyFilter() }
                        ), sliderRange: -90...90, orientation: .vertical)
                            .frame(width: 50, alignment: .trailing)
                    }
                    Image(nsImage: outputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 600, maxHeight: 400)
                    Spacer()
                }
                VStack {
                    HStack{
                        Text("Theta: \(Int(theta))°")
                        Spacer()
                    }
                    DialSliderView(value: Binding(
                        get: { Double(theta) },
                        set: { newValue in theta = Float(newValue); applyFilter() }
                    ), sliderRange: -180...180, orientation: .horizontal)
                }
                // Buttons to load and save the image
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
                    HStack {
                        Text("FoV")
                        Slider(value: Binding(
                            get: { Double(fov) },
                            set: { newValue in fov = Float(newValue); applyFilter() }
                        ), in: 0...180)
                        Text("\(Int(fov))°")
                            .frame(width: 50, alignment: .trailing)
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
