//
//  LittlePictoApp.swift
//  LittlePicto
//
//  Created by diruo on 2025/11/28.
//

import SwiftUI
import FirebaseCore

@main
struct LittlePictoApp: App {
    // Register app delegate for Firebase setup.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    /// Global subscription manager, injected into the environment so any view
    /// can check `isPremium` or trigger purchases.
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
        }
    }
}
