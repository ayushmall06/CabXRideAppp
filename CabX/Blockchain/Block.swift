//
//  Block.swift
//  CabX
//
//  Created by Ayush Mall on 23/06/22.
//

import UIKit

class Block {
    
    var hash: String!
    var data: String!
    var previousHash: String!
    var index: Int!
    // logic for Block here
    
    func generateHash() -> String {
        return NSUUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}
