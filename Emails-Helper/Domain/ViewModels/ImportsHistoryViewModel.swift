//
//  ImportsHistoryViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/11/2025.
//

import Foundation

enum ImportType: Int {
    case file = 1
    case text = 2
    case combined = 3

    var description: String {
        switch self {
        case .file: return "File Import"
        case .text: return "Text Import"
        case .combined: return "Combined Import"
        }
    }
    
    var icon: String {
        switch self {
        case .file: return "doc.fill"
        case .text: return "text.alignleft"
        case .combined: return "person.3.fill"
        }
    }
}

struct ImportInfo: Identifiable, Equatable {
    let id: Int64
    let name: String
    let dateCreated: Date
    let importType: ImportType
    let tagId: Int64
    let leadCount: Int
}

import Foundation

class ImportHistoryViewModel: ObservableObject {
    @Published var selectedTagId: Int64?
    @Published var imports: [ImportInfo] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    
    var totalCount: Int = 0
    private var offset: Int = 0
    private let pageSize: Int = 10
    
    private var fetchTask: Task<Void, Never>?
    
    var canLoadMore: Bool {
        return offset < totalCount && !isLoading && !isLoadingMore
    }
    
    init(initialTagId: Int64?) {
        self.selectedTagId = initialTagId
        fetchData(isLoadMore: false)
    }
    
    func tagDidChange() {
        offset = 0
        totalCount = 0
        imports = []
        fetchData(isLoadMore: false)
    }
    
    func loadMore() {
        guard canLoadMore else { return }
        fetchData(isLoadMore: true)
    }
    
    private func fetchData(isLoadMore: Bool) {
        fetchTask?.cancel()
        
        guard let tagId = selectedTagId else {
            imports = []
            return
        }
        
        isLoading = true
        
        fetchTask = Task {
            let (fetchedImports, fetchedTotalCount) = await ImportsTable.fetchImports(
                for: tagId,
                limit: pageSize,
                offset: self.offset
            )
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                self.totalCount = fetchedTotalCount
                
                if isLoadMore {
                    self.imports.append(contentsOf: fetchedImports)
                } else {
                    self.imports = fetchedImports
                }
                
                self.offset = self.imports.count
                
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }
}
