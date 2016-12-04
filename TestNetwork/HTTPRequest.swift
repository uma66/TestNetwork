//
//  HTTPRequest.swift
//  TestNetwork
//
//  Created by uma6 on 2016/12/03.
//  Copyright © 2016年 uma6. All rights reserved.
//

import Alamofire
import ObjectMapper

internal enum SocketEventType<T> {
    case connect(T)
    case disconnect(T)
    case recieveData(T)
    case error(NSError)
}

// structにはmutaingなプロパティを定義できないため、classを強制する
// そもそもクロージャを
protocol BaseSocketClient: class {
    associatedtype EntityType: EntityProtocol
    // typealiasに@escapingを定義できないbugがあるため、escapingなfuncはtypealiasは使えない
    // https://bugs.swift.org/browse/SR-2316
    func connect(eventHandler: @escaping (SocketEventType<EntityType>) -> Void) -> Void
    var onEvent: ((SocketEventType<EntityType>) -> Void)? {
        get set
    }
}

extension BaseSocketClient {
    func connect(eventHandler: @escaping (SocketEventType<EntityType>) -> Void) -> Void {
        self.onEvent = eventHandler
    }
}

class LoginSocketClient: BaseSocketClient {
    typealias EntityType = LoginEntity
    var onEvent: ((SocketEventType<LoginEntity>) -> Void)?
}



internal enum RequestResultType<T> {
    case success(T)
    case failure(T)
    case error(NSError)
}

// 念のためラップして返却する
final internal class HTTPRequest {
    var request: Alamofire.DataRequest
    required init(request: Alamofire.DataRequest) {
        self.request = request
    }
}

typealias RequestParams = [String: Any?]

internal typealias RequestSettings = (
    method: HTTPMethod,
    path: String,
    contentType: ContentType,
    params: RequestParams?,
    needsAccessToken: Bool
)

internal enum ContentType: String {
    case None
    case XFormUrlEncoded = "application/x-www-form-urlencoded"
    case Json = "application/json"
}

internal protocol HTTPRouter {
    associatedtype EntityType: EntityProtocol
    func requestSettings() -> RequestSettings
    func sessionManager() -> SessionManager
}

extension HTTPRouter where Self: URLRequestConvertible {
    
    typealias CompletionHandelr = (RequestResultType<EntityType>) -> Void
    
    func createRequest() throws -> URLRequest  {
        let (method, path, contentType, params, needsAccessToken) = self.requestSettings()
        
        let url = try LoginRouter.baseURLString.asURL()
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue
        
        if contentType != .None {
            urlRequest.addValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        }
        
        if needsAccessToken == true {
            urlRequest.addValue("token", forHTTPHeaderField: "access-token")
        }
        
        return try URLEncoding.default.encode(urlRequest, with: eliminateNilParams(params: params))
    }
    
    func eliminateNilParams(params: RequestParams?) -> [String: Any]? {
        var eliminatedParams: [String: Any]? = [:]
        
        if let keys = params?.keys {
            for key in keys {
                if let value = params?[key] {
                    eliminatedParams?[key] = value
                }
            }
        }
        return eliminatedParams
    }
    
    // 返り値を使わないことを許可
    @discardableResult
    internal func startRequest(completionHandler: @escaping CompletionHandelr) -> HTTPRequest? {
        
        return HTTPRequest(request:
            self.sessionManager().request(self)
            //Alamofire.request(self as! URLRequestConvertible)
                .responseJSON { response in
                    
                    let statusCode: Int? = response.response?.statusCode
                    print("debugDescription: \(response.response.debugDescription)")
                    
                    if statusCode == 200,
                        let entity = Mapper<EntityType>().map(JSONObject: response.result.value)
                    {
                        
                        if case .Failure =  entity.validatedResult() {
                            completionHandler(RequestResultType<EntityType>.failure((entity as EntityType)))
                            return
                        }
                        
                        completionHandler(RequestResultType<EntityType>.success((entity as EntityType)))
                        return
                        
                    } else if statusCode == 400,
                        let entity = Mapper<EntityType>().map(JSONObject: response.result.value)
                    {
                        completionHandler(RequestResultType<EntityType>.failure((entity as EntityType)))
                        
                    } else if let error = response.result.error
                    {
                        completionHandler(RequestResultType<EntityType>.error(error as NSError))
                    }
        })
        
    }
    
    func sessionManager() -> SessionManager {
        return SessionManager.default
    }
    
}

// アプリ共通の設定はサブクラスでやる
class HTTPSessionManager : Alamofire.SessionManager {
    
}

// Entityはstructだと重くなるらしいからclassでも良い。entityは頻繁に参照されるし、realmでDBに結構なデータを保存するから、
// classに統一した方が良いかも。
struct LoginEntity: EntityProtocol {
    var loginId: String?
    
    init?(map: Map) {
    }
    mutating func mapping(map: Map) {
        loginId <- map["login_id"]
    }
    
    // 必要ならEntity毎に個別にバリデーション判定を実装
    func validatedResult() -> MappingResult {
        return self.loginId != nil ? .Success : .Failure
    }
}

internal enum LoginRouter: URLRequestConvertible, HTTPRouter {
    
    typealias EntityType = LoginEntity
    static let baseURLString = "https://example.com"
    
    case signIn(userId: String, uuid: String)
    case changePassword(nowPassword: String, toPassword: String)
    case signOut(userId: String)
    
    func asURLRequest() throws -> URLRequest {
        return try self.createRequest()
    }
    
    func requestSettings() -> RequestSettings {
        switch self {
        case .signIn(let userId, let uuid):
            return (.post, "/user/signIn/\(userId)", .Json, ["uuid": uuid], false)
        case .changePassword(let nowPassword, let toPassword):
            return (.post, "/user/changePassword/", .Json, ["now_password": nowPassword,
                                                            "to_password": toPassword], false)
        case .signOut(let userId):
            return (.put, "/user/signOut/\(userId)", .Json, [:], false)
        }
    }
    
    // Router or API個別の設定はここでやる
    func sessionManager() -> SessionManager {
        switch self {
        case .signIn, .changePassword, .signOut:
            // headerが共通の場合は、defaultHTTPHeadersみたいにstaticで定義しておいても良い。
            // 完全に全てのAPIが同じ設定であれば、HTTPSessionManagerをシングルトンにすれば良い。
//            var defaultHeaders = Alamofire.SessionManager.default.defaultHTTPHeaders
//            defaultHeaders["DNT"] = "1 (Do Not Track Enabled)"
            let configuration = URLSessionConfiguration.default
//            configuration.httpAdditionalHeaders = defaultHeaders
            /*
            var defaultHeaders = HTTPSessionManager.default.defaultHTTPHeaders
            defaultHeaders["DNT"] = "1 (Do Not Track Enabled)"
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = defaultHeaders
            */
            return Alamofire.SessionManager(configuration: configuration)
        }
    }
    
}

