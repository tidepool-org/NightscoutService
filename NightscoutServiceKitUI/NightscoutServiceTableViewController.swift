//
//  NightscoutServiceTableViewController.swift
//  NightscoutServiceKitUI
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import NightscoutServiceKit


final class NightscoutServiceTableViewController: ServiceTableViewController, UITextFieldDelegate {

    private let nightscoutService: NightscoutService

    init(nightscoutService: NightscoutService, for operation: Operation) {
        self.nightscoutService = nightscoutService

        super.init(service: nightscoutService, for: operation)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(AuthenticationTableViewCell.nib(), forCellReuseIdentifier: AuthenticationTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case credentials
        case deleteService
    }

    private enum Credentials: Int, CaseIterable {
        case siteURL
        case apiSecret
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        switch operation {
        case .create:
            return Section.allCases.count - 1   // No deleteService
        case .update:
            return Section.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .credentials:
            return Credentials.allCases.count
        case .deleteService:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .credentials:
            return nil
        case .deleteService:
            return " " // Use an empty string for more dramatic spacing
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .credentials:
            switch Credentials(rawValue: indexPath.row)! {
            case .siteURL:
                let cell = tableView.dequeueReusableCell(withIdentifier: AuthenticationTableViewCell.className, for: indexPath) as! AuthenticationTableViewCell
                cell.titleLabel.text = LocalizedString("Site URL", comment: "The title of the Nightscout site URL")
                cell.textField.text = nightscoutService.siteURL?.absoluteString
                cell.textField.keyboardType = .URL
                cell.textField.placeholder = LocalizedString("https://mysite.herokuapp.com", comment: "The placeholder text for the Nightscout site URL")
                cell.textField.returnKeyType = .next
                cell.textField.delegate = self
                return cell
            case .apiSecret:
                let cell = tableView.dequeueReusableCell(withIdentifier: AuthenticationTableViewCell.className, for: indexPath) as! AuthenticationTableViewCell
                cell.titleLabel.text = LocalizedString("API Secret", comment: "The title of the Nightscout API secret")
                cell.textField.text = nightscoutService.apiSecret
                cell.textField.keyboardType = .asciiCapable
                cell.textField.placeholder = LocalizedString("Required", comment: "The default placeholder for required text")
                cell.textField.returnKeyType = .done
                cell.textField.delegate = self
                return cell
            }
        case .deleteService:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = LocalizedString("Delete Service", comment: "Button title to delete a service")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .credentials:
            break
        case .deleteService:
            confirmDeletion {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

    // MARK: - UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let indexPath = tableView.indexPathForRow(at: tableView.convert(textField.frame.origin, from: textField.superview)) else {
            return true
        }

        let text = (textField.text! as NSString).replacingCharacters(in: range, with: string)

        switch Section(rawValue: indexPath.section)! {
        case .credentials:
            switch Credentials(rawValue: indexPath.row)! {
            case .siteURL:
                nightscoutService.siteURL = URL(http: text)
            case .apiSecret:
                nightscoutService.apiSecret = text
            }
        case .deleteService:
            break
        }

        updateButtonStates()

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField.returnKeyType {
        case .next:
            if let indexPath = tableView.indexPathForRow(at: tableView.convert(textField.frame.origin, from: textField.superview)),
                let cell = tableView.cellForRow(at: IndexPath(row: indexPath.row + 1, section: indexPath.section)) as? AuthenticationTableViewCell {
                cell.textField.becomeFirstResponder()
            }
            return true
        case .done:
            textField.resignFirstResponder()
            done()
            return true
        default:
            return false
        }
    }

}


fileprivate extension URL {

    init?(http: String) {
        self.init(string: http)

        guard let scheme = scheme?.lowercased(),
            (scheme == "http" || scheme == "https"),
            host?.isEmpty == false else {
                return nil
        }
    }

}


extension AuthenticationTableViewCell: IdentifiableClass {}


extension AuthenticationTableViewCell: NibLoadable {}


extension TextButtonTableViewCell: IdentifiableClass {}
