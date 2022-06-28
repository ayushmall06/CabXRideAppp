//
//  Blockchain.swift
//  CabX
//
//  Created by Ayush Mall on 23/06/22.
//

import UIKit

class Blockchain {

    var chain = [Block]()
    
    func createInitialBlock(data:String) {
        let genesisBlock = Block()
        genesisBlock.hash = genesisBlock.generateHash()
        genesisBlock.data = data
        genesisBlock.previousHash = "b559cdb8bc9ee05c198e11a22c634d88661ac661eb93a706ccbb26e194ce92e1"
        genesisBlock.index = 0
        chain.append(genesisBlock)
    }
    
    func createBlock(data:String) {
        let newBlock = Block()
        newBlock.hash = newBlock.generateHash()
        newBlock.data = data
        newBlock.previousHash = chain[chain.count-1].hash
        newBlock.index = chain.count
        chain.append(newBlock)
    }

    
}

