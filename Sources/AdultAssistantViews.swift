import SwiftUI

struct AdultAssistantView: View {
    @Environment(AdultAssistantController.self) private var assistant
    @State private var showsSettings = false

    var body: some View {
        @Bindable var assistant = assistant
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                AdultPrivateQABanner()
                if let issue = assistant.library.storageIssue {
                    Label(issue, systemImage: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    Button("Retry opening plans") { assistant.library.reload() }
                }
                if let plan = assistant.selectedPlan {
                    AdultPlanView(plan: plan)
                    Button { assistant.selectedPlanID = nil; assistant.goal = ""; assistant.guide = nil } label: {
                        Label("Another task", systemImage: "plus.circle.fill").font(.headline).padding(.vertical, 8)
                    }.accessibilityIdentifier("assistant-another-task")
                } else {
                    composer
                    if !assistant.library.plans.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your plans").font(.title2.bold())
                            ForEach(assistant.library.plans) { plan in
                                Button { assistant.selectedPlanID = plan.id } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "list.bullet.clipboard").font(.title2).foregroundStyle(AdultPalette.accent)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(plan.title).font(.headline)
                                            Text("\(plan.actions.filter { $0.status == .completed }.count) of \(plan.actions.count) ready or done")
                                                .font(.subheadline).foregroundStyle(AdultPalette.secondaryText)
                                        }.fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right").font(.caption.bold()).accessibilityHidden(true)
                                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(22).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(AdultPalette.background)
        .navigationTitle("Assistant")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showsSettings = true } label: { Label("Assistant settings", systemImage: "slider.horizontal.3") }
                    .accessibilityIdentifier("assistant-settings")
            }
        }
        .sheet(isPresented: $showsSettings) { AdultAssistantSettingsView() }
        .alert("Needs a hand", isPresented: Binding(get: { assistant.issue != nil }, set: { if !$0 { assistant.issue = nil } })) {
            Button("OK", role: .cancel) { assistant.issue = nil }
        } message: { Text(assistant.issue ?? "Try again.") }
        .accessibilityIdentifier("assistant-screen")
    }

    private var composer: some View {
        @Bindable var assistant = assistant
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "sparkles").font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AdultPalette.accent).accessibilityHidden(true)
                Text("A little help.\nA doable plan.")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let guide = assistant.guide {
                HStack(alignment: .top) {
                    Label(guide.title, systemImage: guide.symbol).font(.subheadline.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { assistant.guide = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Remove guide context").buttonStyle(.plain)
                }.padding(14).background(AdultPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("What would you like to get done?").font(.headline)
                TextEditor(text: $assistant.goal)
                    .frame(minHeight: 96, maxHeight: 150).scrollContentBackground(.hidden)
                    .padding(10).background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AdultPalette.accent.opacity(0.25)))
                    .accessibilityLabel("Task for your assistant").accessibilityIdentifier("assistant-goal")
            }
            if assistant.isWorking {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(assistant.connection.useWebResearch ? "Researching and making your plan…" : "Making your plan…")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Cancel") { assistant.cancelGeneration() }
                }
            } else if assistant.connection.canGenerate && !assistant.isPrivateQA {
                Button { assistant.startPlan() } label: {
                    Label("Make my plan", systemImage: "sparkles").font(.headline)
                        .padding(.vertical, 10).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).foregroundStyle(AdultPalette.background)
                    .disabled(assistant.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !assistant.library.canSave)
                    .accessibilityIdentifier("assistant-make-plan")
            } else {
                Button { showsSettings = true } label: {
                    Label("Choose your AI", systemImage: "sparkles").font(.headline)
                        .padding(.vertical, 10).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).foregroundStyle(AdultPalette.background).accessibilityIdentifier("assistant-connect")
            }
            if assistant.goal.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    suggestion("Reset my week", symbol: "calendar", color: .teal, goal: "Plan a Sunday reset with laundry, groceries and a 30-minute tidy. Ask for dates if needed.")
                    suggestion("Make dinner easier", symbol: "carrot", color: .orange, goal: "Help me plan three simple dinners and a shopping list for one person.")
                    suggestion("Sort the paperwork", symbol: "doc.text", color: .indigo, goal: "Make a checklist to organize household paperwork and research any rules that depend on where I live.")
                    suggestion("Care for my car", symbol: "car", color: .green, goal: "Help me plan car maintenance. Ask for the model, mileage and manual before choosing intervals.")
                }
            }
            Label(assistant.connection.provider.displayName, systemImage: assistant.connection.provider == .onDevice ? "cpu" : "network")
                .font(.caption.weight(.semibold)).foregroundStyle(AdultPalette.secondaryText)
        }
    }

    private func suggestion(_ title: String, symbol: String, color: Color, goal: String) -> some View {
        Button { assistant.goal = goal } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(title).font(.subheadline.bold()).foregroundStyle(AdultPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct AdultPrivateQABanner: View {
    @Environment(AdultAssistantController.self) private var assistant
    var body: some View {
        #if DEBUG
        if assistant.isPrivateQA {
            Text("Private QA · \(assistant.privateSessionID?.uuidString ?? "missing session")\nScheduling and AI disabled")
                .font(.caption).fixedSize(horizontal: false, vertical: true).padding(10)
                .frame(maxWidth: .infinity, alignment: .leading).background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("adult-private-qa-marker")
        }
        #endif
    }
}

struct AdultPlanSidebar: View {
    @Environment(AdultAssistantController.self) private var assistant
    var body: some View {
        List {
            Button { assistant.selectedPlanID = nil; assistant.guide = nil; assistant.goal = "" } label: {
                Label("New task", systemImage: "plus.circle.fill").font(.headline).padding(.vertical, 6)
            }
            ForEach(assistant.library.plans) { plan in
                Button { assistant.selectedPlanID = plan.id } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text(plan.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Your plans")
    }
}

private struct AdultPlanView: View {
    @Environment(AdultAssistantController.self) private var assistant
    let plan: AdultAssistantPlan
    @State private var deleting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(plan.title).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            Text(plan.summary).font(.title3).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Label(plan.provider.displayName, systemImage: "sparkles")
                ShareLink(item: plan.shareText) { Label("Share plan", systemImage: "square.and.arrow.up") }
            }.font(.caption.weight(.semibold))
            ForEach(plan.actions) { action in AdultActionCard(planID: plan.id, action: action) }
            if let evidence = plan.researchEvidence { AdultResearchView(evidence: evidence) }
            if !plan.citations.isEmpty {
                DisclosureGroup("Guide and research sources") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(plan.citations, id: \.url) { citation in
                            Link(destination: citation.url) {
                                Label(citation.title, systemImage: "arrow.up.right.square").fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.padding(.top, 12)
                }.font(.subheadline)
            }
            Button("Delete plan", role: .destructive) { deleting = true }.font(.subheadline)
                .disabled(assistant.busyActionID != nil || assistant.isWorking || !assistant.library.canSave)
        }
        .confirmationDialog("Delete this saved plan? Items already added to Calendar or scheduled reminders will remain. Any unresolved execution history will be removed.", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete saved plan", role: .destructive) { assistant.deletePlan(plan.id) }
            Button("Cancel", role: .cancel) { }
        }
    }
}

private struct AdultActionCard: View {
    @Environment(AdultAssistantController.self) private var assistant
    let planID: UUID
    let action: AdultAssistantAction
    @State private var editing = false
    @State private var reviewing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: action.kind.symbol).font(.title2).foregroundStyle(action.kind.color)
                    .frame(width: 32).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(action.kind.label.uppercased()).font(.caption.bold()).foregroundStyle(action.kind.color)
                    Text(action.title).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if action.status == .pending || action.status == .failed {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("Edit \(action.title)").padding(8)
                }
            }
            if !action.details.isEmpty { Text(action.details).fixedSize(horizontal: false, vertical: true) }
            ForEach(Array(action.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(action.kind.color).frame(minWidth: 20)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let date = action.scheduledAt {
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock").font(.subheadline.weight(.medium))
            }
            if action.repeatRule != .none { Text("Repeats \(action.repeatRule.rawValue)").font(.caption).foregroundStyle(.secondary) }
            if let duration = action.durationMinutes, action.kind == .calendar { Text("\(duration) minutes").font(.caption).foregroundStyle(.secondary) }
            if let error = action.error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            actionControls
            if let evidence = action.researchEvidence { AdultResearchView(evidence: evidence) }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(AdultPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16).fill(action.kind.color).frame(width: 4) }
        .sheet(isPresented: $editing) { AdultActionEditor(planID: planID, action: action) }
        .confirmationDialog("Only reset after checking Calendar and your reminders for this item.", isPresented: $reviewing, titleVisibility: .visible) {
            Button("I checked: no item was created") {
                do { try assistant.library.reviewExecution(planID: planID, actionID: action.id, resolution: .confirmedNoEffect) }
                catch { assistant.issue = AdultAssistantController.message(error) }
            }
            Button("Keep for review", role: .cancel) { }
        }
    }

    @ViewBuilder private var actionControls: some View {
        if action.status == .completed {
            Label(action.completionLabel, systemImage: "checkmark.circle.fill").font(.subheadline.bold()).foregroundStyle(.green)
        } else if action.status == .needsReview {
            Button("I’ve checked the result") { reviewing = true }.buttonStyle(.bordered)
        } else if action.status == .running || assistant.busyActionID == action.id {
            HStack { ProgressView(); Text("Working…") }.font(.subheadline)
        } else {
            switch action.kind {
            case .reminder, .calendar:
                Button { Task { await assistant.apply(planID: planID, actionID: action.id) } } label: {
                    Label(action.kind == .calendar ? "Add to Calendar" : "Schedule reminder", systemImage: "plus")
                        .fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(.borderedProminent).tint(action.kind.color).foregroundStyle(AdultPalette.background)
                    .disabled(assistant.busyActionID != nil || assistant.isPrivateQA || !assistant.library.canSave)
            case .research:
                Button { Task { await assistant.research(planID: planID, action: action) } } label: {
                    Label("Research with OpenAI", systemImage: "magnifyingglass")
                }.buttonStyle(.bordered).disabled(!assistant.connection.hasOpenAIKey || assistant.busyActionID != nil || assistant.isPrivateQA)
                if !assistant.connection.hasOpenAIKey { Text("Connect OpenAI in Assistant settings for live research.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            case .shopping:
                ShareLink(item: action.items.joined(separator: "\n")) { Label("Share shopping list", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                if let query = action.query, let url = Self.searchURL(query) {
                    Link(destination: url) { Label("Find items on the web", systemImage: "arrow.up.right.square") }
                }
                Text("Check the seller, total and delivery details at checkout.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if assistant.connection.hasOpenAIKey {
                    Button { Task { await assistant.researchShopping(planID: planID, action: action) } } label: {
                        Label("Find options with OpenAI", systemImage: "magnifyingglass")
                    }.buttonStyle(.bordered).disabled(assistant.busyActionID != nil || assistant.isPrivateQA)
                }
                Button("List prepared") { assistant.complete(planID: planID, action: action) }.disabled(!assistant.library.canSave)
            case .checklist:
                Button { assistant.complete(planID: planID, action: action) } label: { Label("Mark done", systemImage: "checkmark.circle") }
                    .buttonStyle(.bordered).disabled(!assistant.library.canSave)
            }
        }
    }

    private static func searchURL(_ query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

private struct AdultActionEditor: View {
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State var action: AdultAssistantAction
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $action.title, axis: .vertical)
                TextField("Details", text: $action.details, axis: .vertical)
                if action.kind == .calendar || action.kind == .reminder {
                    if let date = action.scheduledAt {
                        DatePicker("When", selection: Binding(get: { action.scheduledAt ?? date }, set: { action.scheduledAt = $0 }))
                    } else {
                        Label("Choose a time", systemImage: "clock.badge.questionmark")
                    }
                    Button(action.scheduledAt == nil ? "Set a time: one hour from now" : "Use one hour from now") { action.scheduledAt = Date().addingTimeInterval(3_600) }
                    Picker("Repeat", selection: $action.repeatRule) { ForEach(AdultActionRepeat.allCases) { Text($0.rawValue.capitalized).tag($0) } }
                    if action.kind == .calendar {
                        Stepper("\(action.durationMinutes ?? 30) minutes", value: Binding(get: { action.durationMinutes ?? 30 }, set: { action.durationMinutes = $0 }), in: 5...1_440, step: 5)
                    }
                    if action.kind == .reminder, action.repeatRule != .none {
                        Text("Repeating app reminders begin at the next matching time. Monthly reminders on the 29th–31st skip shorter months.").font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if action.query != nil { TextField("Search", text: Binding(get: { action.query ?? "" }, set: { action.query = $0 }), axis: .vertical) }
                if !action.items.isEmpty {
                    Section("Steps or items") {
                        ForEach(action.items.indices, id: \.self) { index in TextField("Item", text: $action.items[index], axis: .vertical) }
                    }
                }
            }
            .navigationTitle("Edit action")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            if action.kind == .calendar && action.durationMinutes == nil { action.durationMinutes = 30 }
                            try assistant.library.updateDraftAction(planID: planID, action: action)
                            dismiss()
                        } catch { assistant.issue = AdultAssistantController.message(error) }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 520, minHeight: 420)
        #endif
    }
}

private struct AdultResearchView: View {
    let evidence: AdultResearchEvidence
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Research", systemImage: "text.book.closed").font(.title2.bold()).foregroundStyle(.blue)
            Text(evidence.checkedAt, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
            ForEach(Array(evidence.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                VStack(alignment: .leading, spacing: 6) {
                    Text(safeAttributed(paragraph)).fixedSize(horizontal: false, vertical: true)
                    // Inline source controls remain visible when the provider's citation glyph isn't a Markdown link.
                    ForEach(evidence.citations.filter { paragraph.contains($0.url.absoluteString) || paragraph.contains($0.title) }, id: \.url) { citation in
                        Link(citation.title, destination: citation.url).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            ForEach(evidence.citations, id: \.url) { citation in
                Link(destination: citation.url) { Label(citation.title, systemImage: "link").fixedSize(horizontal: false, vertical: true) }.font(.subheadline)
            }
        }.padding(18).background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
    private func safeAttributed(_ text: String) -> AttributedString {
        var value = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        for run in value.runs where run.link != nil {
            if !evidence.citations.contains(where: { $0.url == run.link }) { value[run.range].link = nil }
        }
        return value
    }
}

extension AdultActionKind {
    var label: String { switch self { case .reminder: "Reminder"; case .calendar: "Calendar"; case .research: "Research"; case .shopping: "Shopping"; case .checklist: "Checklist" } }
    var symbol: String { switch self { case .reminder: "bell.badge"; case .calendar: "calendar.badge.plus"; case .research: "magnifyingglass"; case .shopping: "basket"; case .checklist: "checklist" } }
    var color: Color { switch self { case .reminder: Color("AssistantReminder"); case .calendar: Color("AssistantCalendar"); case .research: Color("AssistantResearch"); case .shopping: Color("AssistantShopping"); case .checklist: Color("AssistantChecklist") } }
}

extension AdultAssistantAction {
    var completionLabel: String { switch kind { case .calendar: "Added to Calendar"; case .reminder: "Reminder scheduled"; case .research: "Research ready"; case .shopping: "Shopping list prepared"; case .checklist: "Done" } }
}

extension AdultAssistantPlan {
    var shareText: String {
        ([title, summary] + actions.map { action in
            let date = action.scheduledAt.map { "\n" + $0.formatted(date: .abbreviated, time: .shortened) } ?? ""
            return "\n\(action.kind.label): \(action.title)\n\(action.details)\(date)\n" + action.items.joined(separator: "\n")
        } + citations.map { "\($0.title): \($0.url.absoluteString)" }).joined(separator: "\n")
    }
}
