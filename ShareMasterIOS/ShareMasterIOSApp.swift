//
//  ShareMasterIOSApp.swift
//  ShareMasterIOS
//
//  iOS companion to the ShareMaster menu bar app. Accounts and destinations
//  are stored in the App Group (defaults + keychain) so the share extension
//  can upload with the same configuration.
//

import SwiftUI

@main
struct ShareMasterIOSApp: App {
    var body: some Scene {
        WindowGroup {
            DestinationListView()
        }
    }
}
