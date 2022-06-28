//
//  User.swift
//  CabX
//
//  Created by Ayush Mall on 21/06/22.
//

import CoreLocation

enum AccountType: Int {
    case passenger
    case driver
}

struct User {
    let fullname: String
    let email: String
    var accountType: AccountType!
    var location: CLLocation?
    let uid: String
    let ethers: String
    let walletAddress: String
    
    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        self.fullname = dictionary["fullname"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""
        self.ethers = dictionary["ethers"] as? String ?? ""
        self.walletAddress = dictionary["walletAddress"] as? String ?? ""
        
        if let index = dictionary["accounttype"] as? Int {
            self.accountType = AccountType(rawValue: index)!
            
        }
    }
}

