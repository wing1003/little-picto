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
