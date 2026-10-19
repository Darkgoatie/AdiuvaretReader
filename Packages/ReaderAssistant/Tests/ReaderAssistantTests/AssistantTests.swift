import Testing
import Foundation
@testable import ReaderAssistant

struct Scripted: AssistantProvider {
    var availability: AssistantAvailability = .available
    var parts: [String] = []
    var error: AssistantError?
    func stream(prompt: String, instructions: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for p in parts { c.yield(p) }
            if let error { c.finish(throwing: error) } else { c.finish() }
        }
    }
}

@Suite struct PassageTests {
    @Test func selectionIsTrimmedAndEmptyIsNil() {
        #expect(Passage.selection("   ", source: "x") == nil)
        let short = Passage.selection(" hello ", source: "Chapter 1")
        #expect(short?.text == "hello")
        #expect(short?.wasTrimmed == false)
        let long = Passage.selection(String(repeating: "word ", count: 2000), source: "Chapter 1", budget: 100)
        #expect(long?.wasTrimmed == true)
        #expect((long?.text.count ?? 999) <= 100)
    }

    @Test func aroundCentresOnPosition() {
        let text = (0..<400).map { "w\($0)" }.joined(separator: " ")
        let p = Passage.around(text, fraction: 0.5, source: "Chapter 2", budget: 300)!
        #expect(p.wasTrimmed)
        #expect(p.text.count <= 300)
        #expect(p.text.contains("w200") || p.text.contains("w190") || p.text.contains("w210"))
        let start = Passage.around(text, fraction: 0, source: "c", budget: 300)!
        #expect(start.text.hasPrefix("w0 "))
        let whole = Passage.around("short chapter", fraction: 0.9, source: "c")!
        #expect(!whole.wasTrimmed)
    }

    @Test func promptQuotesPassageAndRequest() {
        let p = Passage(text: "The cat sat.", source: "Page 4", isSelection: true, wasTrimmed: false)
        let prompt = AssistantPrompt.prompt(action: .ask("Who sat?"), passage: p)
        #expect(prompt.contains("Passage from Page 4:"))
        #expect(prompt.contains("The cat sat."))
        #expect(prompt.hasSuffix("Who sat?"))
        #expect(AssistantPrompt.prompt(action: .summarise, passage: p).contains("Summarise"))
    }
}

@MainActor
@Suite struct ModelTests {
    private let passage = Passage(text: "text", source: "Chapter 1", isSelection: true, wasTrimmed: false)

    @Test func streamsAnswer() async {
        let m = AssistantModel()
        m.run(.explain, on: passage, with: Scripted(parts: ["It", "It means"]))
        for _ in 0..<200 where m.isRunning { try? await Task.sleep(nanoseconds: 10_000_000) }
        #expect(m.answer == "It means")
        #expect(m.failure == nil)
        #expect(m.lastAction == .explain)
    }

    @Test func reportsFailure() async {
        let m = AssistantModel()
        m.run(.summarise, on: passage, with: Scripted(parts: [], error: .contextTooLong))
        for _ in 0..<200 where m.isRunning { try? await Task.sleep(nanoseconds: 10_000_000) }
        #expect(m.failure == .contextTooLong)
        m.reset()
        #expect(m.failure == nil && m.answer.isEmpty)
    }
}
