public import AppModels
public import Foundation

extension Parser {
    /// The API's answer to `tagsuggest` (G-1 and G-4 of quick 261126-wzg): every entry the tag field could take, in
    /// ascending id order, the order the site's list shows them in (the answer is an object keyed by id, which a
    /// browser walks by ascending integer key). With no match the site answers an empty array instead of an object.
    /// An entry with a namespace the app does not know, an empty name or a key that is no id is left out, and so is
    /// an alias whose canonical tag is such; a `mid` of null is no alias. `login` (an expired session) throws
    /// `loginRequired`, `error` (a refusal) `unknown`, and any other answer without the tags `parseFailed`.
    public static func parseTagSuggestions(data: Data) throws(AppError) -> [SiteTagSuggestion] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .parseFailed
        }
        guard let answer = object as? [String: Any] else { throw .parseFailed }
        if answer["login"] != nil {
            throw .loginRequired
        }
        if answer["error"] != nil {
            throw .unknown
        }
        if let tags = answer["tags"] as? [Any] {
            guard tags.isEmpty else { throw .parseFailed }
            return []
        }
        guard let tags = answer["tags"] as? [String: Any] else { throw .parseFailed }
        return tags
            .compactMap({ siteTagSuggestion(id: $0.key, entry: $0.value) })
            .sorted(by: { $0.id < $1.id })
    }

    private static func siteTagSuggestion(id: String, entry: Any) -> SiteTagSuggestion? {
        guard let id = Int(id),
              let entry = entry as? [String: Any],
              let tag = siteTag(namespace: entry["ns"], name: entry["tn"])
        else { return nil }
        guard let mid = entry["mid"], !(mid is NSNull) else {
            return SiteTagSuggestion(id: id, tag: tag, canonical: nil)
        }
        guard let canonical = siteTag(namespace: entry["mns"], name: entry["mtn"]) else { return nil }
        return SiteTagSuggestion(id: id, tag: tag, canonical: canonical)
    }

    private static func siteTag(namespace: Any?, name: Any?) -> SiteTag? {
        guard let namespace = (namespace as? String).flatMap(TagNamespace.init(rawValue:)),
              let name = name as? String, !name.isEmpty
        else { return nil }
        return SiteTag(namespace: namespace, name: name)
    }
}
