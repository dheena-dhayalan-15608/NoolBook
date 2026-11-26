//
//  NoolStackApp.swift
//  NoolStack for iPhone, iPad and Mac: free tech education in English and Tamil.
//

import SwiftUI

@main
struct NoolStackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 760, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 800)
        .commands { SidebarCommands() }
        #endif

        #if os(macOS)
        Settings {
            SettingsForm().frame(width: 460).padding(.vertical)
        }
        #endif
    }
}
