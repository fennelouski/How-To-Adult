import Foundation
import XCTest
@testable import HowToAdult

/// These tests inject every response. They never construct a connection, read Keychain,
/// contact a provider or invoke the on-device model.
final class AdultAIServiceTests: XCTestCase {
    private let fixtureKey = "offline-fixture-not-an-api-key"
    private let selectedModel = "offline-selected-model"
    private let now = Date(timeIntervalSince1970: 1_791_115_200)

    private func action(kind: String = "checklist") -> [String: Any] {
        ["kind": kind, "title": "Read the care label", "details": "Check temperature and cycle.",
         "scheduledAt": NSNull(), "durationMinutes": NSNull(), "repeatRule": "none",
         "items": ["Read the care label"], "query": NSNull()]
    }

    private func draft(actions: [[String: Any]]? = nil) throws -> String {
        let object: [String: Any] = ["title": "Laundry without surprises", "summary": "Start with the care label.",
                                     "actions": actions ?? [action()]]
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func citation(_ url: String = "https://example.org/care-labels", title: String = "Care labels",
                          start: Int = 0, end: Int = 8) -> [String: Any] {
        ["type": "url_citation", "url": url, "title": title, "start_index": start, "end_index": end]
    }

    private func response(text: String, annotations: [[String: Any]] = [], status: String = "completed",
                          searchStatus: String? = nil, extraContent: [[String: Any]] = []) throws -> Data {
        var output: [[String: Any]] = []
        if let searchStatus { output.append(["type": "web_search_call", "id": "offline-search", "status": searchStatus]) }
        output.append(["type": "message", "role": "assistant", "content":
                        [["type": "output_text", "text": text, "annotations": annotations]] + extraContent])
        return try JSONSerialization.data(withJSONObject: ["status": status, "output": output])
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    private func generate(_ service: AdultAIService, goal: String = "Help me wash this shirt", guide: AdultArticle? = nil,
                          research: Bool = false) async throws -> AdultAssistantPlan {
        try await service.makePlan(goal: goal, guide: guide, provider: .openAI, model: selectedModel,
                                   key: fixtureKey, research: research, now: now)
    }

    private func assertRejected(file: StaticString = #filePath, line: UInt = #line,
                                operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("Invalid provider data must not produce a usable plan or research result.", file: file, line: line)
        } catch {}
    }

    private func assertAIError(_ expected: AdultAIConnectionError, file: StaticString = #filePath, line: UInt = #line,
                               operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("Expected a provider error before returning a result.", file: file, line: line)
        } catch let actual as AdultAIConnectionError {
            switch (expected, actual) {
            case (.invalidInput, .invalidInput), (.invalidResponse, .invalidResponse), (.refused, .refused),
                 (.noKey, .noKey), (.quota, .quota), (.invalidKey, .invalidKey), (.network, .network),
                 (.storage, .storage), (.unavailable, .unavailable): break
            default: XCTFail("Expected \(expected), got \(actual).", file: file, line: line)
            }
        } catch {
            XCTFail("Expected \(expected), got \(error).", file: file, line: line)
        }
    }

