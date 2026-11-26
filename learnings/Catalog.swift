//
//  Catalog.swift
//  The courses, sections, lessons, checkpoints and projects, from catalog.json.
//  catalog.json is written by the website's  node scripts/app-catalog.mjs <path>  after content changes.
//

import Foundation

struct Catalog: Decodable {
    let courses: [Course]

    static let shared: Catalog = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Catalog.self, from: data) else { return Catalog(courses: []) }
        return c
    }()

    /// The item a site route belongs to, such as "lesson-n1".
    func item(route: String) -> Item? {
        for c in courses { for s in c.sections { if let i = s.items.first(where: { $0.href == route }) { return i } } }
        return nil
    }
}

struct Course: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let ta: String?
    let blurb: String
    let taBlurb: String?
    let sections: [CourseSection]
    let later: [Later]

    var items: [Item] { sections.flatMap(\.items) }
    /// What the site divides by for the course percentage: every item, plus the topics still to come.
    var size: Int { items.count + later.reduce(0) { $0 + $1.topics.count } }

    func name(_ lang: Lang) -> String { lang == .ta ? (ta ?? name) : name }
    func blurb(_ lang: Lang) -> String { lang == .ta ? (taBlurb ?? blurb) : blurb }
}

struct CourseSection: Decodable, Hashable {
    let t: String
    let ta: String?
    let items: [Item]

    func title(_ lang: Lang) -> String { lang == .ta ? (ta ?? t) : t }
}

struct Later: Decodable, Hashable {
    let level: Int
    let name: String
    let ta: String?
    let topics: [String]

    func title(_ lang: Lang) -> String { lang == .ta ? (ta ?? name) : name }
}

struct CheckRef: Decodable, Hashable {
    let st: String
    let k: String
}

struct Item: Decodable, Identifiable, Hashable {
    enum Kind: String, Decodable { case lesson, checkpoint, project }

    let id: String
    let kind: Kind
    let href: String
    let no: String
    let title: String
    let ta: String?
    let minutes: Int
    // lessons: how many predictions, quiz questions and tasks
    let P: Int?
    let Q: Int?
    let T: Int?
    // checkpoints: the questions and where their answers are saved
    let cp: [CheckRef]?
    // projects: where the ticks are saved, and how many there are
    let store: String?
    let checks: Int?

    func title(_ lang: Lang) -> String { lang == .ta ? (ta ?? title) : title }

    var symbol: String {
        switch kind {
        case .lesson: "doc.text"
        case .checkpoint: "checklist"
        case .project: "flag.checkered"
        }
    }
}

enum Lang: String, CaseIterable, Identifiable {
    case en, ta
    var id: String { rawValue }
    var label: String { self == .ta ? "தமிழ்" : "English" }
}
