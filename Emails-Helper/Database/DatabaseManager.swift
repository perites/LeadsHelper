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
            
            
            
//            try db.run("""
//                CREATE INDEX IF NOT EXISTS idx_leads_tag_active
//                ON Leads(tagId, isActive, email);
//            """)
//
//
//            try db.run("""
//               CREATE INDEX IF NOT EXISTS idx_tags_domain_active
//               ON Tags(domainId, isActive);
//            """)

            

            
            
//            for row in try! db.prepare(TagsTable.table) {
//                print(row[TagsTable.name])
//                print(row[TagsTable.id])
//            }

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
        print(dbURL)
        return try Connection(dbURL.path)
    }
}

enum TagsTable {
    static let table = Table("tags")
    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let domainId = SQLite.Expression<Int64>("domainId")
    static let isActive = SQLite.Expression<Bool>("isActive")
    static let idealAmount = SQLite.Expression<Int>("idealAmount")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(domainId)
                    t.column(isActive)
                    t.column(idealAmount)

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

    static func addTag(newName: String, newDomainId: Int64) -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                domainId <- newDomainId,
                idealAmount <- 0,
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

    static func editTag(id: Int64, newName: String, newIdealAmount: Int) {
        guard let db = DatabaseManager.shared.db else { return }
        let tag = table.filter(self.id == id)
        do {
            let update = tag.update(name <- newName, idealAmount <- newIdealAmount)
            try db.run(update)
        } catch {
            print("Failed to rename tag \(id): \(error)")
        }
    }