    func testPlanRequestUsesSelectedModelPrivateResponsesAndStrictNullableSchema() async throws {
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft()))])
        let plan = try await generate(AdultAIService(transport: transport))
        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + fixtureKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertFalse(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self).contains(fixtureKey))
        let body = try requestBody(request)
        XCTAssertEqual(body["model"] as? String, selectedModel)
        XCTAssertEqual(body["store"] as? Bool, false)
        let format = try XCTUnwrap((body["text"] as? [String: Any])?["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(format["strict"] as? Bool, true)
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual(Set(try XCTUnwrap(schema["required"] as? [String])), ["title", "summary", "actions"])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let actions = try XCTUnwrap(properties["actions"] as? [String: Any])
        let item = try XCTUnwrap(actions["items"] as? [String: Any])
        XCTAssertEqual(item["additionalProperties"] as? Bool, false)
        XCTAssertEqual(Set(try XCTUnwrap(item["required"] as? [String])),
                       ["kind", "title", "details", "scheduledAt", "durationMinutes", "repeatRule", "items", "query"])
        let fields = try XCTUnwrap(item["properties"] as? [String: Any])
        XCTAssertEqual(Set(try XCTUnwrap((fields["kind"] as? [String: Any])?["enum"] as? [String])),
                       ["reminder", "calendar", "research", "shopping", "checklist"])
        for name in ["scheduledAt", "durationMinutes", "query"] {
            XCTAssertTrue(try XCTUnwrap((fields[name] as? [String: Any])?["type"] as? [String]).contains("null"))
        }
        XCTAssertEqual(plan.provider, .openAI)
        XCTAssertEqual(plan.createdAt, now)
        XCTAssertEqual(plan.actions.first?.status, .pending)
        XCTAssertNil(plan.actions.first?.externalIdentifier)
        XCTAssertNil(plan.researchEvidence)
    }

    func testGeneratedRecurrenceOnlyAppliesToCalendarAndReminder() async throws {
        let kinds = ["calendar", "reminder", "checklist", "research", "shopping"]
        let actions = kinds.map { kind in
            var item = action(kind: kind)
            item["repeatRule"] = "weekly"
            if kind == "calendar" { item["durationMinutes"] = 30 }
            if kind == "research" { item["query"] = "Laundry care labels" }
            return item
        }
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft(actions: actions)))])
        let plan = try await generate(AdultAIService(transport: transport))
        XCTAssertEqual(plan.actions.map(\.kind.rawValue), kinds)
        XCTAssertEqual(plan.actions.map(\.repeatRule), [.weekly, .weekly, .none, .none, .none])
        for item in plan.actions {
            XCTAssertEqual(item.title, "Read the care label")
            XCTAssertEqual(item.details, "Check temperature and cycle.")
            XCTAssertEqual(item.items, ["Read the care label"])
            XCTAssertEqual(item.status, .pending)
            XCTAssertNil(item.scheduledAt)
            XCTAssertNil(item.externalIdentifier)
        }
        XCTAssertEqual(plan.actions[0].durationMinutes, 30)
        XCTAssertEqual(plan.actions[3].query, "Laundry care labels")
        try plan.validate()

        var invalid = action()
        invalid["repeatRule"] = "whenever"
        let invalidTransport = AdultOfflineAITransport([.bytes(try response(text: draft(actions: [invalid])))])
        await assertAIError(.invalidResponse) {
            _ = try await self.generate(AdultAIService(transport: invalidTransport))
        }
        let stored = AdultAssistantAction(kind: .checklist, title: "Laundry", repeatRule: .weekly,
                                           items: ["Read the care label"], updatedAt: now)
        XCTAssertThrowsError(try stored.validate()) { error in
            XCTAssertEqual(error as? AdultAssistantError, .invalidAction)
        }
    }

    func testGeneratedResearchDerivesMissingQueryWithoutRelaxingStoredValidation() async throws {
        var research = action(kind: "research")
        research["title"] = "Simple Dinner Ideas"
        research["details"] = "Research quick and easy dinner recipes for one person."
        research["items"] = ["spaghetti with tomato sauce", "grilled chicken with vegetables", "vegetable stir-fry"]
        var shopping = action(kind: "shopping")
        shopping["items"] = ["spaghetti", "tomato sauce", "chicken breast", "vegetables", "cooking oil"]
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft(actions: [research, shopping])))])
        let plan = try await generate(AdultAIService(transport: transport))
        XCTAssertEqual(plan.actions[0].query, "Simple Dinner Ideas Research quick and easy dinner recipes for one person.")
        XCTAssertEqual(plan.actions[0].items, research["items"] as? [String])
        XCTAssertNil(plan.actions[1].query)
        XCTAssertTrue(plan.actions.allSatisfy { $0.status == .pending && $0.externalIdentifier == nil })
        try plan.validate()
        var stored = plan.actions[0]
        stored.query = nil
        XCTAssertThrowsError(try stored.validate()) { error in
            XCTAssertEqual(error as? AdultAssistantError, .invalidAction)
        }
    }

    func testGuideContextRetainsJurisdictionCautionsAndVerifiedGuideProvenance() async throws {
        let guide = AdultArticle(id: "read-care-labels", title: "Read care labels", summary: "Choose the right cycle.",
                                 categoryID: "home", symbol: "tshirt", minutes: 5, jurisdiction: "United States",
                                 updatedAt: "2026-10-04", tags: [], tools: [],
                                 steps: [GuideStep(id: "label", title: "Read the label", body: "Do not ignore the label.")],
                                 cautions: ["Separate incompatible fabrics."],
                                 sources: [GuideSource(title: "Original care guide", url: "https://example.org/care-labels")])
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft()))])
        let plan = try await generate(AdultAIService(transport: transport), guide: guide)
        let requests = await transport.capturedRequests()
        let body = try requestBody(XCTUnwrap(requests.first))
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])
        let text = try XCTUnwrap(content.first?["text"] as? String)
        let context = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String])
        XCTAssertEqual(context["goal"], "Help me wash this shirt")
        XCTAssertTrue(try XCTUnwrap(context["guide"]).contains(guide.jurisdiction))
        XCTAssertTrue(try XCTUnwrap(context["guide"]).contains(guide.cautions[0]))
        XCTAssertTrue(try XCTUnwrap(context["guide"]).contains(guide.sources[0].url))
        XCTAssertEqual(plan.sourceGuideID, guide.id)
        XCTAssertEqual(plan.citations.count, 1)
        let savedSource = try XCTUnwrap(plan.citations.first)
        XCTAssertEqual(savedSource.source, .guide)
        XCTAssertEqual(savedSource.guideID, guide.id)
        XCTAssertEqual(savedSource.url.absoluteString, guide.sources[0].url)
    }

    func testRefusalRejectsEvenAnOtherwiseValidPlan() async throws {
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft(), extraContent:
            [["type": "refusal", "refusal": "I cannot help with that request."]]))])
        await assertAIError(.refused) { _ = try await self.generate(AdultAIService(transport: transport)) }
        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testIncompleteFailedAndEmptyProviderResponsesNeverBecomePlans() async throws {
        let responses = try [response(text: draft(), status: "incomplete"),
                             response(text: draft(), status: "failed"), response(text: "")]
        for data in responses {
            let transport = AdultOfflineAITransport([.bytes(data)])
            await assertAIError(.invalidResponse) { _ = try await self.generate(AdultAIService(transport: transport)) }
        }
    }

    func testMalformedAndSemanticallyInvalidDraftsAreRejected() async throws {
        var badKind = action(); badKind["kind"] = "place_order"
        var badRepeat = action(); badRepeat["repeatRule"] = "whenever"
        var badDate = action(kind: "reminder"); badDate["scheduledAt"] = "tomorrow morning"
        var badDuration = action(kind: "calendar"); badDuration["durationMinutes"] = 4
        var missingItems = action(kind: "shopping"); missingItems["items"] = []
        var blankQuery = action(kind: "research"); blankQuery["query"] = " \n "
        var blankTitle = action(); blankTitle["title"] = " \n "
        var missingField = action(); missingField.removeValue(forKey: "kind")
        let invalidTexts = try ["{not-json}", "```json\n" + draft() + "\n```", draft(actions: []),
                                draft(actions: Array(repeating: action(), count: 13)),
                                draft(actions: [badKind]), draft(actions: [badRepeat]), draft(actions: [badDate]),
                                draft(actions: [badDuration]), draft(actions: [missingItems]), draft(actions: [blankQuery]),
                                draft(actions: [blankTitle]), draft(actions: [missingField])]
        for text in invalidTexts {
            let transport = AdultOfflineAITransport([.bytes(try response(text: text))])
            await assertRejected { _ = try await self.generate(AdultAIService(transport: transport)) }
        }
    }

    func testFractionalDatesAndUnknownTimingRemainDraftsWithoutExecutionReceipts() async throws {
        var calendar = action(kind: "calendar")
        calendar["scheduledAt"] = "2026-10-05T09:30:00.125+02:00"
        calendar["durationMinutes"] = 30
        calendar["items"] = []
        // Provider-supplied execution claims are outside the draft contract and must never become native receipts.
        calendar["status"] = "completed"
        calendar["externalIdentifier"] = "provider-invented-event"
        var reminder = action(kind: "reminder"); reminder["items"] = []
        let transport = AdultOfflineAITransport([.bytes(try response(text: draft(actions: [calendar, reminder])))])
        let plan = try await generate(AdultAIService(transport: transport))
        let first = try XCTUnwrap(plan.actions.first)
        let expected = Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)), year: 2026, month: 10, day: 5, hour: 7, minute: 30))
        XCTAssertEqual(try XCTUnwrap(first.scheduledAt).timeIntervalSince1970,
                       try XCTUnwrap(expected).timeIntervalSince1970 + 0.125, accuracy: 0.001)
        XCTAssertNil(plan.actions[1].scheduledAt)
        XCTAssertTrue(plan.actions.allSatisfy { $0.status == .pending && $0.externalIdentifier == nil && $0.localCompletion == nil })
    }

    func testResearchRequiresSearchAndStoresOnlyActualSecureAnnotationProvenance() async throws {
        let text = "🧺 Read the care label. label [Unverified prose link](https://invented.example/product)."
        let annotations = [citation(start: 16, end: 21), citation(title: "Duplicate title", start: 23, end: 28),
                           ["type": "file_citation", "url": "https://invented.example/file", "title": "Not a web annotation"]]
        let transport = AdultOfflineAITransport([.bytes(try response(text: text, annotations: annotations, searchStatus: "completed"))])
        let result = try await AdultAIService(transport: transport).research(goal: "Research laundry care", model: selectedModel, key: fixtureKey)
        let requests = await transport.capturedRequests()
        let body = try requestBody(XCTUnwrap(requests.first))
        XCTAssertEqual(body["model"] as? String, selectedModel)
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["tool_choice"] as? String, "required")
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?["type"] as? String, "web_search")
        XCTAssertEqual(result.text, "🧺 Read the care [label](https://example.org/care-labels). [label](https://example.org/care-labels) [Unverified prose link](https://invented.example/product).")
        XCTAssertEqual(result.citations.count, 1)
        let source = try XCTUnwrap(result.citations.first)
        XCTAssertEqual(source.url.absoluteString, "https://example.org/care-labels")
        XCTAssertEqual(source.title, "Care labels")
        XCTAssertEqual(source.source, .webAnnotation)
        XCTAssertNil(source.guideID)
    }

    func testResearchRejectsMissingOrIncompleteSearchAndCitationFreeProse() async throws {
        let responses = try [response(text: "Cited text", annotations: [citation()]),
                             response(text: "Cited text", annotations: [citation()], searchStatus: "in_progress"),
                             response(text: "[Generated link](https://example.org/care-labels)", searchStatus: "completed"),
                             response(text: "Untrusted source", annotations: [citation("http://example.org/care-labels")], searchStatus: "completed")]
        for data in responses {
            let transport = AdultOfflineAITransport([.bytes(data)])
            await assertAIError(.invalidResponse) {
                _ = try await AdultAIService(transport: transport).research(goal: "Laundry care", model: self.selectedModel, key: self.fixtureKey)
            }
        }
    }

    func testCitationOffsetsUseUnicodeScalarsAndPreserveUncitedCharacters() async throws {
        // Thirteen scalars, twelve graphemes and fourteen UTF-16 units. The cited word is scalars 8..<13.
        let text = "🧺 Cafe\u{301} label"
        let transport = AdultOfflineAITransport([.bytes(try response(text: text,
            annotations: [citation(start: 8, end: 13)], searchStatus: "completed"))])
        let result = try await AdultAIService(transport: transport).research(goal: "Care labels", model: selectedModel, key: fixtureKey)
        XCTAssertEqual(result.text, "🧺 Cafe\u{301} [label](https://example.org/care-labels)")
        XCTAssertEqual(result.citations.count, 1)
    }

    func testMultipleOutOfOrderAndAdjacentCitationSpansRetainTheirOwnLinks() async throws {
        let alpha = "https://example.org/alpha"
        let beta = "https://example.org/beta"
        let transport = AdultOfflineAITransport([
            .bytes(try response(text: "🧺 Alpha Beta.", annotations: [
                citation(beta, title: "Beta", start: 8, end: 12),
                citation(alpha, title: "Alpha", start: 2, end: 7)
            ], searchStatus: "completed")),
            .bytes(try response(text: "A🧺B", annotations: [
                citation(beta, title: "B", start: 2, end: 3),
                citation(alpha, title: "A", start: 0, end: 1),
                citation(start: 1, end: 2)
            ], searchStatus: "completed"))
        ])
        let service = AdultAIService(transport: transport)
        let separated = try await service.research(goal: "Care labels", model: selectedModel, key: fixtureKey)
        XCTAssertEqual(separated.text, "🧺 [Alpha](https://example.org/alpha) [Beta](https://example.org/beta).")
        XCTAssertEqual(Set(separated.citations.map { $0.url.absoluteString }), [alpha, beta])
        let adjacent = try await service.research(goal: "Care labels", model: selectedModel, key: fixtureKey)
        XCTAssertEqual(adjacent.text, "[A](https://example.org/alpha)[🧺](https://example.org/care-labels)[B](https://example.org/beta)")
        XCTAssertEqual(adjacent.citations.count, 3)
    }

    func testCitationMarkdownEscapingPreservesVisibleBracketsBackslashAndDestinationParentheses() async throws {
        let text = #"Use [A]\B now."#
        let transport = AdultOfflineAITransport([.bytes(try response(text: text, annotations:
            [citation("https://example.org/source(a)", start: 4, end: 9)], searchStatus: "completed"))])
        let result = try await AdultAIService(transport: transport).research(goal: "Care labels", model: selectedModel, key: fixtureKey)
        let rendered = try AttributedString(markdown: result.text,
                                           options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        XCTAssertEqual(String(rendered.characters), text)
        let linkedRuns = rendered.runs.compactMap { run -> (String, URL)? in
            guard let link = run.link else { return nil }
            return (String(rendered[run.range].characters), link)
        }
        XCTAssertEqual(linkedRuns.count, 1)
        let linked = try XCTUnwrap(linkedRuns.first)
        XCTAssertEqual(linked.0, #"[A]\B"#)
        XCTAssertEqual(linked.1.scheme, "https")
        XCTAssertEqual(linked.1.host, "example.org")
        XCTAssertEqual(linked.1.path, "/source(a)")
    }

    func testMissingNonIntegerNegativeAndOutOfBoundsCitationRangesRejectResearch() async throws {
        var missingStart = citation(start: 8, end: 13); missingStart.removeValue(forKey: "start_index")
        var missingEnd = citation(start: 8, end: 13); missingEnd.removeValue(forKey: "end_index")
        var stringStart = citation(start: 8, end: 13); stringStart["start_index"] = "8"
        var stringEnd = citation(start: 8, end: 13); stringEnd["end_index"] = "13"
        var fractionalStart = citation(start: 8, end: 13); fractionalStart["start_index"] = 8.5
        var booleanStart = citation(start: 8, end: 13); booleanStart["start_index"] = true
        var nullEnd = citation(start: 8, end: 13); nullEnd["end_index"] = NSNull()
        let invalid = [missingStart, missingEnd, stringStart, stringEnd, fractionalStart, booleanStart, nullEnd,
                       citation(start: -1, end: 3), citation(start: 8, end: 8), citation(start: 9, end: 8),
                       citation(start: 8, end: 14), citation(start: 14, end: 15),
                       citation(start: 8, end: Int.max), citation(start: Int.min, end: 13)]
        for annotation in invalid {
            let transport = AdultOfflineAITransport([.bytes(try response(text: "🧺 Cafe\u{301} label",
                annotations: [annotation], searchStatus: "completed"))])
            await assertAIError(.invalidResponse) {
                _ = try await AdultAIService(transport: transport).research(goal: "Care labels", model: self.selectedModel, key: self.fixtureKey)
            }
            let requests = await transport.capturedRequests()
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testOverlappingAndDuplicateCitationSpansRejectTheWholeResearchAnswer() async throws {
        let overlap = [citation(start: 0, end: 3), citation("https://example.org/other", start: 2, end: 5)]
        let duplicate = [citation(start: 0, end: 5), citation(start: 0, end: 5)]
        for annotations in [overlap, duplicate] {
            let transport = AdultOfflineAITransport([.bytes(try response(text: "label", annotations: annotations, searchStatus: "completed"))])
            await assertAIError(.invalidResponse) {
                _ = try await AdultAIService(transport: transport).research(goal: "Care labels", model: self.selectedModel, key: self.fixtureKey)
            }
        }
    }

    func testResearchEvidenceIsRetainedAcrossTheSecondPlanningRequestAndCoding() async throws {
        let text = "Care depends on the fabric. 🧺 Verify the label first."
        let transport = AdultOfflineAITransport([
            .bytes(try response(text: text, annotations: [citation(start: 0, end: 4)], searchStatus: "completed")),
            .bytes(try response(text: draft()))
        ])
        let plan = try await generate(AdultAIService(transport: transport), research: true)
        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 2)
        let planBody = try requestBody(requests[1])
        XCTAssertNil(planBody["tools"], "A planning pass must not silently repeat search or write actions.")
        let input = try XCTUnwrap(planBody["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])
        let context = try XCTUnwrap(content.first?["text"] as? String)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(context.utf8)) as? [String: String])
        let citedText = "[Care](https://example.org/care-labels) depends on the fabric. 🧺 Verify the label first."
        XCTAssertEqual(object["research"], citedText)
        let evidence = try XCTUnwrap(plan.researchEvidence)
        XCTAssertEqual(evidence.text, citedText)
        XCTAssertEqual(evidence.checkedAt, now)
        XCTAssertEqual(evidence.citations, plan.citations)
        XCTAssertEqual(evidence.citations.first?.source, .webAnnotation)
        XCTAssertEqual(try JSONDecoder().decode(AdultAssistantPlan.self, from: JSONEncoder().encode(plan)), plan)
    }

    func testRejectedResearchStopsBeforeThePlanningRequest() async throws {
        let transport = AdultOfflineAITransport([
            .bytes(try response(text: "A generated link is not research evidence.", searchStatus: "completed")),
            .bytes(try response(text: draft()))
        ])
        await assertAIError(.invalidResponse) { _ = try await self.generate(AdultAIService(transport: transport), research: true) }
        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testMaximumAllowedGoalReachesOnlyTheInjectedTransport() async throws {
        let goal = String(repeating: "a", count: 2_000)
        let transport = AdultOfflineAITransport([
            .bytes(try response(text: draft())),
            .bytes(try response(text: "Verified research", annotations: [citation()], searchStatus: "completed"))
        ])
        let service = AdultAIService(transport: transport)
        let plan = try await generate(service, goal: goal)
        XCTAssertEqual(plan.goal, goal)
        let research = try await service.research(goal: goal, model: selectedModel, key: fixtureKey)
        XCTAssertEqual(research.citations.count, 1)
        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testInvalidGoalsModelsAndMissingKeysAreRejectedWithoutTransportCalls() async throws {
        let transport = AdultOfflineAITransport([])
        let service = AdultAIService(transport: transport)
        for goal in ["", " \n\t ", String(repeating: "x", count: 2_001)] {
            await assertAIError(.invalidInput) { _ = try await self.generate(service, goal: goal) }
            await assertAIError(.invalidInput) {
                _ = try await service.research(goal: goal, model: self.selectedModel, key: self.fixtureKey)
            }
        }
        for model in ["", "model/with/path", String(repeating: "x", count: 101)] {
            await assertAIError(.invalidInput) {
                _ = try await service.makePlan(goal: "Laundry", guide: nil, provider: .openAI, model: model,
                                               key: self.fixtureKey, research: false, now: self.now)
            }
        }
        for key in ["", "offline\r\nInjected-Header: value"] {
            await assertAIError(.invalidInput) {
                _ = try await service.makePlan(goal: "Laundry", guide: nil, provider: .openAI, model: self.selectedModel,
                                               key: key, research: false, now: self.now)
            }
        }
        await assertAIError(.noKey) {
            _ = try await service.makePlan(goal: "Laundry", guide: nil, provider: .openAI, model: self.selectedModel,
                                           key: nil, research: false, now: self.now)
        }
        let requests = await transport.capturedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testTransportQuotaAndCancellationDoNotReturnPartialPlansOrRetry() async throws {
        let quota = AdultOfflineAITransport([.failure(.quota)])
        await assertAIError(.quota) { _ = try await self.generate(AdultAIService(transport: quota)) }
        let quotaRequests = await quota.capturedRequests()
        XCTAssertEqual(quotaRequests.count, 1)
        let cancelled = AdultOfflineAITransport([.cancelled])
        do {
            _ = try await generate(AdultAIService(transport: cancelled))
            XCTFail("Cancellation must not produce a plan.")
        } catch is CancellationError {} catch { XCTFail("Cancellation was replaced with \(error).") }
        let cancelledRequests = await cancelled.capturedRequests()
        XCTAssertEqual(cancelledRequests.count, 1)
    }
}

/// An empty response queue throws instead of falling back to any real network transport.
private actor AdultOfflineAITransport: AdultAITransport {
    enum Step: Sendable {
        case bytes(Data)
        case failure(AdultAIConnectionError)
        case cancelled
    }
    enum FixtureError: Error { case unexpectedRequest }
    private var steps: [Step]
    private var requests: [URLRequest] = []

    init(_ steps: [Step]) { self.steps = steps }

    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        guard !steps.isEmpty else { throw FixtureError.unexpectedRequest }
        switch steps.removeFirst() {
        case .bytes(let data): return data
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }

    func capturedRequests() -> [URLRequest] { requests }
}
