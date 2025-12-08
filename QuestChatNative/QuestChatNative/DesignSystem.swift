import SwiftUI

// MARK: - WEEKLYQUEST DESIGN SYSTEM – READ BEFORE EDITING
//
// Repo: questchat-ios-native
// Architecture:
// - SwiftUI app with MVVM + Coordinator + DependencyContainer.
// - QuestChatApp.swift is the ONLY @main entry point.
// - AppCoordinator builds ContentView using DependencyContainer.
// - Some tabs still use a WebView wrapper to load questchat.app.
//
// HARD RULES FOR ANY AI / FUTURE DEV:
// - DO NOT create another @main struct.
// - DO NOT rename or delete QuestChatApp, AppCoordinator, or DependencyContainer.
// - DO NOT modify WebView.swift.
//
// VISUAL STYLE:
// - Background: pure OLED black (Color.black).
// - Cards: "glass" style:
//     • RoundedRectangle cornerRadius: 20–24
//     • Background: .ultraThinMaterial OR Color.white.opacity(0.06)
//     • 1 px stroke: Color.white.opacity(0.08)
//     • Internal padding: 16–20
// - Accent colors: use existing teal/purple from asset catalog
//     • Prefer Color.teal / Color.purple, or any Color.questTeal / Color.questPurple
// - Icons:
//     • Use SF Symbols Draw when possible (iOS 17 / SF Symbols 5+ if not).
//     • Prefer “drawn” style where it makes sense.
//     • Use .symbolRenderingMode(.hierarchical) or .palette with teal/purple.
// - Typography:
//     • Section titles: .headline or .title3, .fontWeight(.semibold)
//     • Secondary text: .subheadline, .foregroundStyle(.secondary)
//     • Tiny labels, stats, timers: .caption, .monospacedDigit
// - Layout:
//     • Use vertical stacks of glass cards instead of plain list rows.
//     • Align content leading, maxWidth: .infinity in cards.
//     • Match padding/spacing of Focus and HP tabs.
//
// CODE RULES:
// - Keep all existing logic, bindings, and view model APIs the same.
// - You may rearrange layout (stacks, spacers) and view modifiers only.
// - Don’t rename view models, functions, or navigation types.

enum WeeklyQuestDesign {
    static let background = Color.black

    static let cardBackground = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
    static let cardCornerRadius: CGFloat = 22
    static let cardHorizontalPadding: CGFloat = 16
}
//
//  DesignSystem.swift
//  QuestChatNative
//
//  Created by Anthony Gagliardo on 12/6/25.
//

