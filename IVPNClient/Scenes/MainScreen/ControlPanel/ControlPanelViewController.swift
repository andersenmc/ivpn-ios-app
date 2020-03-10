//
//  ControlPanelViewController.swift
//  IVPNClient
//
//  Created by Juraj Hilje on 20/02/2020.
//  Copyright © 2020 IVPN. All rights reserved.
//

import UIKit
import NetworkExtension
import JGProgressHUD

class ControlPanelViewController: UITableViewController {
    
    // MARK: - @IBOutlets -
    
    @IBOutlet weak var protectionStatusLabel: UILabel!
    @IBOutlet weak var connectSwitch: UISwitch!
    @IBOutlet weak var enableMultiHopButton: UIButton!
    @IBOutlet weak var disableMultiHopButton: UIButton!
    @IBOutlet weak var exitServerConnectionLabel: UILabel!
    @IBOutlet weak var exitServerNameLabel: UILabel!
    @IBOutlet weak var exitServerFlagImage: UIImageView!
    @IBOutlet weak var entryServerConnectionLabel: UILabel!
    @IBOutlet weak var entryServerNameLabel: UILabel!
    @IBOutlet weak var entryServerFlagImage: UIImageView!
    @IBOutlet weak var antiTrackerSwitch: UISwitch!
    @IBOutlet weak var networkView: NetworkViewTableCell!
    @IBOutlet weak var protocolLabel: UILabel!
    @IBOutlet weak var ipAddressLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var providerLabel: UILabel!
    
    // MARK: - Properties -
    
    let hud = JGProgressHUD(style: .dark)
    var needsToReconnect = false
    
    var sessionManager: SessionManager {
        let sessionManager = SessionManager()
        sessionManager.delegate = self
        return sessionManager
    }
    
    var connectionInfoViewModel: ProofsViewModel! {
        didSet {
            ipAddressLabel.text = connectionInfoViewModel.ipAddress
            locationLabel.text = "\(connectionInfoViewModel.city), \(connectionInfoViewModel.countryCode)"
            providerLabel.text = connectionInfoViewModel.provider
        }
    }
    
    private var vpnStatusViewModel = VPNStatusViewModel(status: .invalid)
    private var lastStatusUpdateDate: Date?
    private var lastAccountStatus: NEVPNStatus = .invalid
    
    private var keyManager: AppKeyManager {
        let keyManager = AppKeyManager()
        keyManager.delegate = self
        return keyManager
    }
    
    private var isMultiHop: Bool = UserDefaults.shared.isMultiHop {
        didSet {
            UserDefaults.shared.set(isMultiHop, forKey: UserDefaults.Key.isMultiHop)
            
            if isMultiHop {
                enableMultiHopButton.setTitleColor(UIColor.init(named: Theme.Key.ivpnLabelPrimary), for: .normal)
                disableMultiHopButton.setTitleColor(UIColor.init(named: Theme.Key.ivpnLabel5), for: .normal)
            } else {
                enableMultiHopButton.setTitleColor(UIColor.init(named: Theme.Key.ivpnLabel5), for: .normal)
                disableMultiHopButton.setTitleColor(UIColor.init(named: Theme.Key.ivpnLabelPrimary), for: .normal)
            }
            
            NotificationCenter.default.post(name: Notification.Name.UpdateFloatingPanelLayout, object: nil)
        }
    }
    
    // MARK: - @IBActions -
    
    @IBAction func toggleConnect(_ sender: UISwitch) {
        connectionExecute()
    }
    
    @IBAction func toggleMultiHop(_ sender: UIButton) {
        guard evaluateIsLoggedIn() else {
            return
        }
        
        guard evaluateIsServiceActive() else {
            return
        }
        
        guard evaluateMultiHopCapability(sender) else {
            return
        }
        
        guard Application.shared.connectionManager.status.isDisconnected() else {
            showConnectedAlert(message: "To change Multi-Hop settings, please first disconnect", sender: sender)
            return
        }
        
        isMultiHop = sender == enableMultiHopButton
        reloadView()
    }
    
    @IBAction func toggleAntiTracker(_ sender: UISwitch) {
        if sender.isOn && Application.shared.settings.connectionProtocol.tunnelType() == .ipsec {
            showAlert(title: "IKEv2 not supported", message: "AntiTracker is supported only for OpenVPN and WireGuard protocols.") { _ in
                sender.setOn(false, animated: true)
            }
            return
        }
        
        guard Application.shared.connectionManager.status.isDisconnected() else {
            showConnectedAlert(message: "To change AntiTracker settings, please first disconnect", sender: sender)
            sender.setOn(sender.isOn, animated: true)
            return
        }
        
        UserDefaults.shared.set(sender.isOn, forKey: UserDefaults.Key.isAntiTracker)
    }
    
