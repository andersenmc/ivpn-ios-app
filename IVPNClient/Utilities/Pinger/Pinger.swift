//
//  Pinger.swift
//  IVPN iOS app
//  https://github.com/ivpn/ios-app
//
//  Created by Juraj Hilje on 2019-11-26.
//  Copyright (c) 2020 Privatus Limited.
//
//  This file is part of the IVPN iOS app.
//
//  The IVPN iOS app is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The IVPN iOS app is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the IVPN iOS app. If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

class Pinger {

    // MARK: - Properties -
    
    static let shared = Pinger()
    var serverList: VPNServerList
    
    private var count = 0
    
    // MARK: - Initialize -
    
    private init() {
        self.serverList = Application.shared.serverList
    }
    
    // MARK: - Methods -
    
    func ping() {
        guard evaluatePing() else {
            return
        }
        
        UserDefaults.shared.set(Date().timeIntervalSince1970, forKey: "LastPingTimestamp")
        
        for server in serverList.servers {
            if let ipAddress = server.ipAddresses.first {
                guard !ipAddress.isEmpty else {
                    continue
                }
                
                // TODO: Set up latency check for ipAddress
            }
        }

        log(info: "Pinger service started")
    }
    
    // MARK: - Private methods -
    
    private func evaluatePing() -> Bool {
        let lastPingTimestamp = UserDefaults.shared.integer(forKey: "LastPingTimestamp")
        let isPingTimeoutPassed = Date().timeIntervalSince1970 > Double(lastPingTimestamp) + Config.minPingCheckInterval
        
        return Application.shared.connectionManager.status.isDisconnected() && isPingTimeoutPassed
    }
    
}
