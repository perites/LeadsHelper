//
//  ImportsHistoryViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/11/2025.
//



import Foundation

// Used to make the 'type' Int more readable in the UI
enum ImportType: Int {
    case file = 0 // Or whatever Int you use for file imports
    case text = 1 // Or whatever Int you use for text imports
    case bulk = 2 // I've assumed a 'bulk' type
    case unknown = 99

    var description: String {
        switch self {
        case .file: return "File Import"
        case .text: return "Text Import"
        case .bulk: return "Bulk Import"
        case .unknown: return "Unknown"
        }
    }
    
    // Provides a nice icon for the list
    var icon: String {
         switch self {
        case .file: return "doc.fill"
        case .text: return "text.alignleft"
        case .bulk: return "person.2.badge.plus.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// This struct will represent one row in your history list
struct ImportInfo: Identifiable, Equatable {
    let id: Int64
    let name: String
    let dateCreated: Date
    let importType: ImportType
    let tagId: Int64
    let leadCount: Int // We will get this by joining the LeadsTable
}




import Foundation

class ImportHistoryViewModel: ObservableObject {
    @Published var selectedTagId: Int64?
    @Published var imports: [ImportInfo] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    
    var totalCount: Int = 0
    private var offset: Int = 0
    private let pageSize: Int = 10 // Show 10 items at a time
    
    private var fetchTask: Task<Void, Never>?

    // Computed property to know if the "Load More" button should be shown
    var canLoadMore: Bool {
        return offset < totalCount && !isLoading && !isLoadingMore
    }

    init(initialTagId: Int64?) {
        self.selectedTagId = initialTagId
        // Fetch initial data
        fetchData(isLoadMore: false)
    }
    
    /// Called when the selected tag changes
    func tagDidChange() {
        // Reset the state
        self.offset = 0
        self.totalCount = 0
        self.imports = []
        // Fetch data for the new tag
        fetchData(isLoadMore: false)
    }
    
    /// Called by the "Load More" button
    func loadMore() {
        guard canLoadMore else { return }
        fetchData(isLoadMore: true)
    }
    
    /// The main function to get data from the database
    private func fetchData(isLoadMore: Bool) {
        fetchTask?.cancel()
        
        guard let tagId = selectedTagId else {
            self.imports = []
            return
        }
        
        // Set the correct loading flag
        if isLoadMore {
            isLoadingMore = true
        } else {
            isLoading = true
        }

//        fetchTask = Task(priority: .userInitiated) {
//            let (fetchedImports, fetchedTotalCount) = ImportsTable.fetchImports(
//                for: tagId,
//                limit: pageSize,
//                offset: self.offset
//            )
//            
//            guard !Task.isCancelled else {
//                await MainActor.run {
//                    self.isLoading = false
//                    self.isLoadingMore = false
//                }
//                return
//            }
//            
//            await MainActor.run {
//                self.totalCount = fetchedTotalCount
//                
//                if isLoadMore {
//                    // Append new items to the end of the list
//                    self.imports.append(contentsOf: fetchedImports)
//                } else {
//                    // Replace the list with the first page
//                    self.imports = fetchedImports
//                }
//                
//                // Update the offset to be ready for the next page
//                self.offset = self.imports.count
//                
//                // Turn off loading flags
//                self.isLoading = false
//                self.isLoadingMore = false
//            }
//        }
    }
}
