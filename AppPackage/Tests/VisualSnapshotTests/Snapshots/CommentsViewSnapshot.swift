import CoreGraphics

/// The snapshot states of `CommentsView` (19-18).
enum CommentsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "comments-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1424, large: 1664, accessibility5: 8651),
                        landscape: .init(xSmall: 1009, large: 1203, accessibility5: 4391)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 4071),
                        landscape: .init(xSmall: 1038, large: 1104, accessibility5: 2913)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.comments(.list) })
            ),
            SnapshotState(
                id: "comments-menu",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.comments(.list) }, interact: GalleryScenarios.openFirstRowMenu
                )
            ),
            SnapshotState(
                id: "comments-block-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { try TracerScenarios.comments() }, interact: TracerScenarios.chooseBlock
                )
            ),
            SnapshotState(
                id: "comments-blocked-row-collapsed",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1331, large: 1544, accessibility5: 7630),
                        landscape: .init(xSmall: 973, large: 1134, accessibility5: 4018)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3762),
                        landscape: .init(xSmall: 1002, large: 1057, accessibility5: 2720)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.comments(.blocked) })
            ),
            SnapshotState(
                id: "comments-blocked-row-shown",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1453, large: 1702, accessibility5: 8890),
                        landscape: .init(xSmall: 1038, large: 1235, accessibility5: 4578)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 4258),
                        landscape: .init(xSmall: 1067, large: 1136, accessibility5: 3048)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.comments(.blockedShown) })
            )
        ]
    }
}