    static func deleteTag(id: Int64) {
        guard let db = DatabaseManager.shared.db else { return }
        let tag = table.filter(self.id == id)
        do {
            let update = tag.update(isActive <- false)
            try db.run(update)
        } catch {
            print("Failed to delete tag \(id): \(error)")
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
                tagId <- newTagId
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
                        ON CONFLICT(email, tagId) DO UPDATE SET isActive = 1, importId = excluded.importId, randomOrder = excluded.randomOrder;
                    """
                    try db.run(sql, [newEmail, newTagId, newImportId, Double.random(in: 0 ..< 1)])
                }
            }
            print(" Successfully inserted \(newEmails.count) leads in one transaction")
        } catch {
            print("Failed to add leads: \(error)")
        }
    }
    
    
    
    
    static func fetchTagsInfoData(
        domainId: Int64,
        useLimit: Int,
        globalUseLimit: Int
    ) -> [TagInfo] {
        
        guard let db = DatabaseManager.shared.db else { return [] }

        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -useLimit, to: Date()) ?? Date.distantPast
        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast

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
        SELECT
            T.id,
            T.name,
            T.idealAmount,
            
            SUM(CASE WHEN L.isActive = 0 THEN 1 ELSE 0 END) AS inactiveCount,
            
            SUM(CASE WHEN L.isActive = 1 THEN 1 ELSE 0 END) AS activeCount,
            
            SUM(CASE
                WHEN L.isActive = 1
                 AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL) 
                 AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
                THEN 1
                ELSE 0
            END) AS availableCount
            
        FROM tags T
        LEFT JOIN leads L ON T.id = L.tagId
        LEFT JOIN globalRecent G ON L.email = G.email
        LEFT JOIN domainRecent D ON L.email = D.email
        
        WHERE T.domainId = ? 
          AND T.isActive = 1
        
        GROUP BY T.id, T.name, T.idealAmount
        ORDER BY T.name;
        """

        var results: [TagInfo] = []
        
        do {
            let parameters: [Binding] = [
                domainId,
                globalCutoffString,
                domainCutoffString,
                domainId
            ]
            
            for row in try db.prepare(sql, parameters) {
                
                let info = TagInfo(
                    id: row[0] as? Int64 ?? 0,
                    name: row[1] as? String ?? "Unknown",
                    idealAmount: Int(row[2] as? Int64 ?? 0),
                    inactiveLeadsCount: Int((row[3] as? Int64) ?? 0),
                    activeLeadsCount: Int((row[4] as? Int64) ?? 0),
                    availableLeadsCount: Int((row[5] as? Int64) ?? 0)
                )
                results.append(info)
            }
            
        } catch {
            print("❌ fetchTagsInfoData failed: \(error)")
        }
        
        return results
    }
    
    
    
//    static func countAllLeads(with tagId: Int64, active: Bool) -> Int {
//        guard let db = DatabaseManager.shared.db else { return 0 }
//
//        let query = table.filter((self.tagId == tagId) && (isActive == active))
//
//        do {
//            let count = try db.scalar(query.count)
//            return count
//        } catch {
//            print("Failed count leads with tag \(tagId): \(error)")
//            return 0
//        }
//    }
//
//    static func countAvailableLeads(
//        with tagId: Int64,
//        domainId: Int64,
//        domainUseLimit: Int,
//        globalUseLimit: Int
//    ) -> Int {
//        guard let db = DatabaseManager.shared.db else { return 0 }
//
//        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -domainUseLimit, to: Date()) ?? Date.distantPast
//        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast
//
//        let dateFormatter = ISO8601DateFormatter()
//        let domainCutoffString = dateFormatter.string(from: domainCutoffDate)
//        let globalCutoffString = dateFormatter.string(from: globalCutoffDate)
//
//        let sql = """
//        WITH globalRecent AS (
//            SELECT email, MAX(lastUsedAt) AS globalLastUsed
//            FROM leads
//            GROUP BY email
//        ),
//        domainRecent AS (
//            SELECT l.email, MAX(l.lastUsedAt) AS domainLastUsed
//            FROM leads l
//            JOIN tags t ON l.tagId = t.id
//            WHERE t.domainId = ?
//            GROUP BY l.email
//        )
//        SELECT COUNT(L.id)
//        FROM leads L
//        JOIN tags T ON L.tagId = T.id
//        LEFT JOIN globalRecent G ON L.email = G.email
//        LEFT JOIN domainRecent D ON L.email = D.email
//        WHERE L.tagId = ?
//          AND L.isActive = 1
//          AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
//          AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL);
//        """
//
//        do {
//            let parameters: [Binding] = [
//                domainId,
//                tagId,
//                globalCutoffString,
//                domainCutoffString
//            ]
//
//            let availableCount = try db.scalar(sql, parameters)
//
//            if let result = availableCount as? Int64 {
//                return Int(result)
//            } else {
//                return 0
//            }
//        } catch {
//            print("❌ countAvailableLeads failed for tagId \(tagId): \(error)")
//            return 0
//        }
//    }

    static func getEmails(
        with tagId: Int64,
        domainId: Int64,
        amount: Int,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) -> [String] {
        guard let db = DatabaseManager.shared.db else { return [] }

        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -domainUseLimit, to: Date()) ?? Date.distantPast
        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast

        

        
        
        let domainCutoffString = dateFormatter.string(from: domainCutoffDate)
        let globalCutoffString = dateFormatter.string(from: globalCutoffDate)
        
        let currentTimestamp = dateFormatter.string(from: Date())
        
        let combinedSQL = """
        UPDATE leads
        SET isActive = 0,
            lastUsedAt = ?
        WHERE id IN (
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
            SELECT L.id
            FROM leads L
            JOIN tags T ON L.tagId = T.id
            LEFT JOIN globalRecent G ON L.email = G.email
            LEFT JOIN domainRecent D ON L.email = D.email
            WHERE L.tagId = ?
              AND L.isActive = 1
              AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
              AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
            ORDER BY L.randomOrder
            LIMIT ?
        )
        RETURNING email;
        """

        var emails: [String] = []

        do {
            let stmt = try db.prepare(
                combinedSQL,
                currentTimestamp,
                domainId,
                tagId,
                globalCutoffString,
                domainCutoffString,
                amount
            )

            for row in stmt {
                if let email = row[0] as? String {
                    emails.append(email)
                }
            }

            if !emails.isEmpty {
                print("🧹 Fetched and deactivated \(emails.count) leads in one step.")
            }

            return emails

        } catch {
            print("❌ getEmails (combined query) failed:", error)
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
