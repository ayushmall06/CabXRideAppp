//
//  AuthButton.swift
//  CabX
//
//  Created by Ayush Mall on 19/06/22.
//

import UIKit

class AuthButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setTitle("Log In", for: .normal)
        setTitleColor(UIColor(white: 1, alpha: 1), for: .normal)
        backgroundColor = .mainBlueTint
        layer.cornerRadius = 5
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