    // MARK: - View lifecycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        addObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Application.shared.connectionManager.getStatus { _, status in
            self.updateStatus(vpnStatus: status)
            
            Application.shared.connectionManager.onStatusChanged { status in
                self.updateStatus(vpnStatus: status)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(pingDidComplete), name: Notification.Name.PingDidComplete, object: nil)
        
        refreshServiceStatus()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        Application.shared.connectionManager.removeStatusChangeUpdates()

        NotificationCenter.default.removeObserver(self, name: Notification.Name.PingDidComplete, object: nil)
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Methods -
    
    func reloadView() {
        tableView.reloadData()
        isMultiHop = UserDefaults.shared.isMultiHop
        updateServerNames()
        updateServerLabels()
        updateAntiTracker()
        updateProtocol()
    }
    
    @objc func connectionExecute() {
        Application.shared.connectionManager.getStatus { _, status in
            if status == .disconnected || status == .invalid {
                self.connect(status: status)
            } else {
                self.disconnect()
            }
        }
    }
    
    @objc func updateControlPanel() {
        reloadView()
    }
    
    @objc func serverSelected() {
        updateServerNames()
    }
    
    @objc func protocolSelected() {
        updateProtocol()
        tableView.reloadData()
        isMultiHop = UserDefaults.shared.isMultiHop
    }
    
    @objc func pingDidComplete() {
        updateServerNames()
        
        if needsToReconnect {
            needsToReconnect = false
            Application.shared.connectionManager.connect()
        }
    }
    
