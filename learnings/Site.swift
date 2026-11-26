//
//  Site.swift
//  The NoolStack website the app shows, and which addresses stay inside the app.
//

import Foundation

enum Site {
    /// The live site on Zoho Catalyst (the same address the website redirects to).
    static let base = URL(string: "https://eaas-60097457113.development.catalystserverless.in/app/")!

    /// The address of a page on the site, from its hash route, such as "lesson-n1" or "debug".
    static func url(_ route: String) -> URL {
        URL(string: base.absoluteString + "#/" + route)!
    }

    /// Pages opened in the app: the site itself and Zoho's sign-in pages. Anything else opens in the browser.
    static func staysInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), url.scheme == "https" || url.scheme == "http" else { return false }
        if host == base.host { return true }
        let zoho = ["zoho.com", "zoho.in", "zohoapis.com", "zohoapis.in", "zohostatic.com", "zohostatic.in", "zohocdn.com",
                    "catalystserverless.com", "catalystserverless.in"]
        return zoho.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// The route in a site address, such as "lesson-n1" for ".../app/#/lesson-n1".
    static func route(of url: URL?) -> String {
        guard let f = url?.fragment else { return "" }
        return f.hasPrefix("/") ? String(f.dropFirst()) : f
    }
}

/// The pages under Explore, each a page of the site.
struct ExplorePage: Identifiable, Hashable {
    let id: String
    let title: String
    let ta: String
    let symbol: String
    let note: String

    static let all: [ExplorePage] = [
        .init(id: "syllabus", title: "Syllabus", ta: "பாடத்திட்டம்", symbol: "list.bullet.rectangle", note: "Every course and lesson on one page."),
        .init(id: "mindmap", title: "Mind Map", ta: "மன வரைபடம்", symbol: "point.3.connected.trianglepath.dotted", note: "Roadmaps of what to learn next."),
        .init(id: "animations", title: "Animations", ta: "அசைவூட்டங்கள்", symbol: "play.rectangle", note: "Short animated videos that explain everyday technology."),
        .init(id: "snippets", title: "Snippets", ta: "சிறு காணொளிகள்", symbol: "film.stack", note: "Bite-sized clips."),
        .init(id: "glossary", title: "Glossary", ta: "சொற்களஞ்சியம்", symbol: "character.book.closed", note: "Every new word, explained."),
        .init(id: "errors", title: "Error help", ta: "பிழை உதவி", symbol: "exclamationmark.bubble", note: "What common error messages mean."),
    ]
}
