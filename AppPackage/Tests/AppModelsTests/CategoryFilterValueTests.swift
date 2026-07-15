import IssueReporting
import Testing
@testable import AppModels

@Test
func privateFilterValueReportsIssueAndReturnsZero() {
    withExpectedIssue {
        #expect(Category.private.filterValue == 0)
    }
}

@Test
func allFilterCategoriesContributeEveryFilterBit() {
    let filterValue = Category.allFiltersCases.map(\.filterValue).reduce(0, +)

    #expect(filterValue == 1023)
}