    func connect(status: NEVPNStatus) {
        guard evaluateIsNetworkReachable() else {
            connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
            return
        }
        
        guard evaluateIsLoggedIn() else {
            NotificationCenter.default.addObserver(self, selector: #selector(connectionExecute), name: Notification.Name.ServiceAuthorized, object: nil)
            connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
            return
        }
        
        guard evaluateHasUserConsent() else {
            NotificationCenter.default.addObserver(self, selector: #selector(connectionExecute), name: Notification.Name.TermsOfServiceAgreed, object: nil)
            connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
            return
        }
        
        guard evaluateIsServiceActive() else {
            NotificationCenter.default.addObserver(self, selector: #selector(connectionExecute), name: Notification.Name.SubscriptionActivated, object: nil)
            connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
            return
        }
        
        if AppKeyManager.isKeyPairRequired && ExtensionKeyManager.needToRegenerate() {
            keyManager.setNewKey()
            connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
            return
        }
        
        let manager = Application.shared.connectionManager
        
        if UserDefaults.shared.networkProtectionEnabled && !manager.canConnect(status: status) {
            showActionSheet(title: "IVPN cannot connect to trusted network. Do you want to change Network Protection settings for the current network and connect?", actions: ["Connect"], sourceView: self.connectSwitch) { index in
                switch index {
                case 0:
                    self.networkView.resetTrustToDefault()
                    manager.resetRulesAndConnect()
                default:
                    break
                }
            }
        } else {
            manager.resetRulesAndConnect()
        }
        
        registerUserActivity(type: UserActivityType.Connect, title: UserActivityTitle.Connect)
    }
    
    @objc func disconnect() {
        let manager = Application.shared.connectionManager
        
        if UserDefaults.shared.networkProtectionEnabled {
            manager.resetRulesAndDisconnectShortcut()
        } else {
            manager.resetRulesAndDisconnect()
        }
        
        registerUserActivity(type: UserActivityType.Disconnect, title: UserActivityTitle.Disconnect)
        
        DispatchQueue.delay(1) {
            Pinger.shared.ping()
        }
    }
    
    @objc func authenticationDismissed() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ServiceAuthorized, object: nil)
    }
    
    @objc func subscriptionDismissed() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SubscriptionActivated, object: nil)
    }
    
    @objc func agreedToTermsOfService() {
        connectionExecute()
    }
    
    @objc func newSession() {
        sessionManager.createSession()
    }
    
    @objc func forceNewSession() {
        sessionManager.createSession(force: true)
    }
    
    func showExpiredSubscriptionError() {
        showActionAlert(
            title: "No active subscription",
            message: "To continue using IVPN, you must activate your subscription.",
            action: "Activate",
            cancel: "Cancel",
            actionHandler: { _ in
                self.present(NavigationManager.getSubscriptionViewController(), animated: true, completion: nil)
            }
        )
    }
    
    func refreshServiceStatus() {
        if let lastUpdateDate = lastStatusUpdateDate {
            let now = Date()
            if now.timeIntervalSince(lastUpdateDate) < Config.serviceStatusRefreshMaxIntervalSeconds { return }
        }
        
        let status = Application.shared.connectionManager.status
        if status != .connected && status != .connecting {
            self.lastStatusUpdateDate = Date()
            self.sessionManager.getSessionStatus()
        }
    }
    
    func showConnectedAlert(message: String, sender: Any?, completion: (() -> Void)? = nil) {
        if let sourceView = sender as? UIView {
            showActionSheet(title: message, actions: ["Disconnect"], sourceView: sourceView) { index in
                if let completion = completion {
                    completion()
                }
                
                switch index {
                case 0:
                    let status = Application.shared.connectionManager.status
                    guard Application.shared.connectionManager.canDisconnect(status: status) else {
                        self.showAlert(title: "Cannot disconnect", message: "IVPN cannot disconnect from the current network while it is marked \"Untrusted\"")
                        return
                    }
                    NotificationCenter.default.post(name: Notification.Name.Disconnect, object: nil)
                    self.hud.indicatorView = JGProgressHUDIndeterminateIndicatorView()
                    self.hud.detailTextLabel.text = "Disconnecting"
                    self.hud.show(in: (self.navigationController?.view)!)
                    self.hud.dismiss(afterDelay: 5)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Observers -
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateControlPanel), name: Notification.Name.UpdateControlPanel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(serverSelected), name: Notification.Name.ServerSelected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnect), name: Notification.Name.Disconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authenticationDismissed), name: Notification.Name.AuthenticationDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionDismissed), name: Notification.Name.SubscriptionDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(protocolSelected), name: Notification.Name.ProtocolSelected, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UpdateControlPanel, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ServerSelected, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.Disconnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.AuthenticationDismissed, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SubscriptionDismissed, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ServiceAuthorized, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SubscriptionActivated, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NewSession, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ForceNewSession, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ProtocolSelected, object: nil)
    }
    
    // MARK: - Private methods -
    
    private func initView() {
        tableView.backgroundColor = UIColor.init(named: Theme.Key.ivpnBackgroundPrimary)
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        isMultiHop = UserDefaults.shared.isMultiHop
        updateServerNames()
        updateServerLabels()
        updateAntiTracker()
        updateProtocol()
    }
    
    private func updateStatus(vpnStatus: NEVPNStatus) {
        vpnStatusViewModel.status = vpnStatus
        protectionStatusLabel.text = vpnStatusViewModel.protectionStatusText
        connectSwitch.setOn(vpnStatusViewModel.connectToggleIsOn, animated: true)
        updateServerLabels()
        
        if vpnStatus == .disconnected {
            hud.dismiss()
        }
        
        if vpnStatus != lastAccountStatus && (vpnStatus == .invalid || vpnStatus == .disconnected) {
            refreshServiceStatus()
        }
        
        if vpnStatus != lastAccountStatus && (vpnStatus == .connected || vpnStatus == .disconnected) {
            if let topViewController = UIApplication.topViewController() as? MainViewControllerV2 {
                topViewController.updateGeoLocation()
            }
        }
        
        lastAccountStatus = vpnStatus
    }
    
    private func updateServerLabels() {
        entryServerConnectionLabel.text = vpnStatusViewModel.connectToServerText
        exitServerConnectionLabel.text = "Exit Server"
    }
    
    private func updateServerNames() {
        updateServerName(server: Application.shared.settings.selectedServer, label: entryServerNameLabel, flag: entryServerFlagImage)
        updateServerName(server: Application.shared.settings.selectedExitServer, label: exitServerNameLabel, flag: exitServerFlagImage)
    }
    
    private func updateServerName(server: VPNServer, label: UILabel, flag: UIImageView) {
        let serverViewModel = VPNServerViewModel(server: server)
        label.icon(text: serverViewModel.formattedServerNameForMainScreen, imageName: serverViewModel.imageNameForPingTime)
        flag.image = serverViewModel.imageForCountryCodeForMainScreen
    }
    
    private func updateAntiTracker() {
        antiTrackerSwitch.isOn = UserDefaults.shared.isAntiTracker
    }
    
    private func updateProtocol() {
        let selectedProtocol = Application.shared.connectionManager.settings.connectionProtocol
        protocolLabel.text = selectedProtocol.format()
    }
    
}
