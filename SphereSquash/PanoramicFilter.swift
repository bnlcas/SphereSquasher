//
//  CustomFilter.swift
//  GlimmerCamera
//
//  Created by Benjamin Lucas on 2/12/23.
//
import CoreImage

enum ProjectionMode: Int {
    case equirectangular = 0,
         stereographic = 1,
         perspective = 2,
         quincuncial = 3
}

class PanoramicFilter : CIFilter
{
    var mode : ProjectionMode = .equirectangular
    
    var theta_normalized : Float  = 0.0
    var phi_normalized : Float = 0.0
    var fov_normalized : Float = 1.0

    //CIColorKernel -> CIKernel
    static var panoramaKernel : CIKernel = { () -> CIKernel in
        let url = Bundle.main.url(forResource: "PanoramaShader", withExtension: "ci.metallib")!
        let data = try! Data(contentsOf: url)
        
        do {
            return try CIKernel(functionName: "panoramaShader", fromMetalLibraryData: data)
        }
        catch {
            print("\(error)")
            fatalError("\(error)")
        }
    }()
    
    //
    public func setMode(_ mode: ProjectionMode){
        self.mode = mode
    }
    
    public func setTheta(_ theta: Float){
        self.theta_normalized = theta / 180 // -1.0 to 1.0
        print(self.theta_normalized)
    }
    
    public func setPhi(_ phi: Float){
        self.phi_normalized = phi / 90 // -1.0 to 1.0
        print(self.phi_normalized)
    }
    
    public func setFoV(_ fov: Float){
        self.fov_normalized = fov/180;
        print(fov_normalized)
    }

    
    @objc dynamic var inputImage : CIImage?
    
    override var outputImage : CIImage!
    {
        guard let inputImage = self.inputImage else
        {
            return nil
        }
        //, Float(self.threshold)
        let arguments = [inputImage, inputImage.extent.width, inputImage.extent.height, self.mode.rawValue, self.theta_normalized, self.phi_normalized, self.fov_normalized] as [Any]
        
        //return Self.panoramaKernel.apply(extent: inputImage.extent, arguments: arguments)
        
        return Self.panoramaKernel.apply(
          extent: inputImage.extent,
          roiCallback: {(index, rect) -> CGRect in return rect},
          arguments: arguments)//[inputImage, threshold])
    }
}
