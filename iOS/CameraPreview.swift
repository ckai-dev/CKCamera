//
//  CameraPreview.swift
//  CKBasicCamera
//
//  Created by Kai Chen on 12/19/22.
//

import UIKit
import AVFoundation

class CameraPreview: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check CameraPreview.layerClass implementation.")
        }
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

}
