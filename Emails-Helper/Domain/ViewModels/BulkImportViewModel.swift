//
//  BulkImportViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 08/11/2025.
//

import SwiftUI

import SwiftUI
import TabularData

class ImportFile: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    
    // By publishing these, individual rows in your view
    // can update themselves when parsing is done.
    @Published var tagId: Int64?
    @Published var emails: [String]?
    @Published var task: Task<Void, Never>?
    
    // Initializer
    init(url: URL, tagId: Int64? = nil, emails: [String]? = nil, task: Task<Void, Never>? = nil) {
        self.url = url
        self.tagId = tagId
        self.emails = emails
        self.task = task
    }
    
    // No longer 'mutating'
    func getEmails() {
        // Don't start a new task if one is already running
        guard task == nil else { return }
        
        task = Task(priority: .userInitiated) {
            var allEmails: [String] = []

            guard let dataFrame = ImportViewModel.getDataFrameFrom(url: url) else { return }

            let emailsFromFile = ImportViewModel.extractValidEmails(from: dataFrame)

            allEmails.append(contentsOf: emailsFromFile ?? [])

            let uniqueEmails = Array(Set(allEmails))
            
            // This is critical for App Sandbox
            
            // --- End Parsing ---

            // Check if the task was cancelled
            guard !Task.isCancelled else { return }
            
            // Call the helper to update on the main thread
            await self.finishTask(with: uniqueEmails)
        }
    }
    
    // Helper to update state on the main thread
    @MainActor
    private func finishTask(with uniqueEmails: [String]?) {
        emails = uniqueEmails
        task = nil // Mark task as complete
    }
    
    // Call this if the file is removed, to stop parsing
    func cancelTask() {
        task?.cancel()
    }
}

class BulkImportViewModel: ObservableObject {
    @Published var importFiles: [ImportFile] = []
    
    enum ImportResult {
        case loading
        case failure
        case success
        case tagNotSet
    }
    
    func importLeads(importName: String) async -> ImportResult {
        let start = Date()
        
        guard importFiles.filter({ $0.emails == nil }).isEmpty else {
            return .loading
        }
        
        guard importFiles.filter({ $0.tagId == nil }).isEmpty else {
            return .tagNotSet
        }
        
        for importFile in importFiles {
            let importId = ImportsTable.addImport(
                newName: importName,
                newTagId: importFile.tagId!,
                newType: 1
            )!
            
            LeadsTable.addLeadsBulk(
                newEmails: importFile.emails!,
                newImportId: importId,
                newTagId: importFile.tagId!
            )
        }
        
        let timeElapsed = Date().timeIntervalSince(start)
        print("Import took \(timeElapsed) seconds.")
        return .success
    }
    
    func updateSelectedFiles(_ urls: [URL]) {
        let existingURLs = Set(importFiles.map { $0.url })
        let newURLs = urls.filter { !existingURLs.contains($0) }
                
        // Don't do anything if there are no new files
        guard !newURLs.isEmpty else { return }

        for url in newURLs {
            // 2. Create the file struct and get its unique ID
            let newFile = ImportFile(url: url)
            newFile.getEmails()
            importFiles.append(newFile)
        }
    }
    
    func removeImportFile(importFile: ImportFile) {
        importFile.cancelTask()
        importFiles.removeAll { $0.id == importFile.id }
    }
}
