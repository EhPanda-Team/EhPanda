//
//  DomainResolver.swift
//  EhPanda
//

struct DomainResolver {
    static func resolve(domain: String) -> String? {
        ResolvableDomain(rawValue: domain)?.ipPool.randomElement()
    }
}

enum ResolvableDomain: String {
    case ehgt = "ehgt.org"
    case ehgt0 = "gt0.ehgt.org"
    case ehgt1 = "gt1.ehgt.org"
    case ehgt2 = "gt2.ehgt.org"
    case ehgt3 = "gt3.ehgt.org"
    case ehgtul = "ul.ehgt.org"
    case ehentai = "e-hentai.org"
    case exhentai = "exhentai.org"
    case repo = "repo.e-hentai.org"
    case forums = "forums.e-hentai.org"
    case github = "raw.githubusercontent.com"
}

private extension ResolvableDomain {
    var ipPool: [String] {
        switch self {
        case .ehgt:
            return [
                "37.48.89.44", "81.171.10.48",
                "178.162.139.24", "178.162.140.212"
            ]
        case .ehgt0:
            return [
                "37.48.89.44", "81.171.10.48",
                "178.162.139.24", "178.162.140.212"
            ]
        case .ehgt1:
            return [
                "37.48.89.44", "81.171.10.48",
                "178.162.139.24", "178.162.140.212"
            ]
        case .ehgt2:
            return [
                "37.48.89.44", "81.171.10.48",
                "178.162.139.24", "178.162.140.212"
            ]
        case .ehgt3:
            return [
                "37.48.89.44", "81.171.10.48",
                "178.162.139.24", "178.162.140.212"
            ]
        case .ehgtul:
            return ["94.100.24.82", "94.100.24.72"]
        case .ehentai:
            return [
                "104.20.134.21", "104.20.135.21",
                "172.67.0.127"
            ]
        case .exhentai:
            return [
                "178.175.128.252", "178.175.129.252",
                "178.175.129.254", "178.175.128.254",
                "178.175.132.20", "178.175.132.22"
            ]
        case .repo:
            return ["94.100.28.57", "94.100.29.73"]
        case .forums:
            return ["94.100.18.243"]
        case .github:
            return [
                "151.101.0.133", "151.101.64.133",
                "151.101.128.133", "151.101.192.133"
            ]
        }
    }
}
