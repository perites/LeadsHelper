//
//  ImportViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import Foundation
import SwiftUI
import TabularData

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
        tagId: Int64,
        domainId: Int64
    ) async -> ImportResult {
        let start = Date()
        guard let emails = emailsAll else {
            return .loading
        }
        
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
        var allEmails: [String] = []
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let options = CSVReadingOptions(
                hasHeaderRow: true,
                delimiter: ","
            )
            let dataFrame = try? DataFrame(contentsOfCSVFile: url, options: options)
            guard let dataFrame else { continue }
            
            let emailsFromFile = extractValidEmails(from: dataFrame)
            allEmails.append(contentsOf: emailsFromFile ?? [])
        }
        
        let uniqueEmails = Array(Set(allEmails))
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
            emailsFromFiles = uniqueEmails
        }
    }
    
    private func getLeadsFromText(text: String) async {
        guard let csvData = text.data(using: .utf8) else { return }
        let dataFrame = try? DataFrame(csvData: csvData)
        guard let dataFrame else { return }
        let emails = extractValidEmails(from: dataFrame)
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
            emailsFromText = Array(emails ?? [])
        }
    }
    
    func extractValidEmails(from dataFrame: DataFrame) -> Set<String>? {
        guard let emailColumn = dataFrame.columns.first(where: {
            $0.name
                .lowercased()
                .trimmingCharacters(in: .whitespaces)
                .contains("email")
        }) else {
//                throw EmailParseError.noEmailColumnFound
            return []
        }
      
        let emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        
        let emailColumnValues = dataFrame[emailColumn.name, String.self]

        let validEmails = Set(
            emailColumnValues
                .compactMap { $0 }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.wholeMatch(of: emailRegex) != nil }
        )
        
        return validEmails
    }
}
