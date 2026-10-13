import OSLogExt
import SwiftUI
import Translation

private let logger = Logger(category: "LiveTextTranslationDownloads")

public extension View {
    /// Offers the system's download of the models `translator` waits for, and lets it carry on once
    /// they are downloaded or declined.
    ///
    /// Only a session SwiftUI hands to `translationTask` can download models; every other session
    /// translates with installed models only. The task runs off the main actor, where the session's
    /// own work runs, so the session never crosses into the main actor's region.
    func liveTextTranslationDownloads(for translator: LiveTextTranslator) -> some View {
        let pair = translator.download
        return translationTask(
            pair.map({ TranslationSession.Configuration(source: $0.source, target: $0.target) })
        ) { @concurrent session in
            guard let pair else {
                return
            }
            do {
                try await session.prepareTranslation()
                await translator.finishDownload(of: pair, succeeded: true)
            } catch {
                let languages = "\(pair.source.minimalIdentifier) to \(pair.target.minimalIdentifier)"
                logger.info("Models for \(languages, privacy: .public) were not downloaded: \(error, privacy: .public)")
                await translator.finishDownload(of: pair, succeeded: false)
            }
        }
    }
}
