//
//  DomainDetailView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import AppKit
import SwiftUI

enum Mode: String {
    case edit
    case view
    case importLeads
    case exportLeads
    case deleted
}

struct DomainDetailView: View {
    @Binding var domain: Domain
    @State private var mode: Mode = .view
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch mode {
            case .view:
                DomainInfoView(mode: $mode, domain: $domain)
            case .edit:
                EditDomainView(
                    mode: $mode,
                    originalDomain: $domain,
                    domain: domain
                )
            case .importLeads:
                ImportLeadsView(mode: $mode, domain: $domain)
            case .exportLeads:
                DomainExportView(mode: $mode, domain: $domain)
            case .deleted:
                DeleteDomainView()
            }
        }
        .padding()
        .navigationTitle(domain.abbreviation)
        .toolbar {
            Button(action: { mode = .edit }) {
                Image(systemName: "gearshape")
            }
        }.frame(minWidth: 550, idealWidth: 550)
    }
}

struct DeleteDomainView: View {
    var body: some View {
        Text("Deleted Domain")
    }
}

struct EditDomainView: View {
    @Binding var mode: Mode
    @Binding var originalDomain: Domain
    
    @State var domain: Domain
    
    var body: some View {
        TextField("Name", text: $domain.name)
            .textFieldStyle(.roundedBorder)
        
        TextField("Abbreviation", text: $domain.abbreviation)
            .textFieldStyle(.roundedBorder)
        
        Picker("Export Type", selection: $domain.exportType) {
            Text("Regular").tag(0)
            Text("Exact Target").tag(1)
            Text("Blueshift").tag(2)
        }
        .pickerStyle(.segmented)
        Text(domain.saveFolder != nil ?
            "Save Folder: \(domain.saveFolder!.path)" :
            "Save Folder: Not Set")

        Button("Change Directory") {
            if let url = pickFolder(startingAt: domain.saveFolder) {
                domain.saveFolder = url
            }
        }
        
        HStack {
            Button("Cancel") {
                mode = .view
            }
            Button("Save") {
                domain.update()
                originalDomain = domain
                mode = .view
            }
            .buttonStyle(.borderedProminent)
            
            Button("Delete Domain") {
                domain.delete()
                domain.deleted = true
                
                originalDomain.delete()
                originalDomain.deleted = true
                
                mode = .deleted
            }
        }
    }
    
    func pickFolder(startingAt initialURL: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        // Set initial directory
        if let initialURL = initialURL {
            panel.directoryURL = initialURL
        }

        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}

struct ImportLeadsView: View {
    @State var importName: String = ""
    @State var emailsFromFiles: [String]? = []
    
    @Binding var mode: Mode
    @Binding var domain: Domain
    
    var body: some View {
        TextField("Import Name", text: $importName)
        SelectFilesView(emailsFromFiles: $emailsFromFiles)
        Button("Import") {
            let start = Date()
            importContacts()
            let timeElapsed = Date().timeIntervalSince(start)
            print("Import took \(timeElapsed) seconds.")
        }
        
        Button("Cancel") {
            mode = .view
        }
    }
    
    private func importContacts() {
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
