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
        
        let group = DispatchGroup()
        count = serverList.servers.count
        
        for server in serverList.servers {
            if let ipAddress = server.ipAddresses.first {
                guard !ipAddress.isEmpty else {
                    continue
                }
                
                group.enter()
                let once = try? SwiftyPing(host: ipAddress, configuration: PingConfiguration(interval: 0.5, with: 5), queue: DispatchQueue.global())
                once?.observer = { response in
                    
                    if let server = self.serverList.getServer(byIpAddress: response.ipAddress ?? "") {
                        if response.ipHeader != nil {
                            if let duration = response.duration {
                                server.pingMs = Int(duration * 1000)
                                
                                let isFastest = Application.shared.settings.selectedServer.fastest
                                
                                if server == Application.shared.settings.selectedServer {
                                    Application.shared.settings.selectedServer = server
                                    Application.shared.settings.selectedServer.fastest = isFastest
                                }
                                
                                if server == Application.shared.settings.selectedExitServer {
                                    Application.shared.settings.selectedExitServer = server
                                }
                            }
                            
                            once?.haltPinging()
                        }
                    }
                    
                    self.count -= 1
                    
                    if self.count <= 0 {
                        NotificationCenter.default.post(name: Notification.Name.PingDidComplete, object: nil)
                        log(info: "Pinger service finished")
                    }
                    
                    group.leave()
                }
                once?.targetCount = 1
                try? once?.startPinging()
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
