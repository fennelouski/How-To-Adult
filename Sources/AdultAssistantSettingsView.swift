import SwiftUI

struct AdultAssistantSettingsView: View {
    @Environment(AdultAssistantController.self) private var assistant
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var status: String?

    var body: some View {
        @Bindable var connection = assistant.connection
        NavigationStack {
            Form {
                AdultPrivateQABanner()
                Section("Your AI") {
                    Picker("Connection", selection: $connection.provider) {
                        ForEach(AdultAIProvider.allCases) { Text($0.displayName).tag($0) }
                    }
                    if connection.provider == .onDevice {
                        Label(AdultAIService.onDeviceAvailable ? "Apple Intelligence is ready" : "Apple Intelligence isn’t available here",
                              systemImage: AdultAIService.onDeviceAvailable ? "checkmark.circle.fill" : "cpu")
                            .foregroundStyle(AdultAIService.onDeviceAvailable ? AdultActionKind.checklist.color : AdultPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Plans are generated on this device. Requires iOS, macOS or visionOS 26 and Apple Intelligence enabled.")
                            .font(.subheadline).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label(connection.hasOpenAIKey ? "OpenAI connected" : "Connect your OpenAI account", systemImage: connection.hasOpenAIKey ? "checkmark.shield.fill" : "key.fill")
                            .foregroundStyle(AdultPalette.accent).fixedSize(horizontal: false, vertical: true)
                        Text("OpenAI API usage is billed to your API account. Your task and selected guide are sent only when you ask the assistant to work.")
                            .font(.subheadline).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        SecureField(connection.hasOpenAIKey ? "Replace API key" : "Paste API key", text: $key)
                            .privacySensitive().accessibilityIdentifier("assistant-api-key")
                            #if os(iOS)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                        Button(connection.hasOpenAIKey ? "Save replacement key" : "Connect OpenAI") {
                            do { try connection.saveKey(key); key = ""; status = "Key saved in this device’s Keychain." }
                            catch { status = AdultAssistantController.message(error) }
                        }.disabled(key.isEmpty || assistant.isPrivateQA)
                        if connection.hasOpenAIKey {
                            Button(assistant.isConfiguring ? "Checking…" : "Test connection") {
                                Task {
                                    do { try await assistant.testConnection(); status = "The selected model is available to this API account." }
                                    catch { status = AdultAssistantController.message(error) }
                                }
                            }.disabled(assistant.isConfiguring || assistant.isPrivateQA)
                            Button("Disconnect OpenAI", role: .destructive) {
                                do { try connection.disconnect(); status = "OpenAI disconnected." }
                                catch { status = AdultAssistantController.message(error) }
                            }
                        }
                        Link("Get an API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        Link("OpenAI API billing", destination: URL(string: "https://platform.openai.com/settings/organization/billing/overview")!)
                        DisclosureGroup("Model") {
                            TextField("Model ID", text: $connection.model)
                                #if os(iOS)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                #endif
                            Text("Default: gpt-6-luna. Custom models must support Responses structured output; live research also requires web search.")
                                .font(.caption).fixedSize(horizontal: false, vertical: true)
                        }
                        Toggle("Research before making a plan", isOn: $connection.useWebResearch)
                            .disabled(!connection.hasOpenAIKey)
                        Text("Web research sends the task to OpenAI’s search tool and saves the answer with its sources. Additional API charges may apply.")
                            .font(.caption).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                    if let status { Text(status).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                }.listRowBackground(AdultPalette.surface)
                .disabled(assistant.isWorking || assistant.busyActionID != nil || assistant.isConfiguring)
                Section("Apply new plans automatically") {
                    Toggle(isOn: Binding(get: { assistant.library.preferences.autoReminders }, set: { enabled in
                        Task { await assistant.setAutomation(.reminder, enabled: enabled) }
                    })) { Label("Schedule reminders", systemImage: "bell.badge").foregroundStyle(AdultPalette.ink) }
                    Toggle(isOn: Binding(get: { assistant.library.preferences.autoCalendar }, set: { enabled in
                        Task { await assistant.setAutomation(.calendar, enabled: enabled) }
                    })) { Label("Add calendar events", systemImage: "calendar.badge.plus").foregroundStyle(AdultPalette.ink) }
                    Toggle("Reminder sound", isOn: Binding(get: { assistant.library.preferences.sound }, set: { sound in
                        var preferences = assistant.library.preferences
                        preferences.sound = sound
                        do { try assistant.library.savePreferences(preferences) }
                        catch { assistant.issue = AdultAssistantController.message(error) }
                    }))
                    Text("Only new plans with a future date are applied. Calendar uses your default calendar; reminders appear as app notifications. Turning these off keeps items already scheduled.")
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }.listRowBackground(AdultPalette.surface)
                .disabled(assistant.isConfiguring || assistant.isWorking || assistant.busyActionID != nil || assistant.isPrivateQA || !assistant.library.canSave)
                Section("Shortcuts") {
                    Label("Make a life plan", systemImage: "square.stack.3d.up.fill").foregroundStyle(AdultPalette.ink)
                    Text("Add this action in Apple’s Shortcuts app, choose your task, then use a personal automation to run it on your schedule. Connect your AI here first.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    Text("Scheduled reminders keep working while the app is closed. AI research runs when you ask or when Shortcuts invokes it.")
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }.listRowBackground(AdultPalette.surface)
                Section("Privacy") {
                    Label("API keys stay in this device’s Keychain", systemImage: "lock.shield")
                    Text("Saved plans stay on this device. Keys aren’t synced or included in plans. They authenticate requests directly to OpenAI. Shopping prepares a list; purchases are completed at the seller’s checkout.")
                        .font(.caption).foregroundStyle(AdultPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    Link("Privacy policy", destination: URL(string: "https://nathanfennel.com/how-to-adult/privacy.html")!)
                }.listRowBackground(AdultPalette.surface)
            }
            .scrollContentBackground(.hidden).background(AdultPalette.background)
            .foregroundStyle(AdultPalette.ink).tint(AdultPalette.accent)
            .navigationTitle("Assistant settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Couldn’t update settings", isPresented: Binding(get: { assistant.issue != nil }, set: { if !$0 { assistant.issue = nil } })) {
                Button("OK", role: .cancel) { assistant.issue = nil }
            } message: { Text(assistant.issue ?? "Try again.") }
        }
        #if os(macOS)
        .frame(minWidth: 320, idealWidth: 540, minHeight: 440)
        #endif
        .onDisappear { key = "" }
        .accessibilityIdentifier("assistant-settings-screen")
    }
}
