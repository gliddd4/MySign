//
//  ImageState.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import UIKit

enum ImageState {
    case empty
    case progress(completed: Int64, total: Int64)
    case success(UIImage)
    case failure
    
    var image: UIImage? {
        switch self {
        case .success(let image): return image
        default: return nil
        }
    }
}
