//
//  EthTransfer.swift
//  CabX
//
//  Created by Ayush Mall on 23/06/22.
//

import UIKit
import CryptoKit


class EthTransfer {
    static let shared = EthTransfer()
    static var blockNumber: Int = 0
    static var previousHash: String = "b559cdb8bc9ee05c198e11a22c634d88661ac661eb93a706ccbb26e194ce92e1"
    
    static let ethereumChain = Blockchain()
    
    let reward: Double = 0.00000121
    
    let invalidAlert = UIAlertController(title: "Invalid Transaction", message: "Please check the details of your transaction", preferredStyle: .alert)
    
    func sendCryptoToContract(fromUid source: String, amount: Double) {
        //var senderWalletAddress: String = ""
        var senderEthers: Double = 0
        //var receiverWalletAddress: String = ""
        Service.shared.fetchUserData(uid: source) { user in
            
            senderEthers = NSString(string: user.ethers).doubleValue
            senderEthers = senderEthers - amount
            Service.shared.updateUserEthers(ethers: String(format: "%f", arguments: [senderEthers]), uid: source)
            var contractCrypto = NSString(string: Service.shared.getCrypto()).doubleValue
            contractCrypto += amount
            Service.shared.updateCrypto(ethers: String(format: "%f", arguments: [contractCrypto]))
            
        }
    }
    
    func sendCryptoFromContract(toUid destination: String, amount: Double) {
        Service.shared.fetchUserData(uid: destination) { user in
            var receiverEthers = NSString(string: user.ethers).doubleValue
            receiverEthers = receiverEthers + amount
            Service.shared.updateUserEthers(ethers: String(format: "%f", arguments: [receiverEthers]), uid: destination)
            var contractCrypto = NSString(string: Service.shared.getCrypto()).doubleValue
            contractCrypto -= amount
            Service.shared.updateCrypto(ethers: String(format: "%f", arguments: [contractCrypto]))
        }
    }
    
    
    func sendEthers(fromWalletAddress fromWalletAddress: String, toWalletAddress toWalletAddress: String, amount amount: String) {
        
        let hash = SHA256.hash(data: Data(amount.utf8)).compactMap{
            String(format: "%02x", $0)
        }.joined()
        
        let index = hash.index(hash.startIndex, offsetBy: 40)
        let walletAddress = hash.prefix(upTo: index)
        
        print("BLOCKCHAIN: New Block mined:")
        print("BLOCKCHAIN:     Block: \(EthTransfer.blockNumber)")
        EthTransfer.blockNumber += 1
        print("BLOCKCHAIN:     Hash: \(hash)")
        print("BLOCKCHAIN:     PreviousHash: \(EthTransfer.previousHash)")
        EthTransfer.previousHash = hash
        print("BLOCKCHAIN:     Data: From: 0x\(fromWalletAddress) To: 0x\(walletAddress) Amount: \(amount)ETH")
        print("BLOCKCHAIN: Chain is Valid: true")
    }
}
