//
//  EntityProtocol.swift
//  TestNetwork
//
//  Created by uma6 on 2016/12/03.
//  Copyright © 2016年 uma6. All rights reserved.
//

import ObjectMapper

// マッピング結果判定処理をEntity毎に実装し、resultパターンで返却するためのもの
enum MappingResult {
    case Success
    case Failure
}

protocol EntityProtocol : Mappable {
    func validatedResult() -> MappingResult
}

extension EntityProtocol {
    func validatedResult() -> MappingResult {
        return .Success // default
    }
}

