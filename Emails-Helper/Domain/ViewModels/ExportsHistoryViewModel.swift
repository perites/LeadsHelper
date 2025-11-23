//
//  ExportHistoryViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 23/11/2025.
//

import SwiftUI

import Foundation

struct ExportHistoryItem: Identifiable {
    let id: Int64
    let dateCreated: Date
    let fileName: String
    let folderName: String
    let isSeparateFiles: Bool
    let tags: [TagRequest] // The decoded tags
    
    // Computed property for the summary
    var totalEmailsCount: Int {
        tags.reduce(0) { $0 + ($1.emailCount ?? 0) }
    }
}

class ExportHistoryViewModel: ObservableObject {
    @Published var exports: [ExportHistoryItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var totalCount: Int = 0
    
    private var offset: Int = 0
    private let pageSize: Int = 10
    
    @ObservedObject var domain: DomainViewModel
    
    private var fetchTask: Task<Void, Never>?
    
    var canLoadMore: Bool {
        return offset < totalCount && !isLoading && !isLoadingMore
    }
    
    init(domain: DomainViewModel) {
        _domain = .init(initialValue: domain)
        fetchData(isLoadMore: false)
    }
    
    func loadMore() {
        guard canLoadMore else { return }
        fetchData(isLoadMore: true)
    }
    
    private func fetchData(isLoadMore: Bool) {
        fetchTask?.cancel()
        
        isLoading = true
        
        fetchTask = Task {
            let (newItems, newTotal) = await ExportTable.fetchExports(
                domainId: domain.id,
                limit: pageSize,
                offset: offset
            )
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                self.totalCount = newTotal
                
                if isLoadMore {
                    self.exports.append(contentsOf: newItems)
                } else {
                    self.exports = newItems
                }
                
                self.offset = self.exports.count
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }
}
