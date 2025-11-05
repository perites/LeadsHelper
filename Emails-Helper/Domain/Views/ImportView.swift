//
//  DomainImportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 17/10/2025.
//

import SwiftUI

struct DomainImportView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode
    
    @StateObject var viewModel: ImportViewModel = .init()
    
    @State var importName: String = ""
    @State var tagName: String = ""
    
    @State var isImporting: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImportNameInputView
            TagNameInputView
            
            Divider()
            
            HStack {
                FilesImportView(viewModel: viewModel)
                TextImportView(viewModel: viewModel)
            }
            
            Divider()
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                Text(
                    "Total Leads: \(viewModel.emailsAll?.count.formatted(.number) ?? "Calculating...")"
                )
                Spacer()
                ImportButton
            }
            .padding(.top, 10)
        }.padding()
            .loadingOverlay(isShowing: $isImporting, text: "Importing...")
    }
        
    private var ImportNameInputView: some View {
        HStack {
            Text("Import Name:")
            TextField("Enter Import Name", text: $importName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
        }.font(.title3)
    }
    
    private var TagNameInputView: some View {
        HStack {
            Text("Tag Name:")
            SearchBarWithSuggestions(
                query: $tagName,
                allItems: domain.tagsInfo.map { $0.name }
            ).textFieldStyle(RoundedBorderTextFieldStyle())
            
        }.font(.title3)
    }
    
    private var ImportButton: some View {
        Button(
            action: {
                Task { @MainActor in
                    isImporting = true
                    
                    let result = await viewModel.importLeads(
                        importName: importName,
                        tagName: tagName,
                        domainId: domain.id
                    )
                    
                    isImporting = false
                    
                    switch result {
                    case .loading:
                        ToastManager.shared.show(style: .warning, message: "Wait for Leads to load")
                    case .failure:
                        ToastManager.shared.show(style: .error, message: "Error while importing leads")
                    case .success(let count):
                        domain.updateTagsInfo()
                        ToastManager.shared
                            .show(
                                style: count > 0 ? .success : .warning,
                                message: "Import Complete:\n\(count) leads imported"
                            )
                        mode = .info
                    }
                }

            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                    Text("Finish Import")
                        .font(.title2)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.green.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
    }
}

private struct FilesImportView: View {
    @ObservedObject var viewModel: ImportViewModel
    
    @State var selectedFiles: [URL] = []
    @State private var isFileImporterPresented = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Files Import").font(.title3).fontWeight(.semibold)
                Spacer()
                SelectFilesButton
            }
            
            SelectedFiles
            
            Text(
                "Leads from files: \(viewModel.emailsFromFiles?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
                
        }.onChange(of: selectedFiles) { _, newSelectedFiles in
            viewModel.getLeads(from: .files(newSelectedFiles))
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    var SelectFilesButton: some View {
        Button(action: {
            isFileImporterPresented.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "folder.badge.person.crop")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                Text("Select Files")
                    .font(.title3)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .cornerRadius(8)
            .shadow(radius: 2)
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                selectedFiles = Array(Set(selectedFiles + urls))
            case .failure(let error):
                print("Error selecting files: \(error)")
            }
        }
    }
        
    var SelectedFiles: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(selectedFiles, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        
                        Text(file.lastPathComponent)
                            .lineLimit(1)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            if let index = selectedFiles.firstIndex(of: file) {
                                selectedFiles.remove(at: index)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain) // No ugly button highlight
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2))
                    )
                }
            }
            .padding(5)
        }
    }
}

private struct TextImportView: View {
    @ObservedObject var viewModel: ImportViewModel
    
    @State var textInput: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Text Import")
                Spacer()
            }
            .padding(.vertical, 5)
            .font(.title3)
            .fontWeight(.semibold)
            
            TextEditor(text: $textInput)
                .font(.body)
                .padding()
                .frame(minHeight: 150) // Adjust height like a textarea
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.4)))
            
            Text(
                "Leads from files: \(viewModel.emailsFromText?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
            
        }.onChange(of: textInput) { _, newText in
            viewModel.getLeads(from: .text(newText))
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
