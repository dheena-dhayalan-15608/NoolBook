//
//  ContentView.swift
//  The app's tabs: Learn, Explore, Debug Desk and Account. On iPad and Mac they become a sidebar.
//

import SwiftUI

enum AppTab: Hashable { case learn, explore, debug, account }

struct ContentView: View {
    @State private var tab: AppTab = .learn
    @State private var learner = Learner.shared

    var body: some View {
        TabView(selection: $tab) {
            Tab(t("Learn", "கற்க"), systemImage: "book", value: .learn) { LearnView() }
            Tab(t("Explore", "ஆராய்க"), systemImage: "sparkles", value: .explore) { ExploreView() }
            Tab(t("Debug Desk", "பிழைதிருத்த மேசை"), systemImage: "bubble.left.and.bubble.right", value: .debug) {
                SitePageScreen(page: .debug, route: "debug", title: t("Debug Desk", "பிழைதிருத்த மேசை"))
            }
            Tab(t("Account", "கணக்கு"), systemImage: "person.crop.circle", value: .account) {
                SitePageScreen(page: .account, route: "account", title: t("Account", "கணக்கு"))
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .preferredColorScheme(learner.theme == "dark" ? .dark : learner.theme == "light" ? .light : nil)
        .task { WebPage.learn.warm() }
    }

    private func t(_ en: String, _ ta: String) -> String { learner.lang == .ta ? ta : en }
}

/// A whole tab that is one page of the site (Debug Desk, Account).
struct SitePageScreen: View {
    let page: WebPage
    let route: String
    let title: String

    var body: some View {
        NavigationStack {
            WebPageView(page: page)
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        if page.canGoBack {
                            Button { page.goBack() } label: { Label("Back", systemImage: "chevron.backward") }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { page.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                            .keyboardShortcut("r", modifiers: .command)
                    }
                }
        }
        .onAppear {
            page.refreshIfStale()
            page.open(page.route.isEmpty ? route : page.route)
        }
    }
}

#Preview {
    ContentView()
}
