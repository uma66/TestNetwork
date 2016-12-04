//
//  ViewController.swift
//  TestNetwork
//
//  Created by uma6 on 2016/12/03.
//  Copyright © 2016年 uma6. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let _ = LoginRouter.signIn(userId: "userId", uuid: "uuid").startRequest { result in
            
            print("callback")
            
            var loginId = "";
            
            switch result {
            case .success(let loginEntity):
                loginId = loginEntity.loginId!
                break
            case .failure(let loginEntity):
                loginId = loginEntity.loginId!
                break
            case .error(_):
                break
            }
            
        }
        
    }
    
}

