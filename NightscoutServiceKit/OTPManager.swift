//
//  OTPManager.swift
//  Loop
//
//  Created by Jose Paredes on 3/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import OneTimePassword
import Base32

private let OTPSecretKeyService = "OTPSecretKeyService"
private let OTPSecretKeyCreatedService = "OTPSecretKeyCreatedService"
private let OTPRecentAcceptedPasswordsService = "OTPRecentAcceptedPasswordsService"

public protocol OTPSecretStore {
    
    func tokenSecretKey() -> String?
    func setTokenSecretKey(_ key: String?) throws
    
    func tokenSecretKeyName() -> String?
    func setTokenSecretKeyName(_ name: String?) throws
    
    func recentAcceptedPasswords() -> [String]
    func setRecentAcceptedPasswords(_ passwords: [String]) throws
}

extension KeychainManager: OTPSecretStore {
    
    public func tokenSecretKey() -> String? {
        return try? getGenericPasswordForService(OTPSecretKeyService)
    }
    
    public func setTokenSecretKey(_ key: String?) throws {
        try replaceGenericPassword(key, forService: OTPSecretKeyService)
    }
    
    public func tokenSecretKeyName() -> String? {
        return try? getGenericPasswordForService(OTPSecretKeyCreatedService)
    }
    
    public func setTokenSecretKeyName(_ name: String?) throws {
        try replaceGenericPassword(name, forService: OTPSecretKeyCreatedService)
    }
    
    public func recentAcceptedPasswords() -> [String] {
        guard let recentString = try? getGenericPasswordForService(OTPRecentAcceptedPasswordsService) else {
            return []
        }

        return convertRecentAcceptedPasswordsFromString(recentString)
    }
    
    public func setRecentAcceptedPasswords(_ passwords: [String]) throws {
        try replaceGenericPassword(convertRecentAcceptedPasswordsToString(passwords), forService: OTPRecentAcceptedPasswordsService)
    }
    
    func convertRecentAcceptedPasswordsToString(_ recentAcceptedPasswords: [String]) -> String {
        return recentAcceptedPasswords.joined(separator: ",")
    }
    
    func convertRecentAcceptedPasswordsFromString(_ passwordsString: String) -> [String] {
        return passwordsString.split(separator: ",").map({String($0)})
    }
}

public class OTPManager {
    
    private var secretStore: OTPSecretStore
    private var nowDateSource: () -> Date
    let algorithm: Generator.Algorithm = .sha1
    let issuerName = "Loop"
    var tokenPeriod: TimeInterval
    var passwordDigitCount = 6
    public static var defaultTokenPeriod: TimeInterval = 30
    
    public init(secretStore: OTPSecretStore = KeychainManager(), nowDateSource: @escaping () -> Date = {Date()}, tokenPeriod: TimeInterval = OTPManager.defaultTokenPeriod) {
        self.secretStore = secretStore
        self.nowDateSource = nowDateSource
        self.tokenPeriod = tokenPeriod
        if secretStore.tokenSecretKey() == nil || secretStore.tokenSecretKeyName() == nil {
            resetSecretKey()
        }
    }
    
    public func validateOTP(otpToValidate: String) -> Bool {
        let maxOTPsToAccept = 2
        
        guard otpToValidate.count == passwordDigitCount && getLastPasswordsAscending(count: maxOTPsToAccept).contains(otpToValidate) else {
            return false //Doesn't match
        }
        
        let recentPasswords = secretStore.recentAcceptedPasswords()
        guard !recentPasswords.contains(otpToValidate) else {
            //Already used
            return false
        }
        
        //Only storing last 2 accepted passwords
        var updatedRecentPasswords = recentPasswords.first != nil ? [recentPasswords.first!] : []
        updatedRecentPasswords.append(otpToValidate)
        do {
            try secretStore.setRecentAcceptedPasswords(updatedRecentPasswords)
        } catch {
            print("Error storing \(error)")
        }
        
        return true

    }
    
    public func resetSecretKey() {
        let secretKey = createRandomSecretKey()
        let secretKeyName = createSecretKeyName()
        
        do {
            try secretStore.setTokenSecretKey(secretKey)
            try secretStore.setTokenSecretKeyName(secretKeyName)
        } catch {
            print("Could not store OTP to keychain \(error)")
        }
    }
    
    func createRandomSecretKey() -> String {
        let Base32Dictionary = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        return String((0..<32).map{_ in Base32Dictionary.randomElement()!})
    }
    
    func createSecretKeyName() -> String {
        return String(format: "%.0f", round(nowDateSource().timeIntervalSince1970*1000))
    }
    
    func otpToken() -> Token? {
        
        guard let secretKey = secretStore.tokenSecretKey(), let secretKeyName = secretStore.tokenSecretKeyName() else {
            return nil
        }
        
        guard let secretKeyData = MF_Base32Codec.data(fromBase32String: secretKey) else {
            print("Error: Could not create data from secret key")
            return nil
        }
        
        let generator = Generator(factor: .timer(period: TimeInterval(self.tokenPeriod)), secret: secretKeyData, algorithm: algorithm, digits: passwordDigitCount)!
        return Token(name: secretKeyName, issuer: issuerName, generator: generator)
    }
    
    public func getLastPasswordsAscending(count: Int) -> [String] {
        
        guard let token = self.otpToken() else {
            return []
        }
        
        let currentTimeInterval = nowDateSource().timeIntervalSince1970
        let earliestTimeInterval = currentTimeInterval - (TimeInterval(count - 1 ) * tokenPeriod)
        
        var toRet = [String]()
        for timeInterval in stride(from: earliestTimeInterval, through: currentTimeInterval, by: tokenPeriod) {
            guard let otp = try? token.generator.password(at: Date(timeIntervalSince1970: timeInterval)) else {
                continue
            }
            toRet.append(otp)
        }
        return toRet
    }
    
    public func currentPassword() -> String? {
        //We don't use self.otpToken()?.currentPassword as the date can't be injected for testing.
        return self.getLastPasswordsAscending(count: 1).last
    }
    
    public func tokenName() -> String? {
        return self.otpToken()?.name
    }
    
    public var otpURL: String? {
        
        guard let secretKey = secretStore.tokenSecretKey(), let tokenName = secretStore.tokenSecretKeyName() else {
            return nil
        }
        
        let queryItems = [
            URLQueryItem(name: "algorithm", value: algorithm.otpURLStringComponent()),
            URLQueryItem(name: "digits", value: "\(passwordDigitCount)"),
            URLQueryItem(name: "issuer", value: issuerName),
            URLQueryItem(name: "period", value: "\(Int(tokenPeriod))"),
            URLQueryItem(name: "secret", value: secretKey),
        ]
        
        let components = URLComponents(scheme: "otpauth", host: "totp", path: "/" + tokenName, queryItems: queryItems)
        return components.url?.absoluteString
    }
    
}


extension Generator.Algorithm {
    
    func otpURLStringComponent() -> String {
        switch self {
        case .sha1:
            return "SHA1"
        case .sha256:
            return "SHA256"
        case .sha512:
            return "SHA512"
        }
    }
}

extension URLComponents {
    init(scheme: String,
         host: String,
         path: String,
         queryItems: [URLQueryItem]) {
        self.init()
        self.scheme = scheme
        self.host = host
        self.path = path
        self.queryItems = queryItems
    }
}
