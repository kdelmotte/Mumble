// SettingsView.swift
// Mumble
//
// The main Settings window. Uses a NavigationSplitView with a left-hand
// sidebar for tab navigation and a detail area that shows the selected tab.

import SwiftUI

// MARK: - SettingsTab

enum SettingsTab: String, CaseIterable, Identifiable {
    case home
    case settings
    case shortcut
    case tone
    case vocabulary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:       return "Home"
        case .settings:   return "Settings"
        case .shortcut:   return "Shortcut"
        case .tone:       return "Tone"
        case .vocabulary: return "Vocabulary"
        }
    }

    var systemImage: String {
        switch self {
        case .home:       return "house"
        case .settings:   return "gearshape"
        case .shortcut:   return "keyboard"
        case .tone:       return "waveform"
        case .vocabulary: return "character.book.closed"
        }
    }

    /// Asset catalog image name for the mascot header.
    var headerImageName: String {
        switch self {
        case .home:       return "MumbleIconHome"
        case .settings:   return "MumbleIconSettings"
        case .shortcut:   return "MumbleIconShortcut"
        case .tone:       return "MumbleIconTone"
        case .vocabulary: return "MumbleIconVocabulary"
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .home

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            switch selectedTab {
            case .home:
                HomeTabView(viewModel: viewModel)
            case .settings:
                SettingsTabView(viewModel: viewModel)
            case .shortcut:
                ShortcutTabView(viewModel: viewModel)
            case .tone:
                ToneTabView(viewModel: viewModel)
            case .vocabulary:
                VocabularyTabView(viewModel: viewModel)
            }
        }
    }
}
