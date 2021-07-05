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
        let mangaMO: MangaMO? = PersistenceController.fetch(
            entityName: "MangaMO", gid: gid
        )
        return mangaMO?.toEntity() ?? Manga.empty
    }
    var mangaDetail: MangaDetail? {
        let mangaDetailMO: MangaDetailMO? = PersistenceController.fetch(
            entityName: "MangaDetailMO", gid: gid
        )
        return mangaDetailMO?.toEntity()
    }
}
