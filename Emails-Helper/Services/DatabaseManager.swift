//
//  DatabaseManager.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import Foundation
import SQLite

// SQLite Manager
class DatabaseManager {
    static let shared = DatabaseManager()

    var db: Connection!

    init() {
        do {
            db = try Connection("emails-helper-db.sqlite3")
            try db.run("PRAGMA foreign_keys = ON")

//            try db.run(LeadsTable.table.drop(ifExists: true))
//            try db.run(TagsTable.table.drop(ifExists: true))
//            try db.run(ImportsTable.table.drop(ifExists: true))
//            try db.run(DomainsTable.table.drop(ifExists: true))
//            print("Database cleaned")

            LeadsTable.createTable(in: db)
            DomainsTable.createTable(in: db)
            TagsTable.createTable(in: db)
            ImportsTable.createTable(in: db)

        } catch {
            print("DB Error: \(error)")
        }
    }
}

enum TagsTable {
    static let table = Table("tags")
    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let domainId = SQLite.Expression<Int64>("domainId")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(domainId)

                    t.foreignKey(
                        domainId,
                        references: DomainsTable.table,
                        DomainsTable.id,
                        delete: .cascade
                    )
                })
        } catch {
            print("Error creating Tags table: \(error)")
        }
    }

    static func findByName(name: String, domainId: Int64) -> Int64? {
        guard let db = DatabaseManager.shared.db else { return nil }

        do {
            let query = table.filter((self.name == name) && (self.domainId == domainId))
            let tag = try db.pluck(query)

            return tag?[id]
        } catch {
            print("Error fetching domain by ID: \(error)")
            return nil
        }
    }

    static func addTag(newName: String, newDomainId: Int64) -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                domainId <- newDomainId,
            )

            if let rowId = try DatabaseManager.shared.db?.run(insert) {
                return rowId
            }

            return nil
        } catch {
            print("Failed to add tag: \(error)")
            return nil
        }
    }
}

enum ImportsTable {
    static let table = Table("imports")

    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let dateCreated = SQLite.Expression<Date>("dateCreated")
    static let type = SQLite.Expression<Int>("type")
    static let tagId = SQLite.Expression<Int64>("tagId")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(dateCreated)
                    t.column(type)
                    t.column(tagId)
                    t.foreignKey(
                        tagId,
                        references: TagsTable.table,
                        TagsTable.id,
                        delete: .cascade
                    )

                })
        } catch {
            print("Error creating Imports table: \(error)")
        }
    }

    static func addImport(newName: String, newTagId: Int64, newType: Int) -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                dateCreated <- Date(),
                type <- newType,
                tagId <- newTagId,
            )

            if let rowId = try DatabaseManager.shared.db?.run(insert) {
                return rowId
            }

            return nil
        } catch {
            print("Failed to add import: \(error)")
            return nil
        }
    }
}

enum LeadsTable {
    static let table = Table("leads")

    static let id = SQLite.Expression<Int64>("id")
    static let email = SQLite.Expression<String>("email")
    static let tagId = SQLite.Expression<Int64>("tagId")
    static let importId = SQLite.Expression<Int64>("importId")

    static let isActive = SQLite.Expression<Bool>("isActive")

    static let randomOrder = SQLite.Expression<Double>("randomOrder")

    static let lastUsedAt = SQLite.Expression<Date?>("lastUsedAt")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(email)
                    t.column(tagId)
                    t.column(importId)

                    t.column(isActive)

                    t.column(randomOrder)

                    t.column(lastUsedAt)

                    t.foreignKey(
                        tagId,
                        references: TagsTable.table,
                        TagsTable.id,
                        delete: .cascade
                    )

                    t.foreignKey(
                        importId,
                        references: ImportsTable.table,
                        ImportsTable.id,
                        delete: .cascade
                    )

                    t.unique(email, tagId)

                })

        } catch {
            print("Error creating Leads table: \(error)")
        }
    }

    static func addLeadsBulk(newEmails: [String], newImportId: Int64, newTagId: Int64) {
        guard let db = DatabaseManager.shared.db else { return }

        do {
            try db.transaction {
                for newEmail in newEmails {
                    let sql = """
                        INSERT INTO leads (email, tagId, importId, isActive, randomOrder)
                        VALUES (?, ?, ?, 1, ?)
                        ON CONFLICT(email, tagId) DO UPDATE SET isActive = 1;
                    """
                    try db.run(sql, [newEmail, newTagId, newImportId, Double.random(in: 0 ..< 1)])
                }
            }
            print(" Successfully inserted \(newEmails.count) leads in one transaction")
        } catch {
            print("Failed to add leads: \(error)")
        }
    }

    static func countLeads(with tagId: Int64, isActive: Bool = true) -> Int {
        guard let db = DatabaseManager.shared.db else { return 0 }

        let query = table.filter(
            (self.tagId == tagId) && (Self.isActive == isActive)
        )

        do {
            let count = try db.scalar(query.count)
            return count
        } catch {
            print("Failed count leads with tag \(tagId): \(error)")
            return 0
        }
    }

    static func getEmails(with tagId: Int64, amount: Int) -> [String] {
        guard let db = DatabaseManager.shared.db else { return [] }

        let query = table.filter((self.tagId == tagId) && (isActive == true))
            .order(randomOrder)
            .limit(amount)

        var result: [String] = []
        var deactivateIDs: [Int64] = []

        do {
            try db.transaction {
                for row in try db.prepare(query) {
                    result.append(row[LeadsTable.email])
                    deactivateIDs.append(row[LeadsTable.id])
                }

                if !deactivateIDs.isEmpty {
                    let deactivateQuery = LeadsTable.table.filter(deactivateIDs.contains(LeadsTable.id))
                    try db.run(deactivateQuery.update(LeadsTable.isActive <- false))
                    print("🧹 Deactivated \(deactivateIDs.count) leads")
                }
            }

            return result
        } catch {
            print("Failed to get leads: \(error)")
            return []
        }
    }
}

enum DomainsTable {
    static let table = Table("domains")

    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let abbreviation = SQLite.Expression<String>("abbreviation")
    static let exportType = SQLite.Expression<Int>("exportType")
    static let saveFolder = SQLite.Expression<Blob?>("saveFolder")
    static let lastExportRequest = SQLite.Expression<String?>("lastExportRequest")
    
    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(abbreviation)
                    t.column(exportType)
                    t.column(saveFolder)
                    t.column(lastExportRequest)

                })

        } catch {
            print("Error creating Domains table: \(error)")
        }
    }

    static func findById(id: Int64) -> Row? {
        guard let db = DatabaseManager.shared.db else { return nil }

        do {
            let query = table.filter(self.id == id)
            return try db.pluck(query)
        } catch {
            print("Error fetching domain by ID: \(error)")
            return nil
        }
    }

    static func addDomain(newName: String) -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                abbreviation <- "ABC",
                exportType <- 0,
            )
            if let rowId = try DatabaseManager.shared.db?.run(insert) {
                return rowId
            }

            return nil
        } catch {
            print("Failed to add domain: \(error)")
            return nil
        }
    }
}
