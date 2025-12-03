//
//  LoadingManager.swift
//  pausehere
//
//  Created by wangpengcheng on 2025/6/11.
//
import SwiftUI

class LoadingManager: ObservableObject {
    static let shared = LoadingManager()

    @Published var isLoading: Bool = false

    private init() {}
    
    func show() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}
