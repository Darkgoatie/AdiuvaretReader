import Foundation
import ReaderAssistant
#if canImport(FoundationModels)
import FoundationModels
#endif

struct UnavailableProvider: AssistantProvider {
    let reason: String
    var availability: AssistantAvailability { .unavailable(reason) }
    func stream(prompt: String, instructions: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: AssistantError.other) }
    }
}

enum AssistantProviders {
    static func make() -> any AssistantProvider {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return AppleProvider() }
        #endif
        return UnavailableProvider(reason: "The assistant needs a device with Apple Intelligence (iOS 26 or macOS 26 or later).")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
struct AppleProvider: AssistantProvider {
    var availability: AssistantAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable: .unavailable("Apple Intelligence is not available on this device. Turn it on in Settings, or try again once the model has finished downloading.")
        }
    }

    func stream(prompt: String, instructions: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    for try await partial in session.streamResponse(to: prompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    if case LanguageModelSession.GenerationError.exceededContextWindowSize = error {
                        continuation.finish(throwing: AssistantError.contextTooLong)
                    } else if case LanguageModelSession.GenerationError.guardrailViolation = error {
                        continuation.finish(throwing: AssistantError.refused)
                    } else if case LanguageModelSession.GenerationError.refusal = error {
                        continuation.finish(throwing: AssistantError.refused)
                    } else if case LanguageModelSession.GenerationError.rateLimited = error {
                        continuation.finish(throwing: AssistantError.busy)
                    } else {
                        continuation.finish(throwing: AssistantError.other)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
