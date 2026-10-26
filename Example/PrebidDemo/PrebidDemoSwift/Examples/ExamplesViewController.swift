/*   Copyright 2019-2022 Prebid.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit

fileprivate let cellID = "exampleCell"

class ExamplesViewController: UIViewController {
    
    @IBOutlet weak var integrationKindPicker: UIButton!
    @IBOutlet weak var adFormatPicker: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let testCases = IntegrationCaseManager.allCases
    private var displayedCases = [IntegrationCase]()
    
    private var filterText = ""
    private var currentIntegrationKind: IntegrationKind?
    private var currentAdFormat: AdFormat?
    private var serverItem: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
        
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            title = appName
        }
        
        displayedCases = testCases

        setupPickers()
        setupServerMenu()
    }

    private func setupServerMenu() {
        let serverItem = UIBarButtonItem(image: UIImage(systemName: "server.rack"), menu: serverMenu())
        self.serverItem = serverItem
        serverItem.accessibilityIdentifier = "prebidServerMenu"
        serverItem.accessibilityLabel = "Prebid server"
        navigationItem.rightBarButtonItems = (navigationItem.rightBarButtonItems ?? []) + [serverItem]
        updateServerPrompt()
    }

    private func serverMenu() -> UIMenu {
        let actions = PrebidServer.allCases.map { server in
            UIAction(title: server.title, state: server == PrebidServer.selected ? .on : .off) { [weak self] _ in
                self?.select(server)
            }
        }
        return UIMenu(title: "Prebid server", children: actions)
    }

    private func select(_ server: PrebidServer) {
        guard server.hostURL != nil else {
            askTeadsHost()
            return
        }
        PrebidServer.selected = server
        server.apply()
        serverItem?.menu = serverMenu()
        updateServerPrompt()
    }

    /// The Teads host is not in the repo, so it is asked once and saved.
    private func askTeadsHost() {
        let alert = UIAlertController(
            title: PrebidServer.teads.title,
            message: "Enter the auction URL. It is saved on this device.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "http://<host>/openrtb2/auction"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let host = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !host.isEmpty else { return }
            UserDefaults.standard.set(host, forKey: PrebidServer.teadsHostKey)
            self?.select(.teads)
        })
        present(alert, animated: true)
    }

    private func updateServerPrompt() {
        let title = PrebidServer.selected.title
        if #available(iOS 26.0, *) {
            navigationItem.subtitle = title
        } else {
            navigationItem.prompt = title
        }
    }
    
    private func setupPickers() {
        let allIntegrationKindsAction = UIAction(title: "All") { [weak self] _ in
            self?.currentIntegrationKind = nil
            self?.filterTestCases()
        }
        
        let integrationKindActions = IntegrationKind.allCases.map { integration in
            UIAction(title: integration.description) { [weak self] _ in
                self?.currentIntegrationKind = integration
                self?.filterTestCases()
            }
        }
        if CommandLine.arguments.contains("-integrationKindAll") {
            integrationKindPicker.setupPullDown(with: [allIntegrationKindsAction] + integrationKindActions)
        } else {
            integrationKindPicker.setupPullDown(with: integrationKindActions + [allIntegrationKindsAction])
            currentIntegrationKind = IntegrationKind.gamOriginal
            filterTestCases()
        }
        let allAdFormatsAction = UIAction(title: "All") { [weak self] _ in
            self?.currentAdFormat = nil
            self?.filterTestCases()
        }
        
        let adFormatActions = AdFormat.allCases.map { adFormat in
            UIAction(title: adFormat.description) { [weak self] _ in
                self?.currentAdFormat = adFormat
                self?.filterTestCases()
            }
        }
        
        adFormatPicker.setupPullDown(with: [allAdFormatsAction] + adFormatActions)
        
    }
    
    private func filterTestCases() {
        displayedCases = testCases
            .filter { currentIntegrationKind == nil ? true : $0.integrationKind == currentIntegrationKind }
            .filter { currentAdFormat == nil ? true : $0.adFormat == currentAdFormat }
            .filter { filterText.isEmpty || $0.title.range(of: filterText, options: .caseInsensitive) != nil }
        
        tableView.reloadData()
    }
    
    @IBAction func settingsButtonTapped(_ sender: Any) {
        if let settingsViewController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController {
            settingsViewController.title = "Settings"
            navigationController?.pushViewController(settingsViewController, animated: true)
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension ExamplesViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        
        var content = cell.defaultContentConfiguration()
        content.text = displayedCases[indexPath.row].title
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let testCase = displayedCases[indexPath.row]
        
        let viewController = testCase.configurationClosure()
        viewController.view.backgroundColor = .white
        viewController.title = testCase.title
        
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension ExamplesViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterText = searchBar.text ?? ""
        filterTestCases()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        filterText = searchBar.text ?? ""
        filterTestCases()
        searchBar.endEditing(true)
    }
}
