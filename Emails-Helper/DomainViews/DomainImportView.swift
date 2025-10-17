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
    @State var emailsFromFiles: [String]? = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            ImportNameInputView
            Spacer()
            SelectFilesView(emailsFromFiles: $emailsFromFiles)
            Spacer()
            HStack {
                GoBackButtonView(mode: $mode)
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
        let emails = emailsFromFiles!
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

struct SelectFilesView: View {
    @Binding var emailsFromFiles: [String]?
    
    @State var selectedFiles: [URL] = []
    @State private var isFileImporterPresented = false
        
    var body: some View {
        VStack {
            HStack {
                FilesPicker
                SelectedFiles
            }
            Text("Contacts Amount from files: \(emailsFromFiles.map { String($0.count) } ?? "Loading...")")
                
        }.task(id: selectedFiles) {
            emailsFromFiles = nil
            let emails: [String] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .background).async {
                    var csvData = ""
                    for url in selectedFiles {
                        guard url.startAccessingSecurityScopedResource() else {
                            print("Cannot access file: \(url)")
                            continue
                        }
                        defer { url.stopAccessingSecurityScopedResource() } // runs after scope ends

                        if let data = try? String(contentsOf: url, encoding: .utf8) {
                            csvData += data
                        }
                    }
                    let result = getEmailsFromString(csvData)
                    continuation.resume(returning: result)
                }
            }
            await MainActor.run {
                emailsFromFiles = emails
            }
        }
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
        
    var FilesPicker: some View {
        Button("Select Files") {
            isFileImporterPresented.toggle()
        }
        .padding()
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                selectedFiles = Array(Set(selectedFiles + urls))
            case .failure(let error):
                print("Error selecting files: \(error)")
            }
        }
    }
        
    var SelectedFiles: some View {
        List {
            ForEach(selectedFiles, id: \.self) { file in
                HStack {
                    Text(file.lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        if let index = selectedFiles.firstIndex(of: file) {
                            selectedFiles.remove(at: index)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .frame(height: CGFloat(selectedFiles.count * 40))
    }
}
