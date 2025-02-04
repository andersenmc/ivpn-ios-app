//
//  ApiService+Ext.swift
//  IVPN iOS app
//  https://github.com/ivpn/ios-app
//
//  Created by Juraj Hilje on 2019-08-08.
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

import UIKit

extension ApiService {
    
    // MARK: - Methods -
    
    func getServersList(storeInCache: Bool, completion: @escaping (ServersUpdateResult) -> Void) {
        let request = APIRequest(method: .get, path: Config.apiServersFile)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        log(.info, message: "Load servers")
        
        APIClient().perform(request) { result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                guard Config.useDebugServers == false else { return }
                
                if let data = response.body {
                    let serversList = VPNServerList(withJSONData: data, storeInCache: storeInCache)
                    
                    if serversList.servers.count > 0 {
                        log(.info, message: "Load servers success")
                        completion(.success(serversList))
                        return
                    }
                }
                
                log(.info, message: "Load servers error (probably parsing error)")
                completion(.error)
            case .failure:
                log(.info, message: "Load servers error")
                completion(.error)
            }
        }
    }
    
}
