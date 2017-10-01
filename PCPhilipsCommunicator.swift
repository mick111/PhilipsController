//
//  PCPhilipsCommunicator.swift
//  Philips Controller
//
//  Created by Michael Mouchous on 28/09/2017.
//  Copyright © 2017 Michael Mouchous. All rights reserved.
//

import Foundation
import Crypto

extension Notification.Name {
    static let newValue = Notification.Name(rawValue: "newValue")
}
extension AnyHashable {
    static let response = "response"
}

extension String {
    var hmac: String {
        return (self.hmac(key: PCPhilipsCommunicator.secretKey, algorithm: .sha1)!.data(using: .utf8)?.base64EncodedString())!
    }
}
class PCPhilipsCommunicator: NSObject, URLSessionDelegate {
    // Keychain Configuration
    struct KeychainConfiguration {
        static let serviceName = "PhilipsControler"
        static let accessGroup: String? = nil
    }

    /// Key used for generated the HMAC signature
    static let secretKey = String(data: Data(base64Encoded: "ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXzToowvhHvA==")!, encoding: .utf8)!

    var address: String = "192.168.42.36"

    lazy var username = (UserDefaults.standard.value(forKey: "username") as? String) ?? "ziBPcKz4N36GEocS"

    var passwordItems: [KeychainPasswordItem] = []

    var defaultHA1: String = ""

    func save(password: String, for accountName: String) {
        UserDefaults.standard.setValue(accountName, forKey: "username")
        save(ha1: [accountName, "XTV", password].joined(separator: ":").md5!, for: accountName)
    }

    func save(ha1: String, for accountName: String) {
        UserDefaults.standard.setValue(accountName, forKey: "username")
        do {
            // This is a new account, create a new keychain item with the account name.
            let passwordItem = KeychainPasswordItem(service: KeychainConfiguration.serviceName,
                                                    account: accountName,
                                                    accessGroup: KeychainConfiguration.accessGroup)

            // Save the password for the new item.
            try passwordItem.savePassword(ha1)
        } catch {
            fatalError("Error updating keychain - \(error)")
        }
    }

    var ha1: String? {
        guard let accountName = UserDefaults.standard.value(forKey: "username") as? String else {
            // Is not present
            save(ha1: defaultHA1, for: username)
            return defaultHA1
        }

        do {
            let passwordItem = KeychainPasswordItem(service: KeychainConfiguration.serviceName,
                                                    account: accountName,
                                                    accessGroup: KeychainConfiguration.accessGroup)
            return try passwordItem.readPassword()
        }
        catch {
            fatalError("Error reading password from keychain - \(error)")
        }
    }


//    func pair() {
//        var config = ["application_id":"app.id",
//                      "device_id": username,
//                      ]
//
//        let device_spec =  [
//            "device_name": "heliotrope",
//            "device_os": "Android",
//            "app_name": "ApplicationName",
//            "type": "native",
//            "app_id": "app.id" ,
//            "id": username ,
//        ]
//
//
//        let data : [String : Any] = [
//            "scope":  ["read", "write", "control"],
//            "device": [
//                "device_name": "heliotrope",
//                "device_os": "Android",
//                "app_name": "ApplicationName",
//                "type": "native",
//                "app_id": "app.id" ,
//                "id": username ,
//            ]
//        ]
//
//        var request = URLRequest(url: URL(string:"https://\(self.address):1926/6/pair/request")!)
//        request.httpMethod = "POST"
//        request.httpBody = try? JSONEncoder().encode(data)
//
//        NSLog("Starting pairing request")
//        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
//            // Got an error, no need to go further
//            if let error = error {
//                NSLog("\(error)")
//                return
//            }
//            if let data = data, let json = try? JSONDecoder().decode([String: Any].self, from: data) {
//                let authTimestamp =  json["timestamp"]
//                //config['auth_key'] = response["auth_key"]
//                //let pin = ("Enter onscreen passcode : ")
//            }
//        }
//        task.resume()
//        config['application_id'] = "app.id"
//        config['device_id'] = createDeviceId()
//        data = { 'scope'  :  [ "read", "write", "control"] }
//        data['device']  = getDeviceSpecJson(config)
//        print("Starting pairing request")
//        r = requests.post("https://" + config['address'] + ":1926/6/pair/request", json=data, verify=False)
//        response = r.json()
//        auth_Timestamp = response["timestamp"]
//        config['auth_key'] = response["auth_key"]
//        auth_Timeout = response["timeout"]
//
//        pin = input("Enter onscreen passcode : ")
//
//        auth = { "auth_AppId"  : "1" }
//        auth ['pin'] = str(pin)
//        auth['auth_timestamp'] = auth_Timestamp
//        auth['auth_signature'] = create_signature(b64decode(secret_key), str(auth_Timestamp) + str(pin))
//
//        grant_request = {}
//        grant_request['auth'] = auth
//        grant_request['device']  = getDeviceSpecJson(config)
//
//        print("Attempting to pair")
//        r = requests.post("https://" + config['address'] +":1926/6/pair/grant", json=grant_request, verify=False,auth=HTTPDigestAuth(config['device_id'], config['auth_key']))
//        print(r.json())
//        print("Username for subsequent calls is : " + config['device_id'])
//        print("Password for subsequent calls is : " + config['auth_key'])
//    }


    var volume: Int = 0
    var session: URLSession!

    /// URLSessionDelegate
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.host == address else { return }
        
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        default:
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
        "volume": "/6/audio/volume",
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
            guard let authHeader = PCHTTPDigest.auth(infos: wwwAuthInfosDict, ha1: self.ha1!) else { return }

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
