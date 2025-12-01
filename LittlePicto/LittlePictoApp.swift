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
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
