//
//  LearnView.swift
//  The Learn tab: where you are up to, every course with its progress, and each course's lessons.
//  Lessons open in the reader, which shows the lesson page of the site.
//

import SwiftUI

enum LearnRoute: Hashable {
    case course(Course)
    case item(Item)
}

struct LearnView: View {
    @State private var path: [LearnRoute] = []
    @State private var learner = Learner.shared
    @State private var settings = false
    private let courses = Catalog.shared.courses

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Hero(next: learner.next(in: courses), started: learner.started) { path.append(.item($0)) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if learner.started {
                    Section {
                        HStack(spacing: 12) {
                            Stat(value: "\(courses.reduce(0) { $0 + learner.doneCount($1) })", label: t("Finished", "முடிந்தவை"), symbol: "checkmark.seal")
                            Stat(value: "\(learner.streak)", label: t("Day streak", "தொடர் நாட்கள்"), symbol: "flame")
                            Stat(value: "\(learner.badges)", label: t("Badges", "பதக்கங்கள்"), symbol: "rosette")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section(t("Courses", "பாடநெறிகள்")) {
                    ForEach(courses) { c in
                        NavigationLink(value: LearnRoute.course(c)) { CourseRow(course: c) }
                    }
                }
            }
            .navigationTitle("NoolStack")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { settings = true } label: { Label(t("Settings", "அமைப்புகள்"), systemImage: "gearshape") }
                }
            }
            .sheet(isPresented: $settings) { SettingsSheet() }
            .navigationDestination(for: LearnRoute.self) { r in
                switch r {
                case .course(let c): CourseView(course: c) { path.append(.item($0)) }
                case .item(let i): ReaderView(page: .learn, route: i.href, title: i.title(learner.lang))
                }
            }
        }
    }

    private func t(_ en: String, _ ta: String) -> String { learner.lang == .ta ? ta : en }
}

private struct Hero: View {
    let next: (Course, Item)?
    let started: Bool
    let open: (Item) -> Void
    @State private var learner = Learner.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image("Mascot").resizable().scaledToFit().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(learner.lang == .ta ? "கல்வி ஒரு சேவை" : "Education As A Service")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(started ? (learner.lang == .ta ? "மீண்டும் வருக!" : "Welcome back!") : (learner.lang == .ta ? "பூஜ்ஜியத்திலிருந்து தொடங்குங்கள்" : "Start from zero"))
                        .font(.title2.bold())
                }
            }
            Text(learner.lang == .ta
                 ? "“கணினி என்றால் என்ன?” என்பதிலிருந்து தொடங்கும் இலவசப் பாடநெறிகள். ஒவ்வொரு பாடத்திலும் ஒரு அனிமேஷன், கைகளால் முயற்சி, ஒரு வினாடி வினா."
                 : "Free courses that start with “what is a computer?”. Every lesson has an animation, something to try with your own hands, and a quiz.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let (c, i) = next {
                Button { open(i) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(started ? (learner.lang == .ta ? "தொடரவும்" : "Continue") : (learner.lang == .ta ? "கற்கத் தொடங்குங்கள்" : "Start learning"))
                                .font(.caption.weight(.semibold)).opacity(0.8)
                            Text(i.title(learner.lang)).font(.headline).multilineTextAlignment(.leading)
                            Text(c.name(learner.lang)).font(.caption).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill").font(.title)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.ink)
                    .background(Color.amber, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Label(learner.lang == .ta ? "எல்லாப் பாடங்களையும் முடித்துவிட்டீர்கள்!" : "You have finished every lesson so far!", systemImage: "party.popper")
                    .font(.headline)
            }
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct Stat: View {
    let value: String
    let label: String
    let symbol: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(Color.amberText)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct CourseRow: View {
    let course: Course
    @State private var learner = Learner.shared
    var body: some View {
        HStack(spacing: 14) {
            Ring(pct: learner.pct(course), size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(course.name(learner.lang)).font(.headline)
                Text(course.blurb(learner.lang)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

struct Ring: View {
    let pct: Int
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            Circle().stroke(Color.amber.opacity(0.22), lineWidth: size / 9)
            Circle().trim(from: 0, to: CGFloat(pct) / 100)
                .stroke(Color.amber, style: StrokeStyle(lineWidth: size / 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(pct)%").font(.system(size: size / 3.6, weight: .semibold)).monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(pct) percent done")
    }
}

struct CourseView: View {
    let course: Course
    let open: (Item) -> Void
    @State private var learner = Learner.shared

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Ring(pct: learner.pct(course), size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(learner.doneCount(course)) / \(course.items.count)").font(.title3.bold()).monospacedDigit()
                        Text(course.blurb(learner.lang)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            ForEach(Array(course.sections.enumerated()), id: \.offset) { _, s in
                Section(s.title(learner.lang)) {
                    ForEach(s.items) { i in
                        Button { open(i) } label: { ItemRow(item: i) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !course.later.isEmpty {
                Section(learner.lang == .ta ? "விரைவில் வருகிறது" : "Coming soon") {
                    ForEach(course.later, id: \.self) { l in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l.title(learner.lang)).font(.headline)
                            Text(l.topics.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(course.name(learner.lang))
    }
}

private struct ItemRow: View {
    let item: Item
    @State private var learner = Learner.shared
    var body: some View {
        let pct = learner.pct(item), done = learner.done(item)
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : item.symbol)
                .font(.title3)
                .foregroundStyle(done ? Color.mint : Color.amberText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title(learner.lang)).font(.body).foregroundStyle(.primary)
                HStack(spacing: 8) {
                    if !item.no.isEmpty { Text(item.no) }
                    if item.minutes > 0 { Text("\(item.minutes) min") }
                    if pct > 0 && !done { Text("\(pct)%") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A page of the site pushed onto a tab (a lesson, or an Explore page), with the site's own lesson pager inside.
struct ReaderView: View {
    let page: WebPage
    let route: String
    let title: String
    @State private var learner = Learner.shared

    var body: some View {
        WebPageView(page: page)
            .navigationTitle(currentTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { page.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r", modifiers: .command)
                }
            }
            .onAppear {
                page.refreshIfStale()
                page.open(route)
            }
    }

    /// The lesson pager moves to other lessons inside the page; keep the title in step.
    private var currentTitle: String {
        if page.route != route, let i = Catalog.shared.item(route: page.route) { return i.title(learner.lang) }
        return title
    }
}
