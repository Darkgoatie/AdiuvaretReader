import Foundation
import Observation

public enum AssistantAction: Equatable, Sendable {
    case explain, summarise, define, simplify
    case ask(String)

    public var title: String {
        switch self {
        case .explain: "Explain"
        case .summarise: "Summarise"
        case .define: "Define"
        case .simplify: "Simplify"
        case .ask: "Ask"
        }
    }

    public static let quickActions: [AssistantAction] = [.explain, .summarise, .define, .simplify]

    /// The question part of the prompt.
    var request: String {
        switch self {
        case .explain: "Explain what this passage means, in a few short sentences."
        case .summarise: "Summarise this passage in two or three sentences."
        case .define: "Define the key terms or unusual words in this passage, one line each."
        case .simplify: "Rewrite this passage in plain, simple language, keeping its meaning."
        case .ask(let q): q
        }
    }
}

public enum AssistantPrompt {
    public static let instructions = """
    You are a reading assistant inside a book reader. Answer only from the passage you are given. \
    If the passage does not contain the answer, say so in one sentence. Quote short phrases from the passage when you refer to it. \
    Be brief. Reply in plain text without Markdown, in the language of the passage unless asked otherwise.
    """

    public static func prompt(action: AssistantAction, passage: Passage) -> String {
        let trimmed = passage.wasTrimmed ? " (shortened)" : ""
        return "Passage from \(passage.source)\(trimmed):\n\"\"\"\n\(passage.text)\n\"\"\"\n\n\(action.request)"
    }
}

public enum AssistantAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

public protocol AssistantProvider: Sendable {
    var availability: AssistantAvailability { get }
    /// Streams the answer so far; each element replaces the previous one.
    func stream(prompt: String, instructions: String) -> AsyncThrowingStream<String, Error>
}

public enum AssistantError: Error, Equatable, Sendable {
    case contextTooLong
    case refused
    case busy
    case other
}

@MainActor
@Observable
public final class AssistantModel {
    public private(set) var answer = ""
    public private(set) var isRunning = false
    public private(set) var failure: AssistantError?
    public private(set) var lastAction: AssistantAction?

    @ObservationIgnored private var task: Task<Void, Never>?

    public init() {}

    public func run(_ action: AssistantAction, on passage: Passage, with provider: any AssistantProvider) {
        cancel()
        answer = ""
        failure = nil
        lastAction = action
        isRunning = true
        let prompt = AssistantPrompt.prompt(action: action, passage: passage)
        task = Task { [weak self] in
            do {
                for try await partial in provider.stream(prompt: prompt, instructions: AssistantPrompt.instructions) {
                    guard !Task.isCancelled else { return }
                    self?.answer = partial
                }
            } catch let e as AssistantError {
                self?.failure = e
            } catch is CancellationError {
            } catch {
                self?.failure = .other
            }
            self?.isRunning = false
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    public func reset() {
        cancel()
        answer = ""
        failure = nil
        lastAction = nil
    }
}
