//
//  ExportsHistoryView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 23/11/2025.
//

import SwiftUI

struct DomainExportHistoryView: View {
    @Binding var mode: Mode
    @StateObject private var viewModel: ExportHistoryViewModel
    
    init(domain: DomainViewModel, mode: Binding<Mode>) {
        self._mode = mode
        self._viewModel = StateObject(wrappedValue: ExportHistoryViewModel(domain: domain))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("View exports history for \(viewModel.domain.name)").font(.body)
    
            Divider()
            
            ContentView
                .loadingOverlay(
                    isShowing: $viewModel.isLoading,
                    text: "Loading..."
                )
            Divider()
            FooterView
        }
    }
    
    @ViewBuilder
    private var ContentView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.exports.isEmpty {
                    Text("No exports found.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                   
                } else {
                    ForEach(viewModel.exports) { item in
                        ExportRowView(item: item)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.windowBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }
    
    private var FooterView: some View {
        ZStack {
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                
                Button(action: viewModel.loadMore) {
                    HStack {
                        Image(systemName: "10.arrow.trianglehead.clockwise")
                        Text("Load More")
                    }
                    .font(.title3)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                .disabled(!viewModel.canLoadMore)
            }
            
            Text("\(viewModel.exports.count) / \(viewModel.totalCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
}

struct ExportRowView: View {
    let item: ExportHistoryItem
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Main Clickable Header
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .center, spacing: 10) {
                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    
                    // Icon
                    
                    Image(systemName: item.isSeparateFiles ? "folder.fill" : "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                       
                    HStack {
                        Text(
                            item.isSeparateFiles ?
                                "\(item.folderName.components(separatedBy: "$|-|-|$")[0])/\(item.fileName.components(separatedBy: "$|-|-|$")[0])" : item.fileName.components(separatedBy: "$|-|-|$")[0]
                        )
                        .font(.headline)
                        .lineLimit(1)
                        Text("(id: \(item.id))").foregroundColor(.gray)
                    }
                    Spacer()
                    
                    Text("\(item.totalEmailsCount)")
                        .monospacedDigit()
                        .padding(.trailing, 20)
                    
                    Text(item.dateCreated.formatted(
                        .dateTime
                            .day(.twoDigits)
                            .month(.twoDigits)
                            .year()
                            .hour().minute()
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.top, 10)
                    
                    ForEach(item.tags) { tag in
                        HStack {
                            Text(tag.tagName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // Requested vs Actual logic
                            HStack(spacing: 15) {
                                VStack(alignment: .trailing) {
                                    Text("Requested")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(tag.requestedAmount != nil ? "\(tag.requestedAmount!)" : "0")
                                        .font(.subheadline)
                                }
                                
                                VStack(alignment: .trailing) {
                                    Text("Actual")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(tag.emailCount ?? 0)")
                                        .font(.subheadline)
                                        .foregroundColor(
                                            (
                                                tag.requestedAmount != nil && tag.emailCount ?? 0 < tag.requestedAmount!
                                            )
                                                ? .red : .green
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Thin separator between tags
                        if tag.id != item.tags.last?.id {
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
}
