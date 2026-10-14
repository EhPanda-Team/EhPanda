@testable import AppModels
import IssueReporting
import Testing

@Test
func privateFilterValueReportsIssueAndReturnsZero() {
    expectReportsIssue {
        #expect(Category.private.filterValue == 0)
    } matching: {
        $0.description.contains("`Category.private` has no `filterValue`")
    }
}

@Test
func allFilterCategoriesContributeEveryFilterBit() {
    let filterValue = Category.allFiltersCases.map(\.filterValue).reduce(0, +)

    #expect(filterValue == 1023)
}
