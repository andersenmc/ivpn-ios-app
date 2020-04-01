//
//  MainView.swift
//  IVPNClient
//
//  Created by Juraj Hilje on 01/04/2020.
//  Copyright © 2020 IVPN. All rights reserved.
//

import UIKit
import NetworkExtension

class MainView: UIView {
    
    // MARK: - @IBOutlets -
    
    @IBOutlet weak var infoAlertView: InfoAlertView!
    @IBOutlet weak var mapScrollView: MapScrollView!
    
    // MARK: - Properties -
    
    private var infoAlertViewModel = InfoAlertViewModel()
    private let markerContainerView = MapMarkerContainerView()
    private let markerView = MapMarkerView()
    
    // MARK: - View lifecycle -
    
    override func awakeFromNib() {
//        initMarker()
//        initSettingsAction()
//        initInfoAlert()
//        updateInfoAlert()
    }
    
    // MARK: - Methods -
    
    func setupView() {
        
    }
    
    func setupConstraints() {
        mapScrollView.setupConstraints()
        markerContainerView.setupConstraints()
    }
    
    func updateStatus(vpnStatus: NEVPNStatus) {
        markerView.status = vpnStatus
    }
    
    // MARK: - Private methods -
    
    private func initMarker() {
        markerContainerView.addSubview(markerView)
        addSubview(markerContainerView)
    }
    
    private func initSettingsAction() {
        let settingsButton = UIButton()
        addSubview(settingsButton)
        settingsButton.bb.size(width: 42, height: 42).top(55).right(-30)
        settingsButton.setupIcon(imageName: "icon-settings")
        settingsButton.addTarget(self, action: #selector(MainViewControllerV2.openSettings), for: .touchUpInside)
        
        let accountButton = UIButton()
        addSubview(accountButton)
        if UIDevice.current.userInterfaceIdiom == .pad {
            accountButton.bb.size(width: 42, height: 42).top(55).right(-100)
        } else {
            accountButton.bb.size(width: 42, height: 42).top(55).left(30)
        }
        accountButton.setupIcon(imageName: "icon-user")
        accountButton.addTarget(self, action: #selector(MainViewControllerV2.openAccountInfo), for: .touchUpInside)
    }
    
}
