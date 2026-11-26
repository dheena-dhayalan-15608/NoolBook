//
//  Learner.swift
//  What the learner has done, read from the site's saved progress ("ztp-progress-v1"), and their
//  language ("eaas-lang") and theme ("ztp-theme"). The site keeps saving them as it always has; the app
//  reads them from the page and works out percentages the same way as the site's stores/progress.js.
//

import Foundation
import Observation

@Observable
final class Learner {
    static let shared = Learner()

    private(set) var saved: [String: Any] = [:]
    var lang: Lang = .en
    var theme: String = ""          // "", "light" or "dark"; empty follows the device

    /// Goes up whenever one page changes something the others show (progress, language, theme, signing in or out),
    /// so the other pages reload before they are shown again.
    private(set) var epoch = 0

    private let cacheKey = "noolstack-app-progress"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: cacheKey) { saved = Self.parse(raw) }
        if let l = UserDefaults.standard.string(forKey: "noolstack-app-lang"), let v = Lang(rawValue: l) { lang = v }
        theme = UserDefaults.standard.string(forKey: "noolstack-app-theme") ?? ""
    }

    /// A page reported what it has saved.
    func update(progress: String?, lang l: String?, theme t: String?) {
        let p = progress ?? ""
        let newSaved = Self.parse(p)
        let newLang = Lang(rawValue: l ?? "") ?? lang
        let newTheme = (t == "light" || t == "dark") ? t! : ""
        let changed = !NSDictionary(dictionary: newSaved).isEqual(to: saved) || newLang != lang || newTheme != theme
        saved = newSaved
        lang = newLang
        theme = newTheme
        UserDefaults.standard.set(p, forKey: cacheKey)
        UserDefaults.standard.set(lang.rawValue, forKey: "noolstack-app-lang")
        UserDefaults.standard.set(theme, forKey: "noolstack-app-theme")
        if changed { epoch += 1 }
    }

    func bump() { epoch += 1 }

    private static func parse(_ raw: String) -> [String: Any] {
        guard let d = raw.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }

    // MARK: progress, as on the site

    private func truthy(_ v: Any?) -> Bool {
        switch v {
        case nil, is NSNull: false
        case let b as Bool: b
        case let n as NSNumber: n.doubleValue != 0
        case let s as String: !s.isEmpty
        default: true
        }
    }
    private func dict(_ k: String) -> [String: Any] { saved[k] as? [String: Any] ?? [:] }
    private func doneCount(_ store: String, _ prefix: String, _ n: Int) -> Int {
        let s = dict(store)
        return (0..<n).filter { truthy((s[prefix + String($0)] as? [String: Any])?["done"]) }.count
    }
    private func frac(_ a: Int, _ n: Int?) -> Double { (n ?? 0) > 0 ? Double(a) / Double(n!) : 0 }

    func pct(_ i: Item) -> Int {
        switch i.kind {
        case .lesson:
            let read = truthy(dict("read")[i.id]) ? 20.0 : 0
            let ex = truthy(dict("ex")[i.id]) ? 10.0 : 0
            let p = 25 * frac(doneCount("pred", i.id + "p", i.P ?? 0), i.P)
            let q = 30 * frac(doneCount("quiz", i.id + "q", i.Q ?? 0), i.Q)
            let t = 15 * frac(doneCount("task", i.id + "t", i.T ?? 0), i.T)
            return Int((read + ex + p + q + t).rounded())
        case .checkpoint:
            return Int((100 * frac(cpDone(i), i.cp?.count)).rounded())
        case .project:
            return Int((100 * frac(projTicks(i), i.checks)).rounded())
        }
    }

    func done(_ i: Item) -> Bool {
        switch i.kind {
        case .lesson: pct(i) == 100
        case .checkpoint: cpPassed(i)
        case .project: projTicks(i) == (i.checks ?? 0)
        }
    }

    private func cpEntry(_ r: CheckRef) -> [String: Any] { dict(r.st)[r.k] as? [String: Any] ?? [:] }
    private func cpDone(_ i: Item) -> Int { (i.cp ?? []).filter { truthy(cpEntry($0)["done"]) }.count }
    private func cpPassed(_ i: Item) -> Bool {
        let refs = i.cp ?? []
        guard !refs.isEmpty, cpDone(i) == refs.count else { return false }
        let pts = refs.reduce(0.0) { $0 + ((cpEntry($1)["pts"] as? NSNumber)?.doubleValue ?? 0) }
        return (10 * pts / Double(refs.count)).rounded() >= 70
    }
    private func projTicks(_ i: Item) -> Int {
        let checks = (saved[i.store ?? ""] as? [String: Any])?["checks"] as? [Any] ?? []
        return checks.filter { truthy($0) }.count
    }

    func pct(_ c: Course) -> Int {
        guard c.size > 0 else { return 0 }
        return Int((Double(c.items.reduce(0) { $0 + pct($1) }) / Double(c.size)).rounded())
    }
    func doneCount(_ c: Course) -> Int { c.items.filter { done($0) }.count }

    /// The first thing not finished yet, in course order.
    func next(in courses: [Course]) -> (Course, Item)? {
        for c in courses { if let i = c.items.first(where: { !done($0) }) { return (c, i) } }
        return nil
    }

    var started: Bool { !dict("read").isEmpty || !dict("quiz").isEmpty || !dict("pred").isEmpty }

    /// Days in a row with some learning, ending today or yesterday.
    var streak: Int {
        let days = Set((saved["days"] as? [String]) ?? [])
        guard !days.isEmpty else { return 0 }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        var d = Date()
        if !days.contains(f.string(from: d)) { d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while days.contains(f.string(from: d)) { n += 1; d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    var badges: Int { (saved["badges"] as? [Any])?.count ?? 0 }
}
