import Foundation

@main struct AdultLocalProbe {
    static func main() async {
        print("On-device available: \(AdultAIService.onDeviceAvailable)")
        guard AdultAIService.onDeviceAvailable else { return }
        do {
            let plan = try await AdultAIService().makePlan(goal: "Make one checklist with three small steps to tidy a desk. No purchases, reminders or calendar events.", guide: nil, provider: .onDevice, model: "unused", key: nil, research: false)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(plan), as: UTF8.self))
        } catch {
            print("Local planning failed: \(error.localizedDescription)")
            exit(1)
        }
    }
}
