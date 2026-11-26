//
//  ExploreView.swift
//  The Explore tab (syllabus, mind map, animations, snippets, glossary, error help) and the settings.
//

import SwiftUI

struct ExploreView: View {
    @State private var learner = Learner.shared

    var body: some View {
        NavigationStack {
            List(ExplorePage.all) { p in
                NavigationLink(value: p) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(learner.lang == .ta ? p.ta : p.title).font(.headline)
                            Text(p.note).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } icon: {
                        Image(systemName: p.symbol).foregroundStyle(Color.amberText)
                    }
                }
            }
            .navigationTitle(learner.lang == .ta ? "ஆராய்க" : "Explore")
            .navigationDestination(for: ExplorePage.self) { p in
                ReaderView(page: .explore, route: p.id, title: learner.lang == .ta ? p.ta : p.title)
            }
        }
    }
}

/// Language and theme. They are the site's own settings, so the website on the same account follows them too.
struct SettingsForm: View {
    @State private var learner = Learner.shared

    private var lang: Binding<Lang> {
        Binding(get: { learner.lang }, set: { (l: Lang) in
            learner.lang = l
            WebPage.setSiteValue("eaas-lang", l.rawValue)
        })
    }

    private var theme: Binding<String> {
        Binding(get: { learner.theme }, set: { (t: String) in
            learner.theme = t
            WebPage.setSiteValue("ztp-theme", t.isEmpty ? nil : t)
        })
    }

    var body: some View {
        Form {
            Picker("Language · மொழி", selection: lang) {
                ForEach(Lang.allCases) { l in Text(l.label).tag(l) }
            }
            Picker("Theme", selection: theme) {
                Text("Same as the device").tag("")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Section {
                Link("Open NoolStack in the browser", destination: Site.base)
                Link("Privacy", destination: Site.url("privacy"))
                Link("Community rules", destination: Site.url("rules"))
            } footer: {
                Text("NoolStack is free. Lessons, progress, sign-in and Debug Desk are the same as on the website.")
            }
        }
        .formStyle(.grouped)
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SettingsForm()
                .navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

extension Color {
    /// NoolStack's colours, from the website.
    static let amber = Color(red: 0xF2 / 255, green: 0xB1 / 255, blue: 0x3C / 255)
    static let ink = Color(red: 0x1C / 255, green: 0x22 / 255, blue: 0x30 / 255)
    static let mint = Color(red: 0x3F / 255, green: 0xB3 / 255, blue: 0x7F / 255)
    /// Amber that is dark enough to read on a light background.
    static let amberText = Color("AccentColor")
}
