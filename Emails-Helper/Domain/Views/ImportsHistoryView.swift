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
    @Binding var mode: Mode
    
    init(domain: DomainViewModel, initialTagId: Int64, mode: Binding<Mode>) {
        self.domain = domain
        self._viewModel = StateObject(
            wrappedValue: ImportHistoryViewModel(initialTagId: initialTagId)
        )
        _mode = mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TagPickerView(
                domain: domain,
                pickedTagId: $viewModel.selectedTagId,
                mode: .regular,
                pickerName: "View imports history for:"
            ).onChange(of: viewModel.selectedTagId) { _, _ in
                viewModel.tagDidChange()
            }
            
            Divider()
            ContentView.loadingOverlay(isShowing: $viewModel.isLoading, text: "Loading...")
            Divider()
            
            FooterView
        }
    }
    
    @ViewBuilder
    private var ContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.imports.isEmpty {
                    Text(viewModel.selectedTagId == nil ? "Select a tag to view its history." : "No imports found for this tag.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)

                            
                } else {
                    ForEach(viewModel.imports) { importInfo in
                        ImportRowView(importInfo: importInfo)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.windowBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                    }
                }
            }
        }
    }
    
    private var FooterView: some View {
        ZStack {
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                LoadMoreButton
            }
                
            Text("\(viewModel.imports.count) / \(viewModel.totalCount)").font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var LoadMoreButton: some View {
        
        Button(action: viewModel.loadMore) {
            HStack(spacing: 8) {
                Image(systemName: "10.arrow.trianglehead.clockwise")
                Text(viewModel.isLoadingMore ? "Loading..." : "Load More")
            }
            .font(.title3)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }.disabled(!viewModel.canLoadMore)
    }
}

struct ImportRowView: View {
    let importInfo: ImportInfo
    
    var body: some View {
        HStack(spacing: 12) {
                Image(systemName: importInfo.importType.icon)
                    .font(.title2)
                    .foregroundColor(.green)
                
            
                Text(importInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                
            Spacer()
            
            Text("\(importInfo.leadCount)")
                .monospacedDigit()
                .padding(.trailing, 20)
                
            
           
            
            
            Text(importInfo.dateCreated.formatted(
                .dateTime
                    .day(.twoDigits)
                    .month(.twoDigits)
                    .year()
                    .hour().minute()
            ))
                .font(.caption)
                .foregroundColor(.secondary)

        }
    }
}
