//
//  UploadedFile.swift
//  ShareMaster
//
//  Created by Conor Ryan on 02/07/26.
//

import Foundation
import SwiftData

@Model
final class UploadedFile {
    var filename: String
    var key: String
    var url: String
    var size: Int64
    var uploadedAt: Date
    
    init(filename: String, key: String, url: String, size: Int64, uploadedAt: Date = Date()) {
        self.filename = filename
        self.key = key
        self.url = url
        self.size = size
        self.uploadedAt = uploadedAt
    }
}
