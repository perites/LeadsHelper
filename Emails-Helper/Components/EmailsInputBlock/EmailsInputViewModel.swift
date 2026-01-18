//
//  EmailsInputViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//

import SwiftUI
import TabularData

class EmailsInputViewModel: ObservableObject {
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

    var inputType: Int? {
        if let files = emailsFromFiles, let text = emailsFromText {
            if !files.isEmpty && !text.isEmpty {
                return 3
            } else if !files.isEmpty {
                return 1
            } else if !text.isEmpty {
                return 2
            }
        }

        return nil
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
            guard let dataFrame = Self.getDataFrameFrom(url: url) else { continue }
            
            let emailsFromFile = Self.extractValidEmails(
                from: dataFrame,
                sourceName: url.lastPathComponent
            )
            
            allEmails.append(contentsOf: emailsFromFile)
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
        let emails = Self.extractValidEmails(from: dataFrame, sourceName: "Input Text")
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
            emailsFromText = Array(emails)
        }
    }
    
    static func getDataFrameFrom(url: URL) -> DataFrame? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let options = CSVReadingOptions(
            hasHeaderRow: true,
            delimiter: ","
        )
        let dataFrame = try? DataFrame(contentsOfCSVFile: url, options: options)
        
        return dataFrame
    }
    
    static func extractValidEmails(from dataFrame: DataFrame, sourceName: String) -> Set<String> {
        guard let emailColumn = dataFrame.columns.first(where: {
            $0.name
                .lowercased()
                .trimmingCharacters(in: .whitespaces)
                .contains("email")
        }) else {
            Task { await MainActor.run {
                ToastManager.shared
                    .show(
                        style: .warning,
                        message: "'Email' column not found in \(sourceName)",
                        duration: 100,
                        removeSameOld: true,
                    )
                
            }}
            
            return []
        }
        
        if sourceName == "Input Text" {
            Task { await MainActor.run {
                ToastManager.shared.dismissAll(message: "'Email' column not found in Input Text")
                
            }}
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
