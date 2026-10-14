import SwiftUI
import Translation

public extension View {
    /// Translates with one SwiftUI-owned session, including any required model downloads.
    /// The batch call owns the prompt and its cancellation; the session never crosses isolation regions.
    func liveTextTranslations(for translator: LiveTextTranslator) -> some View {
        let work = translator.session
        return translationTask(translator.configuration) { @concurrent session in
            guard let work else { return }
            guard !Task.isCancelled, await translator.session?.id == work.id else {
                await translator.sessionEnded(work.id)
                return
            }
            defer { session.cancel() }
            for await batch in work.requests {
                guard !Task.isCancelled, await translator.session?.id == work.id else { break }
                let requests = batch.sources.map { source in
                    TranslationSession.Request(sourceText: source.text, clientIdentifier: source.groupID.uuidString)
                }
                let result: Result<[UUID: String], any Error>
                do {
                    let responses = try await session.translations(from: requests)
                    var translations = [UUID: String]()
                    for response in responses {
                        guard let id = response.clientIdentifier.flatMap(UUID.init(uuidString:)),
                              translations[id] == nil
                        else { continue }
                        translations[id] = response.targetText
                    }
                    result = .success(translations)
                } catch {
                    guard !Task.isCancelled, await translator.session?.id == work.id else { break }
                    if error is CancellationError || CocoaError.userCancelled ~= error {
                        await translator.finish(batch, in: work.id, with: .failure(error))
                        return
                    }
                    // Readiness classifies a model failure; it is never polled or used as a barrier.
                    guard await session.isReady else {
                        await translator.modelsUnavailable(in: work.id, with: error)
                        return
                    }
                    result = .failure(error)
                }
                guard !Task.isCancelled else { break }
                await translator.finish(batch, in: work.id, with: result)
            }
            await translator.sessionEnded(work.id)
        }
    }
}
