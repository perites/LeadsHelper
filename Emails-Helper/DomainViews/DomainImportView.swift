//
//  DomainImportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 17/10/2025.
//

class ImportsViewModel: ObservableObject {
    @Published var emailsFromFiles: [String]? = []
    @Published var emailsFromText: [String]? = []
    
    var filesParseTask: Task<Void, Never>?
    var textParseTask: Task<Void, Never>?
    
    var emailsAll: [String]? {
        if emailsFromText != nil && emailsFromFiles != nil {
            return Array(Set(emailsFromText! + emailsFromFiles!))
        } else {
            return nil
        }
    }
    
    func importLeads(
        importName: String,
        tagName: String,
        domainId: Int64
    ) async {
        let start = Date()
        guard let emails = emailsAll else {
            ToastManager.shared
                .show(style: .warning, message: "Wait for Leads to load")
            return
        }
        
        let tagId = getTagId(tagName: tagName, domainId: domainId)
        
        var newType = 0
        if let files = emailsFromFiles, let text = emailsFromText {
            if !files.isEmpty && !text.isEmpty {
                newType = 3
            } else if !files.isEmpty {
                newType = 1
            } else if !text.isEmpty {
                newType = 2
            }
        }

        let importId = ImportsTable.addImport(
            newName: importName,
            newTagId: tagId,
            newType: newType
        )!
        
        LeadsTable.addLeadsBulk(
            newEmails: emails,
            newImportId: importId,
            newTagId: tagId
        )
        
        let timeElapsed = Date().timeIntervalSince(start)
        print("Import took \(timeElapsed) seconds. Type : \(newType)")
    }
    
    func getTagId(tagName: String, domainId: Int64) -> Int64 {
        var tagId: Int64?
        
        tagId = TagsTable.findByName(name: tagName, domainId: domainId)
        if tagId == nil {
            tagId = TagsTable.addTag(
                newName: tagName,
                newDomainId: domainId
            )!
        }
        return tagId!
    }
    
    func getEmailsFromString(_ input: String) -> [String] {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
                
        guard let regex = try? NSRegularExpression(pattern: emailRegex, options: []) else {
            return []
        }
                
        let range = NSRange(location: 0, length: input.utf16.count)
                
        let matches = regex.matches(in: input, options: [], range: range)
                
        let emails = Array(Set(matches.compactMap {
            Range($0.range, in: input).map { String(input[$0]) }
        }))
                
        return emails
    }
        
    enum LeadSource {
        case files([URL])
        case text(String)
    }

    func getLeads(from source: LeadSource) {
        switch source {
        case .files(let urls):
            filesParseTask?.cancel()
            emailsFromFiles = nil
            
            filesParseTask = Task {
                await self.getLeadsFromFiles(urls: urls)
            }

        case .text(let inputText):
            textParseTask?.cancel()
            emailsFromText = nil
            textParseTask = Task {
                await self.getLeadsFromText(text: inputText)
            }
        }
    }
    
    private func getLeadsFromFiles(urls: [URL]) async {
        var combined = ""
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            combined += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        let emails = getEmailsFromString(combined)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            emailsFromFiles = emails
        }
    }
    
    private func getLeadsFromText(text: String) async {
        let emails = getEmailsFromString(text)
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
            emailsFromText = emails
        }
    }
}

import SwiftUI

struct DomainImportView: View {
    @Binding var mode: Mode
    @ObservedObject var domain: DomainViewModel
    
    @StateObject var viewModel: ImportsViewModel = .init()
    
    @State var importName: String = ""
    @State var tagName: String = ""
    
    @State var isLoading: Bool = false
    
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
                GoBackButtonView(mode: $mode, goBackMode: .view)
                Spacer()
                Text(
                    "Total Leads: \(viewModel.emailsAll?.count.formatted(.number) ?? "Calculating...")"
                )
                Spacer()
                ImportButton
            }
            .padding(.top, 10)
        }.padding()
            .loadingOverlay(isShowing: $isLoading, text: "Importing...")
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
                    isLoading = true

                    await viewModel.importLeads(
                        importName: importName,
                        tagName: tagName,
                        domainId: domain.id
                    )

                    isLoading = false
                    domain.updateTagsInfo()
                    ToastManager.shared.show(style: .success, message: "Import Complete")
                    mode = .view
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
    @ObservedObject var viewModel: ImportsViewModel
    
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
//        .frame(height: 400)
    }
}

private struct TextImportView: View {
    @ObservedObject var viewModel: ImportsViewModel
    
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


