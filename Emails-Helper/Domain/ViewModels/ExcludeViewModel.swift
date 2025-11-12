//
//  ExcludeViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//

import Foundation
import SQLite

class ExcludeViewModel: ObservableObject {
    enum ExcludeResult {
        case failure
        case success
    }

    func excludeLeads(
        domainId: Int64,
        excludeFromAll: Bool,
        selectedTagId: Int64?,
        allEmails: [String]
    ) async -> ExcludeResult {
        let start = Date()

        guard let db = DatabaseManager.shared.db else { return .failure }

        let uniqueEmails = Set(allEmails)
        if uniqueEmails.isEmpty {
            print("ℹ️ Exclude complete: 0 leads provided.")
            return .success
        }

        let tempTableName = "temp_exclude_\(Int64.random(in: 1000 ... 9999))"

        do {
            try db.run("CREATE TEMPORARY TABLE \(tempTableName) (email TEXT PRIMARY KEY) WITHOUT ROWID;")

            try db.transaction {
                let stmt = try db.prepare("INSERT OR IGNORE INTO \(tempTableName) (email) VALUES (?)")
                for email in uniqueEmails {
                    try stmt.run(email)
                }
            }

            let (tagFilterSQL, bindings) = try buildFilter(
                domainId: domainId,
                excludeFromAll: excludeFromAll,
                selectedTagId: selectedTagId
            )

            
            let updateSQL = """
            UPDATE leads
            SET \(LeadsTable.isActive.template) = 0
            WHERE
                \(tagFilterSQL)
                AND \(LeadsTable.email.template) IN (SELECT email FROM \(tempTableName))
            """

            try db.run(updateSQL, bindings)


            try db.run("DROP TABLE IF EXISTS \(tempTableName)")

            let timeElapsed = Date().timeIntervalSince(start)
            print("✅ Exclude complete: leads deactivated in \(String(timeElapsed)) seconds")
            return .success

        } catch {
            print("❌ Exclude leads failed: \(error)")
            let result = try? db.run("DROP TABLE IF EXISTS \(tempTableName)")
            return .failure
        }
    }

    private func buildFilter(
        domainId: Int64,
        excludeFromAll: Bool,
        selectedTagId: Int64?
    ) throws -> (sql: String, bindings: [SQLite.Binding]) {
        if excludeFromAll {
            let sql = "\(LeadsTable.tagId.template) IN (SELECT \(TagsTable.id.template) FROM tags WHERE \(TagsTable.domainId.template) = ?)"
            return (sql, [domainId])

        } else {
            guard let tagId = selectedTagId else {
                print("Error: selectedTagId is nil but excludeFromAll is false.")
                throw NSError(domain: "ExcludeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid parameters"])
            }
            let sql = "\(LeadsTable.tagId.template) = ?"
            return (sql, [tagId])
        }
    }
}
