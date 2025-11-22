//
//  ImportsJistoryView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/11/2025.
//


import SwiftUI

struct DomainImportHistoryView: View {
    @ObservedObject var domain: DomainViewModel
    @StateObject private var viewModel: ImportHistoryViewModel
    
    init(domain: DomainViewModel, initialTagId: Int64) {
        self.domain = domain
        self._viewModel = StateObject(
            wrappedValue: ImportHistoryViewModel(initialTagId: initialTagId)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            Picker("View History For:", selection: $viewModel.selectedTagId) {
                Text("Select a Tag").tag(Int64?.none)
                ForEach(domain.tagsInfo) { tag in
                    Text(tag.name).tag(tag.id as Int64?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: 350)
            .onChange(of: viewModel.selectedTagId) { _, _ in
                // Use the new view model function
                viewModel.tagDidChange()
            }
            
            Divider()

            // MARK: - List of Imports
            
            // Show a full-screen spinner *only* on the first load
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.imports.isEmpty {
                Spacer()
                Text(viewModel.selectedTagId == nil ? "Please select a tag to view its history." : "No imports found for this tag.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                // The List of imports
                List(viewModel.imports) { importInfo in
                    ImportRowView(importInfo: importInfo)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                
                // --- THIS IS THE NEW PART ---
                
                // "Load More" button section
                if viewModel.canLoadMore || viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        Button(action: viewModel.loadMore) {
                            HStack(spacing: 8) {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "plus")
                                }
                                
                                Text(viewModel.isLoadingMore ? "Loading..." : "Load More")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .cornerRadius(20)
                        .disabled(viewModel.isLoadingMore)
                        
                        // Show the count
                        Text("\(viewModel.imports.count) / \(viewModel.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
    }
}



// A separate, clean view for a single list row
struct ImportRowView: View {
    let importInfo: ImportInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: importInfo.importType.icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(importInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(importInfo.dateCreated.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(importInfo.leadCount) leads")
                    .font(.headline)
                    .foregroundColor(importInfo.leadCount > 0 ? .primary : .secondary)
                Text(importInfo.importType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
