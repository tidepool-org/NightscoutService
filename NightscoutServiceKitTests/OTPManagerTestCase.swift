//
//  OTPManagerTestCase.swift
//  NightscoutServiceKitTests
//
//  Created by Bill Gestrich on 8/13/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import NightscoutServiceKit
@testable import OneTimePassword

class OTPManagerTestCase: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRecentPasswordsFixedTime() throws {
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate})
        XCTAssertEqual(manager.getLastPasswordsAscending(count: 2), sequenceData.otpAscendingPasswords)
    }
    
    func testRecentPasswordsIncludesCurrent() throws {
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {sequenceData.endDate})
        XCTAssertEqual(sequenceData.otpAscendingPasswords.last!, manager.currentPassword()!)
    }
    
    func testValidation() throws {
        
        let sequenceData = getTestSequence()
        let mockStore = MockSecretStore(testSequence: sequenceData)
        let mockDateSource = MockDateSource()
        let manager = OTPManager(secretStore: mockStore, nowDateSource: {mockDateSource.currentDate})
        
        mockDateSource.currentDate = sequenceData.otpAscendingDates()[0] //Get first date
        XCTAssertEqual(manager.currentPassword(), sequenceData.otpAscendingPasswords[0])
        XCTAssertTrue(manager.validateOTP(otpToValidate: sequenceData.otpAscendingPasswords[0]))
        XCTAssertFalse(manager.validateOTP(otpToValidate: sequenceData.otpAscendingPasswords[0])) //Reject reuse
        
        //Advance clock to next interval and try next code
        mockDateSource.currentDate = mockDateSource.currentDate.addingTimeInterval(manager.tokenPeriod)
        XCTAssertEqual(manager.currentPassword(), sequenceData.otpAscendingPasswords[1])
        XCTAssertTrue(manager.validateOTP(otpToValidate: sequenceData.otpAscendingPasswords[1]))
        XCTAssertFalse(manager.validateOTP(otpToValidate: sequenceData.otpAscendingPasswords[1])) //Reject reuse
    }
    
    func getTestSequence() -> OTPTestSequence {
        /*
         To get sequence of OTP codes from an independent source for these tests:
         
         1. Go to https://cryptotools.net/otp
         2. Copy the test secretKey below to website
         3. Note the Epoch time from site
         4. Note the next 2 consecutive codes
         5. Update the endDate below with (epoch time + 30)
         6. Update codes below
         */
        return OTPTestSequence(secretKey: "2IOF4MG5QSAKMIYD6QJKOBZFH2QV2CYG", tokenName: "Test Key", endDate: Date(timeIntervalSince1970: 1655326953), otpAscendingPasswords: ["928595", "278849"])
    }
}

struct OTPTestSequence {
    let secretKey: String
    let tokenName: String
    let endDate: Date
    let otpAscendingPasswords: [String]
    
    func otpAscendingDates() -> [Date] {
        var datesDescending = [Date]()
        for (index, _) in otpAscendingPasswords.reversed().enumerated() {
            //Array reversed so index 0 is newest OTP.
            let date = endDate.addingTimeInterval( TimeInterval(index) * -OTPManager.defaultTokenPeriod)
            datesDescending.append(date)
        }
        //Reverse again to put back in ascending order
        return datesDescending.reversed()
    }
}

class MockSecretStore: OTPSecretStore {

    var secretKey: String?
    var keyName: String?
    var recentlyAcceptedPasswords = [String]()
    
    init(secretKey: String?, keyCreated: String?){
        self.secretKey = secretKey
        self.keyName = keyCreated
    }
    
    convenience init(testSequence: OTPTestSequence){
        self.init(secretKey: testSequence.secretKey, keyCreated: testSequence.tokenName)
    }
    
    func setTokenSecretKey(_ key: String?) throws {
        secretKey = key
    }
    
    func tokenSecretKey() -> String? {
        return secretKey
    }
    
    func tokenSecretKeyName() -> String? {
        return keyName
    }
    
    func setTokenSecretKeyName(_ name: String?) throws {
        keyName = name
    }
    
    func recentAcceptedPasswords() -> [String] {
        return recentlyAcceptedPasswords
    }
    
    func setRecentAcceptedPasswords(_ passwords: [String]) throws {
        self.recentlyAcceptedPasswords = passwords
    }
}

class MockDateSource {
    
    init(currentDate: Date = Date()){
        self.currentDate = currentDate
    }
    
    var currentDate: Date
}
