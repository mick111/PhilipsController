//
//  PCPhilipsCommunicator.swift
//  Philips Controller
//
//  Created by Michael Mouchous on 28/09/2017.
//  Copyright © 2017 Michael Mouchous. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let newValue = Notification.Name(rawValue: "newValue")
}
extension AnyHashable {
    static let response = "response"
}

class PCPhilipsCommunicator: NSObject, URLSessionDelegate {
    
    var address: String = "192.168.42.36"
    var username: String = "ziBPcKz4N36GEocS"
    var password: String = "6c17071f094fbba5317a02069fe23009b3b1def19bb5b7c802defeeb953cc86e"
    var volume: Int = 0
    var session: URLSession!


    /// URLSessionDelegate
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.host == address else { return }
        
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            challenge.sender!.use(credential, for: challenge)
            completionHandler(.useCredential, credential)
        default:
            completionHandler(.useCredential, URLCredential(user: username, password: password, persistence: .none))
            return
        }
    }

    let cmds_get = [
        "tv": "/6/channeldb/tv",
        "applications": "/6/applications",
        "audio": "/6/audio/volume",
        "ambilightMode": "/6/ambilight/mode",
        "ambilightTopology": "/6/ambilight/topology",
        "recordings": "/6/recordings/list",
        "powerstate": "/6/powerstate",
        "ambilightCurrentConfiguration": "/6/ambilight/currentconfiguration",
        "channelLists": "/6/channeldb/tv/channelLists/all",
        "epgsource": "/6/system/epgsource",
        "system": "/6/system",
        "systemStorage": "/6/system/storage",
        "timestamp": "/6/system/timestamp",
        "structure": "/6/menuitems/settings/structure",
        "ambilight": "/6/ambilight/cached",
        "name": "/6/system/name",
        ]

    let cmds_post = [
        "standby": "/6/input/key",
        "vol 42": "/6/audio/volume",
        "vol muted": "/6/audio/volume",
    ]

    lazy var cmds = [cmds_get, cmds_post]

    func postValue(for: String, body: String) {
        guard let uri = cmds_post[`for`] else { return }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session.configuration.httpAdditionalHeaders = nil
        var request = URLRequest(url: URL(string:"https://\(self.address):1926\(uri)")!)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        let task = session.dataTask(with: request) {
            self.handeResponse(data: $0, response: $1, error: $2, uri: uri, method: "POST", body: body.data(using: .utf8))
        }

        task.resume()
    }
    func getValue(for: String) {
        guard let uri = cmds_get[`for`] else { return }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session.configuration.httpAdditionalHeaders = nil
        let task = session.dataTask(with: URL(string:"https://\(address):1926\(uri)")!) {
            self.handeResponse(data: $0, response: $1, error: $2, uri: uri, method: "GET")
        }
        task.resume()
    }

    func handeResponse(data: Data?, response: URLResponse?, error: Error?, uri: String, method: String, additionalHeaders: [AnyHashable : Any]? = nil, body: Data? = nil) {
        // Got an error, no need to go further
        if let error = error {
            NSLog("\(error)")
            return
        }

        // We need to authenticate
        if let httpResponse = (response as? HTTPURLResponse),
            httpResponse.statusCode == 401,
            let allHeaderFields = httpResponse.allHeaderFields["Www-Authenticate"] as? String,
            allHeaderFields.hasPrefix("Digest ")
        {
            // Construct additional auth
            let userDict = ["username":self.username,
                            "uri":uri,
                            "method": method]

            // Parse the content
            let wwwAuthInfosDict = allHeaderFields
                .dropFirst(7)
                .replacingOccurrences(of: ", ", with: ",")
                .replacingOccurrences(of: "\"", with: "")
                .split(separator: ",")
                .map { String($0) }
                .map {
                    let kv = $0.split(separator: "=", maxSplits: 1)
                    return [String(kv[0]):String(kv[1])]
                }
                .reduce(userDict) { $0.merging($1) { f,_ in return f } }

            // Compute the response digest
            guard let authHeader = PCHTTPDigest.auth(infos: wwwAuthInfosDict, password: self.password) else { return }

            // Prepare the session to integrate this
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json",
                "Authorization": authHeader].merging(additionalHeaders ?? [:]) {f,_ in f}
            self.session = URLSession(configuration: configuration,
                                      delegate: self, delegateQueue: nil)
            // Ask for the same thing
            var request = URLRequest(url: URL(string:"https://\(self.address):1926\(uri)")!)
            request.httpMethod = method
            request.httpBody = body
            let task = self.session.dataTask(with: request) {
                self.handeResponse(data: $0, response: $1, error: $2, uri: uri, method: method,
                                   additionalHeaders: additionalHeaders,
                                   body: body)
            }
            task.resume()
        } else if let data = data, let dataStr = String(data: data, encoding: .utf8) {
            // Got some interesting data. Just post it.
            NotificationCenter.default.post(name: .newValue, object: self, userInfo: [.response: dataStr])
        }
    }
}
