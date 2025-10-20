//
//  ImportViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

class ImportViewModel: ObservableObject {
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
    
    enum ImportResult {
        case loading
        case failure
        case success
    }

    func importLeads(
        importName: String,
        tagName: String,
        domainId: Int64
    ) async -> ImportResult {
        let start = Date()
        guard let emails = emailsAll else {
            return .loading
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
        return .success
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
