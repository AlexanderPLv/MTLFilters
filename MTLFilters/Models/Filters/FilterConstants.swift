//
//  FilterConstants.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 06.05.2023.
//

import Foundation

enum FilterConstants {
    static let threadgroupWidth = 16
    static let threadgroupHeight = 16
    static let threadgroupDepth  = 1
    
    static let blurTextureIndexInput  = 0
    static let blurTextureIndexOutput = 1
    static let blurBufferIndexLOD = 0
}
