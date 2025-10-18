//
//  DomainImportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 17/10/2025.
//

import SwiftUI

struct DomainImportView: View {
    @Binding var mode: Mode
    @Binding var domain: Domain
    
    @State var importName: String = ""
    @State var emailsFromFiles: [String]? = nil
    @State var emailsFromText: [String]? = nil
    
    var emailsAll: [String]? {
        if emailsFromText != nil && emailsFromFiles != nil {
            return Array(Set(emailsFromText! + emailsFromFiles!))
        } else {
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImportNameInputView
            
            Divider()

            HStack {
                FilesImportView(emailsFromFiles: $emailsFromFiles)
                TextImportView(emailsFromText: $emailsFromText)
            }
            
            Divider()
            HStack {
                GoBackButtonView(mode: $mode)
                Spacer()
                Text(
                    "Total Leads: \(emailsAll?.count.formatted(.number) ?? "Calculating...")"
                )
                Spacer()
                ImportButton
            }
            .padding(.top, 10)
        }.padding()
    }
    
    private var ImportNameInputView: some View {
        HStack {
            Text("Import Name:")
                .font(.title3)
            TextField("Enter import name", text: $importName)
                .font(.title3)
                .textFieldStyle(PlainTextFieldStyle())
        }
    }
    
    private var ImportButton: some View {
        Button(action: {
            let start = Date()
            importLeads()
            let timeElapsed = Date().timeIntervalSince(start)
            print("Import took \(timeElapsed) seconds.")
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

    private func importLeads() {
        guard let emails = emailsAll else {
            ToastManager.shared
                .show(style: .error, message: "Leads exported successfully")
            return
        }
        LeadsTable
            .addLeadsBulk(
                newEmails: emails,
                newImportName: importName,
                newDomain: domain.id
            )
        
        domain.importNames.append(importName)
        domain.importNames = Array(Set(domain.importNames)).sorted()
        domain.update()
        mode = .view
    }
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

private struct FilesImportView: View {
    @Binding var emailsFromFiles: [String]?
    
    @State var selectedFiles: [URL] = []
    @State private var isFileImporterPresented = false
    
    @State private var parseTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            HStack {
                Text("Files Import").font(.title3).fontWeight(.semibold)
                Spacer()
                SelectFilesButton
            }
            
            SelectedFiles
            
            Text(
                "Leads from files: \(emailsFromFiles?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
                
        }.onChange(of: selectedFiles, initial: true) { _, newSelectedFiles in
            parseTask?.cancel()
            
            emailsFromFiles = nil
            parseTask = Task.detached { [newSelectedFiles] in
                var combined = ""
                for url in newSelectedFiles {
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
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func readCSV(from url: URL) -> String {
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            return data
        } catch {
            print("Error reading file:", error)
            return ""
        }
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
    @Binding var emailsFromText: [String]?
    
    @State var textInput: String = ""
    
    @State private var parseTask: Task<Void, Never>? = nil

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
                "Leads from files: \(emailsFromText?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
            
        }.onChange(of: textInput, initial: true) { _, newText in
            parseTask?.cancel() // cancel previous parsing
            emailsFromText = nil
            
            parseTask = Task.detached { [newText] in
                // Heavy parsing
                let emails = getEmailsFromString(newText)
                
                // Only update if not cancelled
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    emailsFromText = emails
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
