//
//  PCCredentialsHTTPDigest.swift
//  Philips Controller
//
//  Created by Michael Mouchous on 30/09/2017.
//  Copyright © 2017 Michael Mouchous. All rights reserved.
//

import UIKit
import Crypto

class PCHTTPDigest: NSObject {
    static var countNonces: [String: Int] = [:]

    static func auth(infos: [String:String], ha1: String) -> String? {
        guard let userid = infos["username"],
            let realm = infos["realm"],
            let uri = infos["uri"],
            let method = infos["method"],
            let nonce = infos["nonce"],
            let qop = infos["qop"] else {
                return nil
        }

        let nc: String
        if let count = countNonces[nonce] {
            nc = String(format: "%08x",count)
        } else {
            countNonces[nonce] = 1
            nc = "00000001"
        }

        let cnonce = String(format: "%08x",arc4random()) + String(format: "%08x", arc4random())

        let s2 = [method, uri].joined(separator: ":")
        guard let ha2 = s2.md5 else { return nil }
        let s3 = [ha1, nonce, nc, cnonce, qop, ha2].joined(separator: ":")
        guard let ha3 = s3.md5 else { return nil }

        let result = "Digest " + [
            "username=\"\(userid)\"",
            "realm=\"\(realm)\"",
            "nonce=\"\(nonce)\"",
            "uri=\"\(uri)\"",
            "algorithm=MD5",
            "response=\"\(ha3)\"",
            "qop=auth",
            "nc=\(nc)",
            "cnonce=\"\(cnonce)\""].joined(separator: ", ")
        return result
    }
}
