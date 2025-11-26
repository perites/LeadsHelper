//
//  DownloadViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 09/11/2025.
//

import SQLite
import SwiftUI
import TabularData

enum ActivityState: String, CaseIterable, Identifiable {
    case all = "All Leads"
    case active = "Active Only"
    case inactive = "Inactive Only"

    var id: String { rawValue }
}

enum DownloadField: CaseIterable, Identifiable {
    case email
    case isActive
    case lastUsedAt
    case tagName
    case importName
    case dateImported

    var id: String { label }

    var label: String {
        switch self {
        case .email: return "Email"
        case .isActive: return "Is Active"
        case .lastUsedAt: return "Last Used"
        case .tagName: return "Tag Name"
        case .importName: return "Import Name"
        case .dateImported: return "Date Imported"
        }
    }

    var expression: Expressible {
        switch self {
        case .email: return LeadsTable.table[LeadsTable.email]
        case .isActive: return LeadsTable.table[LeadsTable.isActive]
        case .lastUsedAt: return LeadsTable.table[LeadsTable.lastUsedAt]
        case .tagName: return TagsTable.table[TagsTable.name]
        case .importName: return ImportsTable.table[ImportsTable.name]
        case .dateImported: return ImportsTable.table[ImportsTable.dateCreated]
        }
    }

    func extract(from row: Row) -> String {
        switch self {
        case .email: return row[expression as! SQLite.Expression<String>]

        case .isActive: return row[expression as! SQLite.Expression<Bool>] ? "Active" : "Inactive"

        case .lastUsedAt:
            if let date = row[expression as! SQLite.Expression<Date?>] {
                return dateFormatter.string(from: date)
            }
            return ""

        case .tagName: return row[expression as! SQLite.Expression<String>]

        case .importName: return row[expression as! SQLite.Expression<String>]

        case .dateImported:
            let date = row[expression as! SQLite.Expression<Date>]
            return dateFormatter.string(from: date)
        }
    }
}

class DownloadViewModel: ObservableObject {
    enum DownloadResult {
        case success
        case failure
    }

    func downloadLeads(domainId: Int64, fileURL: URL, fieldsToInclude: Set<DownloadField>, downloadAllTags: Bool, selectedTagId: Int64?, activityState: ActivityState) async -> DownloadResult {

        let columns = fieldsToInclude.map(\.expression)
        let fieldsToInclude = fieldsToInclude.map { field in
            (label: field.label, extract: field.extract)
        }.sorted(by: { $0.label < $1.label })

        var fieldsValues = fieldsToInclude.reduce(into: [String: [String]]()) { dict, field in
            dict[field.label] = []
        }

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

        if downloadAllTags {
            query = query.filter(TagsTable.table[TagsTable.domainId] == domainId)
        } else {
            query = query.filter(LeadsTable.table[LeadsTable.tagId] == selectedTagId!)
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

            for row in try await DatabaseActor.shared.dbFetch(query){
                for field in fieldsToInclude {
                    fieldsValues[field.label]?
                        .append(field.extract(row))
                }
            }

            for field in fieldsToInclude {
                let values = fieldsValues[field.label] ?? []
                dataFrame.append(column: Column(name: field.label, contents: values))
            }
            let finalFileUrl = await ExportViewModel.ensureNameIsUnique(
                for: fileURL
            )
            try dataFrame.writeCSV(to: finalFileUrl)
            return .success

        } catch {
            print("❌ Download failed:", error)
            return .failure
        }
    }
}
