import XCTest
@testable import HowToAdult

final class AdultAssistantTests: XCTestCase {
    private func event(scheduledAt: Date? = Date().addingTimeInterval(3_600)) -> AdultAssistantAction {
        AdultAssistantAction(kind: .calendar, title: "Laundry", scheduledAt: scheduledAt, durationMinutes: 30)
    }

    private func plan(actions: [AdultAssistantAction]? = nil) -> AdultAssistantPlan {
        AdultAssistantPlan(title: "A calmer week", summary: "Make time for the basics.",
                           goal: "Keep the laundry under control.", provider: .onDevice, actions: actions ?? [event()])
    }

    private func evidence() throws -> AdultResearchEvidence {
        AdultResearchEvidence(text: "Use the care label to choose the wash temperature.",
            citations: [AdultAssistantCitation(title: "Care labels", url: try XCTUnwrap(URL(string: "https://example.com/care-labels")),
                                              source: .guide, guideID: "read-care-labels")], checkedAt: Date())
    }

    @MainActor private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AdultAssistantTests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func saved(_ directory: URL) throws -> AdultAssistantArchive {
        try AdultAssistantArchive.decode(Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json")))
    }

    @MainActor func testPreferencesPersistAndLegacyLibraryIsUntouched() throws {
        try withDirectory { directory in
            let legacy = directory.appendingPathComponent("UserLibrary-v1.json")
            let original = Data("preserved guide library evidence".utf8)
            try original.write(to: legacy)
            let library = AdultAssistantLibrary(directory: directory)
            XCTAssertTrue(library.canSave)
            XCTAssertFalse(library.preferences.autoReminders)
            XCTAssertFalse(library.preferences.autoCalendar)
            XCTAssertTrue(library.preferences.sound)
            var preferences = library.preferences
            preferences.autoReminders = true
            preferences.autoCalendar = true
            preferences.sound = false
            preferences.calendarIdentifier = "test-calendar"
            preferences.reminderListIdentifier = "test-list"
            try library.savePreferences(preferences)
            preferences.autoReminders = false
            preferences.autoCalendar = false
            try library.savePreferences(preferences)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertEqual(reopened.preferences, preferences)
            XCTAssertTrue(reopened.plans.isEmpty)
            XCTAssertEqual(try Data(contentsOf: legacy), original)
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)),
                           ["UserLibrary-v1.json", "AssistantLibrary-v1.json"])
        }
    }

    @MainActor func testEditableDraftRetainsItsActionIDAndCannotForgeReceipts() throws {
        try withDirectory { directory in
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan(actions: [event(scheduledAt: nil)])
            try library.add(original)
            var edited = original.actions[0]
            edited.title = "Laundry on Saturday"
            edited.scheduledAt = Date().addingTimeInterval(7_200)
            edited.durationMinutes = 45
            try library.updateDraftAction(planID: original.id, action: edited)
            XCTAssertEqual(library.plans[0].actions[0].id, original.actions[0].id)
            XCTAssertEqual(try saved(directory).plans[0].actions[0].title, edited.title)
            edited.status = .completed
            edited.externalIdentifier = "invented-receipt"
            XCTAssertThrowsError(try library.updateDraftAction(planID: original.id, action: edited))
            XCTAssertEqual(library.plans[0].actions[0].status, .pending)
            XCTAssertThrowsError(try library.updateDraftAction(planID: original.id, action: event()))
        }
    }

    @MainActor func testBeginIsDurableBeforeAnExternalAttemptAndCannotRepeat() throws {
        try withDirectory { directory in
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan()
            let actionID = original.actions[0].id
            try library.add(original)
            let snapshot = try library.beginExecution(planID: original.id, actionID: actionID)
            XCTAssertEqual(snapshot.id, actionID)
            XCTAssertEqual(snapshot.status, .running)
            XCTAssertEqual(try saved(directory).plans[0].actions[0], snapshot)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: actionID))
            XCTAssertThrowsError(try library.finishExecution(planID: original.id, actionID: actionID, externalIdentifier: " "))
            try library.finishExecution(planID: original.id, actionID: actionID, externalIdentifier: "test-native-event")
            let bytes = try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json"))
            try library.finishExecution(planID: original.id, actionID: actionID, externalIdentifier: "test-native-event")
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json")), bytes)
            XCTAssertThrowsError(try library.finishExecution(planID: original.id, actionID: actionID, externalIdentifier: "second-event"))
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: actionID))
            XCTAssertEqual(try saved(directory).plans[0].actions[0].externalIdentifier, "test-native-event")
        }
    }

    @MainActor func testIncompleteAndPastDraftDatesNeverBeginExecution() throws {
        try withDirectory { directory in
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan(actions: [event(scheduledAt: nil)])
            try library.add(original)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: original.actions[0].id)) {
                XCTAssertEqual($0 as? AdultAssistantError, .missingSchedule)
            }
            var edited = original.actions[0]
            edited.scheduledAt = Date().addingTimeInterval(-60)
            try library.updateDraftAction(planID: original.id, action: edited)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: edited.id)) {
                XCTAssertEqual($0 as? AdultAssistantError, .scheduleInPast)
            }
            edited.scheduledAt = Date().addingTimeInterval(3_600)
            edited.durationMinutes = nil
            try library.updateDraftAction(planID: original.id, action: edited)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: edited.id)) {
                XCTAssertEqual($0 as? AdultAssistantError, .missingDuration)
            }
            edited.durationMinutes = 4
            XCTAssertThrowsError(try library.updateDraftAction(planID: original.id, action: edited))
            edited.durationMinutes = 5
            try library.updateDraftAction(planID: original.id, action: edited)
            XCTAssertEqual(try library.beginExecution(planID: original.id, actionID: edited.id).durationMinutes, 5)
        }
    }

    @MainActor func testInterruptedExecutionNeedsReviewAndDoesNotAutoRetry() throws {
        try withDirectory { directory in
            let first = AdultAssistantLibrary(directory: directory)
            let original = plan()
            let actionID = original.actions[0].id
            try first.add(original)
            try first.beginExecution(planID: original.id, actionID: actionID)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertTrue(reopened.canSave)
            XCTAssertEqual(reopened.plans[0].actions[0].status, .needsReview)
            XCTAssertNotNil(reopened.plans[0].actions[0].error)
            XCTAssertEqual(try saved(directory).plans[0].actions[0].status, .needsReview)
            XCTAssertThrowsError(try reopened.beginExecution(planID: original.id, actionID: actionID))
            XCTAssertThrowsError(try reopened.updateDraftAction(planID: original.id, action: reopened.plans[0].actions[0]))
            try reopened.reviewExecution(planID: original.id, actionID: actionID, resolution: .confirmedNoEffect)
            XCTAssertEqual(reopened.plans[0].actions[0].status, .pending)
            XCTAssertNil(reopened.plans[0].actions[0].error)
            XCTAssertEqual(try reopened.beginExecution(planID: original.id, actionID: actionID).id, actionID)
        }
    }

    @MainActor func testReviewCanRecordAnExistingNativeObjectWithoutAnotherAttempt() throws {
        try withDirectory { directory in
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan()
            let actionID = original.actions[0].id
            try library.add(original)
            try library.beginExecution(planID: original.id, actionID: actionID)
            try library.failExecution(planID: original.id, actionID: actionID, error: "Service outcome is unknown.", needsReview: true)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: actionID))
            try library.reviewExecution(planID: original.id, actionID: actionID, resolution: .confirmedExisting(externalIdentifier: "verified-existing-event"))
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertEqual(reopened.plans[0].actions[0].status, .completed)
            XCTAssertEqual(reopened.plans[0].actions[0].externalIdentifier, "verified-existing-event")
            XCTAssertThrowsError(try reopened.beginExecution(planID: original.id, actionID: actionID))
        }
    }

    @MainActor func testKnownNoEffectFailureCanBeEditedAndExplicitlyRetried() throws {
        try withDirectory { directory in
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan()
            let actionID = original.actions[0].id
            try library.add(original)
            try library.beginExecution(planID: original.id, actionID: actionID)
            try library.failExecution(planID: original.id, actionID: actionID, error: "Permission was denied before writing.", needsReview: false)
            XCTAssertEqual(library.plans[0].actions[0].status, .failed)
            var edited = library.plans[0].actions[0]
            edited.title = "Try with the selected calendar"
            try library.updateDraftAction(planID: original.id, action: edited)
            XCTAssertEqual(library.plans[0].actions[0].id, actionID)
            XCTAssertNil(library.plans[0].actions[0].error)
            try library.beginExecution(planID: original.id, actionID: actionID)
            XCTAssertThrowsError(try library.failExecution(planID: original.id, actionID: actionID, error: "", needsReview: false))
            XCTAssertEqual(library.plans[0].actions[0].status, .running)
        }
    }

    @MainActor func testLocalCompletionRecordsPreparationAndNeverClaimsAPurchase() throws {
        try withDirectory { directory in
            let actions = [
                AdultAssistantAction(kind: .shopping, title: "Laundry supplies", items: ["Detergent"]),
                AdultAssistantAction(kind: .checklist, title: "Before washing", items: ["Check the care label"]),
                AdultAssistantAction(kind: .research, title: "Read care advice", query: "fabric care symbols")
            ]
            let original = plan(actions: actions)
            let library = AdultAssistantLibrary(directory: directory)
            try library.add(original)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: actions[0].id))
            XCTAssertThrowsError(try library.completeLocalAction(planID: original.id, actionID: actions[0].id, completion: .checklistChecked))
            try library.completeLocalAction(planID: original.id, actionID: actions[0].id, completion: .shoppingListPrepared)
            try library.completeLocalAction(planID: original.id, actionID: actions[1].id, completion: .checklistChecked)
            XCTAssertThrowsError(try library.completeLocalAction(planID: original.id, actionID: actions[2].id, completion: .researchOpened))
            try library.completeResearchAction(planID: original.id, actionID: actions[2].id, evidence: evidence())
            let before = try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json"))
            try library.completeLocalAction(planID: original.id, actionID: actions[0].id, completion: .shoppingListPrepared)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json")), before)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertEqual(reopened.plans[0].actions.map(\.localCompletion), [.shoppingListPrepared, .checklistChecked, .researchOpened])
            XCTAssertTrue(reopened.plans[0].actions.allSatisfy { $0.externalIdentifier == nil && $0.status == .completed })
        }
    }

    @MainActor func testOriginalResearchAnswerAndCompletionAreSavedTogether() throws {
        try withDirectory { directory in
            let action = AdultAssistantAction(kind: .research, title: "Care labels", query: "fabric care symbols")
            let original = plan(actions: [action])
            let library = AdultAssistantLibrary(directory: directory)
            try library.add(original)
            let sourced = try evidence()
            var invalid = sourced
            invalid.citations = []
            XCTAssertThrowsError(try library.completeResearchAction(planID: original.id, actionID: action.id, evidence: invalid))
            XCTAssertEqual(library.plans, [original])
            try library.completeResearchAction(planID: original.id, actionID: action.id, evidence: sourced)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertNil(reopened.plans[0].researchEvidence)
            XCTAssertEqual(reopened.plans[0].actions[0].researchEvidence, sourced)
            XCTAssertEqual(reopened.plans[0].citations, sourced.citations)
            XCTAssertEqual(reopened.plans[0].actions[0].localCompletion, .researchOpened)
            XCTAssertNil(reopened.plans[0].actions[0].externalIdentifier)
            let bytes = try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json"))
            try library.completeResearchAction(planID: original.id, actionID: action.id, evidence: sourced)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json")), bytes)
        }
    }

    @MainActor func testSeparateResearchAnswersPreserveInitialPlanEvidenceAndReload() throws {
        try withDirectory { directory in
            let firstAction = AdultAssistantAction(kind: .research, title: "Wash temperature", query: "wash temperature")
            let secondAction = AdultAssistantAction(kind: .research, title: "Dry temperature", query: "dry temperature")
            let initial = try evidence()
            let washSource = AdultAssistantCitation(title: "Wash guidance", url: try XCTUnwrap(URL(string: "https://example.com/wash")), source: .webAnnotation)
            let drySource = AdultAssistantCitation(title: "Dry guidance", url: try XCTUnwrap(URL(string: "https://example.com/dry")), source: .webAnnotation)
            let first = AdultResearchEvidence(text: "The original washing answer.", citations: initial.citations + [washSource], checkedAt: Date())
            let second = AdultResearchEvidence(text: "The original drying answer.", citations: [washSource, drySource], checkedAt: Date())
            var original = plan(actions: [firstAction, secondAction])
            original.researchEvidence = initial
            original.citations = initial.citations
            let library = AdultAssistantLibrary(directory: directory)
            try library.add(original)
            XCTAssertThrowsError(try library.completeLocalAction(planID: original.id, actionID: firstAction.id, completion: .researchOpened),
                                 "Plan-wide evidence must not be substituted for this action’s missing answer.")
            try library.completeResearchAction(planID: original.id, actionID: firstAction.id, evidence: first)
            try library.completeResearchAction(planID: original.id, actionID: secondAction.id, evidence: second)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertEqual(reopened.plans[0].researchEvidence, initial)
            XCTAssertEqual(reopened.plans[0].actions[0].researchEvidence, first)
            XCTAssertEqual(reopened.plans[0].actions[1].researchEvidence, second)
            XCTAssertEqual(reopened.plans[0].citations, initial.citations + [washSource, drySource])
            let bytes = try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json"))
            try reopened.completeResearchAction(planID: original.id, actionID: firstAction.id, evidence: first)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json")), bytes,
                           "An earlier action’s receipt remains idempotent after another action completes.")
        }
    }

    @MainActor func testShoppingResearchKeepsPreparationPendingAndRetainsItsOwnSources() throws {
        try withDirectory { directory in
            let shopping = AdultAssistantAction(kind: .shopping, title: "Laundry supplies", items: ["Detergent"], query: "laundry detergent")
            let original = plan(actions: [shopping, event()])
            let library = AdultAssistantLibrary(directory: directory)
            try library.add(original)
            let sourced = try evidence()
            try library.saveActionResearch(planID: original.id, actionID: shopping.id, evidence: sourced)
            let reopened = AdultAssistantLibrary(directory: directory)
            let savedAction = reopened.plans[0].actions[0]
            XCTAssertEqual(savedAction.researchEvidence, sourced)
            XCTAssertEqual(savedAction.status, .pending)
            XCTAssertNil(savedAction.localCompletion)
            XCTAssertNil(savedAction.externalIdentifier)
            XCTAssertNil(reopened.plans[0].researchEvidence)
            XCTAssertEqual(reopened.plans[0].citations, sourced.citations)
            XCTAssertThrowsError(try reopened.completeResearchAction(planID: original.id, actionID: shopping.id, evidence: sourced))
            XCTAssertThrowsError(try reopened.saveActionResearch(planID: original.id, actionID: original.actions[1].id, evidence: sourced))
            var invalid = sourced
            invalid.citations = []
            XCTAssertThrowsError(try reopened.saveActionResearch(planID: original.id, actionID: shopping.id, evidence: invalid))
            XCTAssertEqual(reopened.plans[0].actions[0].researchEvidence, sourced)
            try reopened.completeLocalAction(planID: original.id, actionID: shopping.id, completion: .shoppingListPrepared)
            XCTAssertThrowsError(try reopened.saveActionResearch(planID: original.id, actionID: shopping.id, evidence: sourced))
            XCTAssertEqual(try saved(directory).plans[0].actions[0].researchEvidence, sourced)
            XCTAssertNil(try saved(directory).plans[0].actions[0].externalIdentifier)
        }
    }

    @MainActor func testResearchAggregateCitationsFitMultipleAnswersAndRemainBounded() throws {
        let sources = try (0..<651).map { index in
            AdultAssistantCitation(title: "Source \(index)", url: try XCTUnwrap(URL(string: "https://example.com/source/\(index)")), source: .webAnnotation)
        }
        var maximum = plan()
        maximum.citations = Array(sources.prefix(650))
        XCTAssertNoThrow(try maximum.validate())
        maximum.citations.append(sources[650])
        XCTAssertThrowsError(try maximum.validate())
        XCTAssertThrowsError(try AdultResearchEvidence(text: "Too many sources in one answer.", citations: Array(sources.prefix(51)), checkedAt: Date()).validate())
        try withDirectory { directory in
            let research = AdultAssistantAction(kind: .research, title: "Read sources", query: "care labels")
            var original = plan(actions: [research])
            let initial = AdultResearchEvidence(text: "Initial answer.", citations: Array(sources.prefix(50)), checkedAt: Date())
            original.researchEvidence = initial
            original.citations = initial.citations
            let answer = AdultResearchEvidence(text: "Action answer.", citations: Array(sources[50..<100]), checkedAt: Date())
            let library = AdultAssistantLibrary(directory: directory)
            try library.add(original)
            try library.completeResearchAction(planID: original.id, actionID: research.id, evidence: answer)
            XCTAssertEqual(try saved(directory).plans[0].citations.count, 100)
            XCTAssertEqual(try saved(directory).plans[0].researchEvidence, initial)
        }
    }

    @MainActor func testRemovingOneLocalPlanPreservesOtherPlansAndGuideFile() throws {
        try withDirectory { directory in
            let legacy = directory.appendingPathComponent("UserLibrary-v1.json")
            let guideBytes = Data("preserved guide file evidence".utf8)
            try guideBytes.write(to: legacy)
            let library = AdultAssistantLibrary(directory: directory)
            let kept = plan()
            let selected = plan()
            try library.add(kept)
            try library.add(selected)
            try library.beginExecution(planID: selected.id, actionID: selected.actions[0].id)
            XCTAssertThrowsError(try library.remove(planID: selected.id)) {
                XCTAssertEqual($0 as? AdultAssistantError, .executionInProgress)
            }
            try library.failExecution(planID: selected.id, actionID: selected.actions[0].id, error: "Unknown test service outcome.", needsReview: true)
            // This call represents the UI’s explicit confirmation to discard local review receipts.
            try library.remove(planID: selected.id)
            XCTAssertEqual(library.plans, [kept])
            XCTAssertEqual(AdultAssistantLibrary(directory: directory).plans, [kept])
            XCTAssertEqual(try Data(contentsOf: legacy), guideBytes)
            XCTAssertThrowsError(try library.remove(planID: selected.id))
        }
    }

    @MainActor func testPlanRemovalFreesCapacityBeforeAddingAnotherPlan() throws {
        try withDirectory { directory in
            let original = (0..<100).map { _ in plan() }
            let file = directory.appendingPathComponent("AssistantLibrary-v1.json")
            let bytes = try JSONEncoder().encode(AdultAssistantArchive(plans: original))
            try bytes.write(to: file)
            let library = AdultAssistantLibrary(directory: directory)
            XCTAssertTrue(library.canSave)
            let newPlan = plan()
            XCTAssertThrowsError(try library.add(newPlan))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            try library.remove(planID: original[50].id)
            try library.add(newPlan)
            let expectedIDs = Set(original.map(\.id)).subtracting([original[50].id]).union([newPlan.id])
            XCTAssertEqual(Set(try saved(directory).plans.map(\.id)), expectedIDs)
            XCTAssertEqual(library.plans.count, 100)
        }
    }

    func testResearchEvidenceBoundsAndMissingOptionalFieldCompatibility() throws {
        var invalid = try evidence()
        invalid.text = String(repeating: "a", count: 32_001)
        XCTAssertThrowsError(try invalid.validate())
        invalid = try evidence()
        invalid.checkedAt = Date(timeIntervalSince1970: .nan)
        XCTAssertThrowsError(try invalid.validate())
        let original = plan()
        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "researchEvidence")
        let decoded = try JSONDecoder().decode(AdultAssistantPlan.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.researchEvidence)
        let action = original.actions[0]
        var actionObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(action)) as? [String: Any])
        actionObject.removeValue(forKey: "researchEvidence")
        XCTAssertEqual(try JSONDecoder().decode(AdultAssistantAction.self, from: JSONSerialization.data(withJSONObject: actionObject)), action)
        var wrongKind = event()
        wrongKind.researchEvidence = try evidence()
        XCTAssertThrowsError(try wrongKind.validate())
    }

    @MainActor func testCorruptAndUnsupportedStoragePreservesOriginalBytes() throws {
        let unsupported = try JSONEncoder().encode(AdultAssistantArchive(schemaVersion: 99))
        for original in [Data("corrupt personal plan evidence".utf8), unsupported] {
            try withDirectory { directory in
                let url = directory.appendingPathComponent("AssistantLibrary-v1.json")
                try original.write(to: url)
                let library = AdultAssistantLibrary(directory: directory)
                XCTAssertFalse(library.canSave)
                XCTAssertNotNil(library.storageIssue)
                XCTAssertThrowsError(try library.add(plan()))
                XCTAssertEqual(try Data(contentsOf: url), original)
            }
        }
    }

    func testPlanActionAndGlobalIdentifierBounds() throws {
        var twelve = plan(actions: (0..<12).map { _ in event() })
        XCTAssertNoThrow(try twelve.validate())
        twelve.actions.append(event())
        XCTAssertThrowsError(try twelve.validate())
        var archive = AdultAssistantArchive(plans: (0..<100).map { _ in plan() })
        XCTAssertNoThrow(try archive.validate())
        archive.plans.append(plan())
        XCTAssertThrowsError(try archive.validate())
        let duplicate = event()
        archive = AdultAssistantArchive(plans: [plan(actions: [duplicate]), plan(actions: [duplicate])])
        XCTAssertThrowsError(try archive.validate()) {
            XCTAssertEqual($0 as? AdultAssistantError, .duplicateIdentifier)
        }
        let samePlan = plan()
        XCTAssertThrowsError(try AdultAssistantArchive(plans: [samePlan, samePlan]).validate())
    }

    func testDatesAndDurationMustBeFiniteAndBounded() throws {
        var action = event()
        action.scheduledAt = Date(timeIntervalSince1970: .nan)
        XCTAssertThrowsError(try action.validate())
        action.scheduledAt = Date.distantFuture
        XCTAssertThrowsError(try action.validate())
        action.scheduledAt = nil
        action.durationMinutes = 1_440
        XCTAssertNoThrow(try action.validate())
        action.durationMinutes = 1_441
        XCTAssertThrowsError(try action.validate())
        action.durationMinutes = 4
        XCTAssertThrowsError(try action.validate())
        action.durationMinutes = nil
        XCTAssertNoThrow(try action.validate())
        action.updatedAt = Date(timeIntervalSince1970: .infinity)
        XCTAssertThrowsError(try action.validate())
    }

    func testCitationsRequireSecureURLsAndExplicitSourceProvenance() throws {
        let secure = try XCTUnwrap(URL(string: "https://example.com/verified-source"))
        XCTAssertNoThrow(try AdultAssistantCitation(title: "Guide source", url: secure, source: .guide, guideID: "read-care-labels").validate())
        XCTAssertNoThrow(try AdultAssistantCitation(title: "Web annotation", url: secure, source: .webAnnotation).validate())
        XCTAssertThrowsError(try AdultAssistantCitation(title: "Missing guide", url: secure, source: .guide).validate())
        XCTAssertThrowsError(try AdultAssistantCitation(title: "Wrong provenance", url: secure, source: .webAnnotation, guideID: "read-care-labels").validate())
        for address in ["http://example.com/source", "https://fixture-user:fixture-pass@example.com/source", "file:///fixture/source"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertThrowsError(try AdultAssistantCitation(title: "Unsafe URL", url: url, source: .webAnnotation).validate())
        }
    }

    @MainActor func testOversizedLibraryCannotBeOverwritten() throws {
        try withDirectory { directory in
            let original = Data(repeating: 32, count: AdultAssistantValidation.maximumBytes + 1)
            let url = directory.appendingPathComponent("AssistantLibrary-v1.json")
            try original.write(to: url)
            XCTAssertThrowsError(try AdultAssistantArchive.decode(original)) {
                XCTAssertEqual($0 as? AdultAssistantError, .tooLarge)
            }
            let library = AdultAssistantLibrary(directory: directory)
            XCTAssertFalse(library.canSave)
            XCTAssertThrowsError(try library.add(plan()))
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    @MainActor func testWriteFailureRollsBackBeginAndPreferences() throws {
        try withDirectory { container in
            let directory = container.appendingPathComponent("library", isDirectory: true)
            let preserved = container.appendingPathComponent("preserved", isDirectory: true)
            let library = AdultAssistantLibrary(directory: directory)
            let research = AdultAssistantAction(kind: .research, title: "Care labels", query: "fabric care symbols")
            let original = plan(actions: [event(), research])
            try library.add(original)
            let bytes = try Data(contentsOf: directory.appendingPathComponent("AssistantLibrary-v1.json"))
            try FileManager.default.moveItem(at: directory, to: preserved)
            try Data("private write failure fixture".utf8).write(to: directory)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: original.actions[0].id)) {
                XCTAssertEqual($0 as? AdultAssistantError, .writeFailed)
            }
            XCTAssertEqual(library.plans, [original])
            var preferences = library.preferences
            preferences.autoCalendar = true
            XCTAssertThrowsError(try library.savePreferences(preferences))
            XCTAssertFalse(library.preferences.autoCalendar)
            XCTAssertThrowsError(try library.completeResearchAction(planID: original.id, actionID: research.id, evidence: evidence()))
            XCTAssertThrowsError(try library.saveActionResearch(planID: original.id, actionID: research.id, evidence: evidence()))
            XCTAssertThrowsError(try library.remove(planID: original.id))
            XCTAssertEqual(library.plans, [original])
            XCTAssertNil(library.plans[0].researchEvidence)
            XCTAssertNil(library.plans[0].actions[1].researchEvidence)
            XCTAssertEqual(try Data(contentsOf: preserved.appendingPathComponent("AssistantLibrary-v1.json")), bytes)
            XCTAssertNotNil(library.storageIssue)
        }
    }

    @MainActor func testFailedReceiptSavePreservesRunningAndRequiresReviewOnReload() throws {
        try withDirectory { container in
            let directory = container.appendingPathComponent("library", isDirectory: true)
            let preserved = container.appendingPathComponent("preserved", isDirectory: true)
            let library = AdultAssistantLibrary(directory: directory)
            let original = plan()
            let actionID = original.actions[0].id
            try library.add(original)
            try library.beginExecution(planID: original.id, actionID: actionID)
            try FileManager.default.moveItem(at: directory, to: preserved)
            try Data("private write failure fixture".utf8).write(to: directory)
            XCTAssertThrowsError(try library.finishExecution(planID: original.id, actionID: actionID, externalIdentifier: "actual-test-receipt"))
            XCTAssertEqual(library.plans[0].actions[0].status, .running)
            XCTAssertEqual(try saved(preserved).plans[0].actions[0].status, .running)
            XCTAssertThrowsError(try library.beginExecution(planID: original.id, actionID: actionID))
            try FileManager.default.removeItem(at: directory)
            try FileManager.default.moveItem(at: preserved, to: directory)
            let reopened = AdultAssistantLibrary(directory: directory)
            XCTAssertEqual(reopened.plans[0].actions[0].status, .needsReview)
            try reopened.reviewExecution(planID: original.id, actionID: actionID, resolution: .confirmedExisting(externalIdentifier: "actual-test-receipt"))
            XCTAssertEqual(try saved(directory).plans[0].actions[0].externalIdentifier, "actual-test-receipt")
        }
    }

    @MainActor func testNonFileAndBlockedDirectoryNeverBecomeWritableStorage() throws {
        let remote = AdultAssistantLibrary(directory: try XCTUnwrap(URL(string: "https://example.com/no-storage")))
        XCTAssertFalse(remote.canSave)
        XCTAssertThrowsError(try remote.add(plan()))
        try withDirectory { directory in
            let blocked = directory.appendingPathComponent("not-a-directory")
            try Data("private fixture".utf8).write(to: blocked)
            let library = AdultAssistantLibrary(directory: blocked)
            XCTAssertFalse(library.canSave)
            XCTAssertThrowsError(try library.add(plan()))
        }
    }
}
