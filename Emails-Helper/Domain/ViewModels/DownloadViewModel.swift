//
//  DownloadViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 09/11/2025.
//

import SQLite
import SwiftUI
import TabularData

// MARK: - Enums for Pickers

/// Defines the state of leads to download
enum ActivityState: String, CaseIterable, Identifiable {
    case all = "All Leads"
    case active = "Active Only"
    case inactive = "Inactive Only"
    
    var id: String { rawValue }
}

/// Defines the fields that can be included in the download
enum DownloadField: String, CaseIterable, Identifiable {
    case email = "Email"
    case isActive = "Is Active"
    case lastUsedAt = "Last Used"
    case tagName = "Tag Name"
    case importName = "Import Name"
    case dateImported = "Date Imported"
    
    var id: String { rawValue }
}

/// Result of the download operation
enum DownloadResult {
    case success
    case failure
    case noFolder
}

// MARK: - DownloadViewModel

class DownloadViewModel: ObservableObject {
    // MARK: - Properties
    
    let domain: DomainViewModel
    
    // Header
    @Published var fileName: String
    
    // Selection
    @Published var downloadAllTags: Bool
    @Published var selectedTagId: Int64?
    @Published var activityState: ActivityState = .all
    @Published var fieldsToInclude: Set<DownloadField> = [.email] // Default to email only
    
    // MARK: - Init
    
    init(domain: DomainViewModel, downloadAllTags: Bool, selectedTagId: Int64?) {
        self.domain = domain
        // Default to the first tag in the list, if one exists
        self.selectedTagId = selectedTagId
        self.downloadAllTags = downloadAllTags
        
        self.fileName = "\(domain.abbreviation)-download-\(downloadAllTags ? "all-tags" : "selected-tag")"
    }
    
    // MARK: - Public Methods
    
    func downloadLeads() async -> DownloadResult {
        // 1. Get Save Path (Unchanged)
        guard let saveFolderURL = domain.saveFolder else {
            return .noFolder
        }
        let finalFileName = "\(fileName.isEmpty ? "download" : fileName).csv"
        let fileURL = saveFolderURL.appendingPathComponent(finalFileName)

        // 2. Build SQL Query
        guard let db = DatabaseManager.shared.db else { return .failure }

        var selectedFields: [(field: DownloadField, extract: (Row) -> String)] = []
        var columns: [Expressible] = []
            
        let dateFormatter = ISO8601DateFormatter()
        let allFields: [DownloadField] = [.email, .isActive, .lastUsedAt, .tagName, .importName, .dateImported]

        for field in allFields {
            guard fieldsToInclude.contains(field) else { continue }
                
            switch field {
            case .email:
                let expr = LeadsTable.table[LeadsTable.email]
                columns.append(expr)
                selectedFields.append((field, { row in row[expr] ?? "" }))
                    
            case .isActive:
                let expr = LeadsTable.table[LeadsTable.isActive]
                columns.append(expr)
                selectedFields.append((field, { row in (row[expr] == true) ? "Active" : "Inactive" }))
                    
            case .lastUsedAt:
                let expr = LeadsTable.table[LeadsTable.lastUsedAt]
                columns.append(expr)
                // This is correct because lastUsedAt is optional (Date?)
                selectedFields.append((field, { row in
                    if let date = row[expr] { return dateFormatter.string(from: date) }
                    return ""
                }))
                    
            case .tagName:
                let expr = TagsTable.table[TagsTable.name]
                columns.append(expr)
                selectedFields.append((field, { row in row[expr] ?? "" }))
                    
            case .importName:
                let expr = ImportsTable.table[ImportsTable.name]
                columns.append(expr)
                selectedFields.append((field, { row in row[expr] ?? "" }))
                    
            //
            // --- THIS IS THE FIX ---
            //

            case .dateImported:
                let expr = ImportsTable.table[ImportsTable.dateCreated]
                columns.append(expr)
                // 'dateCreated' is non-optional 'Date', so we don't use 'if let'
                selectedFields.append((field, { row in
                    let date = row[expr] // Get the value directly
                    return dateFormatter.string(from: date)
                }))
            }
        }
            
        if selectedFields.isEmpty {
            let expr = LeadsTable.table[LeadsTable.email]
            columns.append(expr)
            selectedFields.append((.email, { row in row[expr] ?? "" }))
        }

        // Build query (This part is all correct)
        var query = LeadsTable.table
            .select(columns)
            .join(
                TagsTable.table,
                on: LeadsTable.table[LeadsTable.tagId] == TagsTable.table[TagsTable.id]
            )
            .join(
                ImportsTable.table,
                on: LeadsTable.table[LeadsTable.importId] == ImportsTable.table[ImportsTable.id]
            )
            .filter(TagsTable.table[TagsTable.domainId] == domain.id)
                
        if !downloadAllTags, let tagId = selectedTagId {
            query = query.filter(LeadsTable.table[LeadsTable.tagId] == tagId)
        }
            
        switch activityState {
        case .active:
            query = query.filter(LeadsTable.table[LeadsTable.isActive] == true)
        case .inactive:
            query = query.filter(LeadsTable.table[LeadsTable.isActive] == false)
        case .all:
            break
        }

        do {
            var dataFrame = DataFrame()
            var dataColumns = selectedFields.reduce(into: [String: [String]]()) { dict, pair in
                dict[pair.field.rawValue] = []
            }

            // This part is correct
            for row in try db.prepare(query) {
                for (field, extract) in selectedFields {
                    dataColumns[field.rawValue]?.append(extract(row))
                }
            }
                    
            //
            // --- THIS IS THE FIX ---
            //
            // Instead of looping over the unordered 'dataColumns' dictionary,
            // we loop over your 'selectedFields' array, which IS in order.
            //
            for (field, _) in selectedFields {
                let colName = field.rawValue
                        
                // Get the data from the dictionary using the ordered name
                let values = dataColumns[colName] ?? []
                        
                // Append the column in the correct order
                dataFrame.append(column: Column(name: colName, contents: values))
            }
                    
            try dataFrame.writeCSV(to: fileURL)
            return .success
                    
        } catch {
            print("❌ Download failed:", error)
            return .failure
        }
    }
}
