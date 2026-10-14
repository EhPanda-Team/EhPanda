import SwiftUI
import Translation

public extension View {
    /// Prepares and translates with the same SwiftUI-owned session. Preparation requests download
    /// permission; translation itself waits for readiness. The session never crosses isolation regions.
    func liveTextTranslations(for translator: LiveTextTranslator) -> some View {
        let work = translator.session
        return translationTask(translator.configuration) { @concurrent session in
            guard let work else { return }
            guard !Task.isCancelled, await translator.session?.id == work.id else {
                await translator.sessionEnded(work.id)
                return
            }
            defer { session.cancel() }
            do {
                try await session.prepareTranslation()
            } catch {
                if !Task.isCancelled {
                    await translator.modelsUnavailable(in: work.id, with: error)
                }
                await translator.sessionEnded(work.id)
                return
            }
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
                    // Dismissing a model prompt can surface as an internal translation error.
                    // Readiness here classifies that failure; it is never polled or used as a barrier.
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
