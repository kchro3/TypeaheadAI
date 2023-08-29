//
//  SettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import SwiftUI

enum Tabs: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "History"
    case about = "About"

    var id: String { self.rawValue }
}

struct SettingsView: View {
    @State private var selectedTab: Tabs = .general

    var body: some View {
        NavigationView {
            List(Tabs.allCases, id: \.self) { tab in
                ItemRow(tab: tab, selectedTab: $selectedTab)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            viewForTab(selectedTab)
        }
    }

    private func viewForTab(_ tab: Tabs) -> some View {
        switch tab {
        case .general:
            return AnyView(GeneralSettingsView())
        case .shortcuts:
            return AnyView(HistoryListView())
        case .about:
            return AnyView(Text("Work in Progress"))
        }
    }
}

struct ItemRow: View {
    var tab: Tabs
    @Binding var selectedTab: Tabs
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(tab.rawValue)
            Spacer()
        }
        .padding(.all, 15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    selectedTab == tab ? .accentColor : (isHovered ? Color.gray.opacity(0.2) : Color.clear)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            selectedTab = tab
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
