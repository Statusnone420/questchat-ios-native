//
//  QuestChatNativeApp.swift
//  QuestChatNative
//
//  Created by Anthony Gagliardo on 11/30/25.
//

import SwiftUI

@main
struct QuestChatNativeApp: App {
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
        }
    }
}
