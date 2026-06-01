//
//  LibraryReadingList.swift
//  Sympho
//
//  Reading list slice inside Library (full module lives in sidebar).
//

import SwiftUI

struct LibraryReadingListSection: View {
    let searchText: String
    let selectedDomain: Domain?
    let selectedTag: LibraryTag?

    var body: some View {
        ReadingListWorkspace(
            presentation: .libraryEmbedded,
            externalSearchText: searchText,
            selectedDomain: selectedDomain,
            selectedTag: selectedTag
        )
    }
}
