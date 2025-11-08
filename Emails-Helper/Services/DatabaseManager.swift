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
            db = try databaseConnection()
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
            
            
            
//            for row in try! db.prepare(LeadsTable.table) {
//                print(row[LeadsTable.email])
//                print(row[LeadsTable.lastUsedAt] as Any)
//            }
//
            
            
//            for row in try db.prepare("SELECT email, lastUsedAt, typeof(lastUsedAt) FROM leads") {
//                print(row)
//            }

            
            

        } catch {
            print("DB Error: \(error)")
        }
    }
    
    


    func databaseConnection() throws -> Connection {
        let fm = FileManager.default

        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folder = appSupport.appendingPathComponent("EmailsHelper", isDirectory: true)

        if !fm.fileExists(atPath: folder.path) {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let dbURL = folder.appendingPathComponent("emails-helper-db.sqlite3")

        return try Connection(dbURL.path)
    }

    
    
}

enum TagsTable {
    static let table = Table("tags")
    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let domainId = SQLite.Expression<Int64>("domainId")
    static let isActive = SQLite.Expression<Bool>("isActive")
    
    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(domainId)
                    t.column(isActive)
                    t.foreignKey(
                        domainId,
                        references: DomainsTable.table,
                        DomainsTable.id,
                        delete: .cascade
                    )
                    
                    
                    t.unique(name, domainId)
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
                isActive <- true
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
    
    static func renameTag(id: Int64, to newName: String) {
        guard let db = DatabaseManager.shared.db else { return }
        let tag = table.filter(self.id == id)
        do {
            let update = tag.update(name <- newName)
            try db.run(update)
        } catch {
            print("Failed to rename tag \(id): \(error)")
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
                        ON CONFLICT(email, tagId) DO UPDATE SET isActive = 1, importId = excluded.importId;
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

    
    static func getEmails(
        with tagId: Int64,
        domainId: Int64,
        amount: Int,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) -> [String] {

        guard let db = DatabaseManager.shared.db else { return [] }

        // Compute cutoff dates
        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -domainUseLimit, to: Date()) ?? Date.distantPast
        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast

        let dateFormatter = ISO8601DateFormatter()
        let domainCutoffString = dateFormatter.string(from: domainCutoffDate)
        let globalCutoffString = dateFormatter.string(from: globalCutoffDate)

        let sql = """
        WITH globalRecent AS (
            SELECT email, MAX(lastUsedAt) AS globalLastUsed
            FROM leads
            GROUP BY email
        ),
        domainRecent AS (
            SELECT l.email, MAX(l.lastUsedAt) AS domainLastUsed
            FROM leads l
            JOIN tags t ON l.tagId = t.id
            WHERE t.domainId = ?
            GROUP BY l.email
        )
        SELECT L.id, L.email
        FROM leads L
        JOIN tags T ON L.tagId = T.id
        LEFT JOIN globalRecent G ON L.email = G.email
        LEFT JOIN domainRecent D ON L.email = D.email
        WHERE L.tagId = ?
          AND L.isActive = 1
          AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
          AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
        ORDER BY L.randomOrder
        LIMIT ?;
        """

        var emails: [String] = []
        var idsToDeactivate: [Int64] = []

        do {
            try db.transaction {
                // 1) Fetch leads to use
                let stmt = try db.prepare(sql, domainId, tagId, globalCutoffString, domainCutoffString, amount)

                for row in stmt {
                    if let id = row[0] as? Int64,
                       let email = row[1] as? String {
                        idsToDeactivate.append(id)
                        emails.append(email)
                    }
                }

                // 2) Mark these leads as used
                if !idsToDeactivate.isEmpty {
                    let placeholders = idsToDeactivate.map { _ in "?" }.joined(separator: ",")
                    let deactivateSQL = """
                    UPDATE leads
                    SET isActive = 0,
                        lastUsedAt = CURRENT_TIMESTAMP
                    WHERE id IN (\(placeholders));
                    """

                    try db.run(deactivateSQL, idsToDeactivate)
                    print("🧹 Deactivated \(idsToDeactivate.count) leads")
                }
            }

            return emails

        } catch {
            print("❌ getEmails failed:", error)
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
    static let useLimit = SQLite.Expression<Int>("useLimit")
    static let globalUseLimit = SQLite.Expression<Int>("globalUseLimit")
    
    static let isActive = SQLite.Expression<Bool>("isActive")
    
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
                    t.column(useLimit)
                    t.column(globalUseLimit)
                    t.column(isActive)
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
                useLimit <- 0,
                globalUseLimit <- 0,
                isActive <- true
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
