//
//  PersistenceAccessor.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/05.
//

protocol PersistenceAccessor {
    var gid: String { get }
}

extension PersistenceAccessor {
    var manga: Manga {
        PersistenceController.fetchMangaNonNil(gid: gid)
    }
    var mangaDetail: MangaDetail? {
        PersistenceController.fetchMangaDetail(gid: gid)
    }
}
