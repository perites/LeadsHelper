//
//  DatabaseManager.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import Foundation
import SQLite

@globalActor actor DatabaseActor {
    static let shared = DatabaseActor()

    private let db: Connection

    private init() {
        do {
            db = try DatabaseActor.databaseConnection()
            try db.run("PRAGMA foreign_keys = ON")
            try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_leads_tagId ON leads(tagId);
                CREATE INDEX IF NOT EXISTS idx_leads_email ON leads(email);
                CREATE INDEX IF NOT EXISTS idx_leads_isActive ON leads(isActive);
                CREATE INDEX IF NOT EXISTS idx_tags_domainId ON tags(domainId);
            """)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private static func databaseConnection() throws -> Connection {
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

//        let dbURL = folder.appendingPathComponent("emails-helper-db-LIVE.sqlite3")
        let dbURL = folder.appendingPathComponent("emails-helper-db.sqlite3")

        return try Connection(dbURL.path)
    }

    func createTables() {
        LeadsTable.createTable(in: db)
        DomainsTable.createTable(in: db)
        TagsTable.createTable(in: db)
        ImportsTable.createTable(in: db)
    }

    func cleanupDatabase() {
        do {
            try db.run(LeadsTable.table.drop(ifExists: true))
            try db.run(TagsTable.table.drop(ifExists: true))
            try db.run(ImportsTable.table.drop(ifExists: true))
            try db.run(DomainsTable.table.drop(ifExists: true))
            print("Database cleaned")
        } catch {
            print("Error cleaning database: \(error)")
        }
    }

    func dbRun(_ sql: String) throws {
        try db.run(sql)
    }

    @discardableResult func dbInsert(_ insert: Insert) throws -> Int64 {
        return try db.run(insert)
    }

    @discardableResult func dbUpdate(_ update: Update) throws -> Int {
        return try db.run(update)
    }

    @discardableResult func dbDelete(_ delete: Delete) throws -> Int {
        return try db.run(delete)
    }

    @discardableResult func dbPrepare(sql: String, params: [Binding?]) throws -> Statement {
        return try db.prepare(sql, params)
    }

    func dbFetch(_ query: QueryType) throws -> [Row] {
        return try Array(db.prepare(query))
    }

    func dbPluck(_ query: QueryType) throws -> Row? {
        return try db.pluck(query)
    }

    func addLeadsBulk(newEmails: [String], newImportId: Int64, newTagId: Int64) {
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

    func bulkExcludeLeads(
        domainId: Int64,
        excludeFromAll: Bool,
        selectedTagId: Int64?,
        emails: [String]
    ) throws {
        let uniqueEmails = Set(emails)
        guard !uniqueEmails.isEmpty else { return }

        // 1. Generate a random temp table name to avoid collisions
        let tempTableName = "temp_exclude_\(Int64.random(in: 1000 ... 9999))"

        // 2. ENSURE CLEANUP: This runs no matter what happens (success or error)
        defer {
            try? db.run("DROP TABLE IF EXISTS \(tempTableName)")
        }

        // 3. Create the temporary table
        try db.run("CREATE TEMPORARY TABLE \(tempTableName) (email TEXT PRIMARY KEY) WITHOUT ROWID;")

        // 4. Bulk Insert the emails into the temp table (inside a transaction for speed)
        try db.transaction {
            let stmt = try db.prepare("INSERT OR IGNORE INTO \(tempTableName) (email) VALUES (?)")
            for email in uniqueEmails {
                try stmt.run(email)
            }
        }

        // 5. Construct the Update SQL
        // Note: We write raw SQL here for clarity and performance on complex joins
        var whereClause = ""
        var bindings: [Binding?] = []

        if excludeFromAll {
            // Filter by Domain: Tag must belong to this Domain
            whereClause = "tagId IN (SELECT id FROM tags WHERE domainId = ?)"
            bindings.append(domainId)
        } else {
            // Filter by Specific Tag
            guard let tagId = selectedTagId else {
                throw NSError(domain: "DbError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing Tag ID"])
            }
            whereClause = "tagId = ?"
            bindings.append(tagId)
        }

        let updateSQL = """
            UPDATE leads
            SET isActive = 0
            WHERE
                \(whereClause)
                AND email IN (SELECT email FROM \(tempTableName))
        """

        // 6. Run the actual update
        try db.run(updateSQL, bindings)

        print("Actor: Exclude operation finished.")
    }
}

//
//// SQLite Manager
// class DatabaseManager {
//    static let shared = DatabaseManager()
//
//    var db: Connection
//
//    init() {
//        do {
//            db = try DatabaseManager.databaseConnection()
//        } catch {
//            fatalError("Failed to initialize database: \(error)")
//        }
//    }
//
//    static func databaseConnection() throws -> Connection {
//        let fm = FileManager.default
//
//        let appSupport = try fm.url(
//            for: .applicationSupportDirectory,
//            in: .userDomainMask,
//            appropriateFor: nil,
//            create: true
//        )
//
//        let folder = appSupport.appendingPathComponent("EmailsHelper", isDirectory: true)
//
//        if !fm.fileExists(atPath: folder.path) {
//            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
//        }
//
//        let dbURL = folder.appendingPathComponent("emails-helper-db-LIVE.sqlite3")
////        let dbURL = folder.appendingPathComponent("emails-helper-db.sqlite3")
//
//        print(dbURL)
//        return try Connection(dbURL.path)
//    }
// }

//            try db.run("PRAGMA foreign_keys = ON")

//            try db.run(LeadsTable.table.drop(ifExists: true))
//            try db.run(TagsTable.table.drop(ifExists: true))
//            try db.run(ImportsTable.table.drop(ifExists: true))
//            try db.run(DomainsTable.table.drop(ifExists: true))
//            print("Database cleaned")
//
//            LeadsTable.createTable(in: db)
//            DomainsTable.createTable(in: db)
//            TagsTable.createTable(in: db)
//            ImportsTable.createTable(in: db)
//
//            //            try db.run("""
//                CREATE INDEX IF NOT EXISTS idx_leads_tag_active
//                ON Leads(tagId, isActive, email);
//            """)
//
//
//            try db.run("""
//               CREATE INDEX IF NOT EXISTS idx_tags_domain_active
//               ON Tags(domainId, isActive);
//            """)

//
//            for row in try! db.prepare(TagsTable.table) {
//                print(row[TagsTable.name])
//                print(row[TagsTable.isActive])
//            }

//            for row in try db.prepare("SELECT email, lastUsedAt, typeof(lastUsedAt) FROM leads") {
//                print(row)
//            }

enum TagsTable {
    static let table = Table("tags")
    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let domainId = SQLite.Expression<Int64>("domainId")
    static let isActive = SQLite.Expression<Bool>("isActive")
    static let idealAmount = SQLite.Expression<Int>("idealAmount")

    static func createTable(in db: Connection) {
        do {
            let createTableExpr = table.create(ifNotExists: true) { t in
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
            }

            try db.run(createTableExpr)

        } catch {
            print("Error creating Tags table: \(error)")
        }
    }

    static func addTag(newName: String, newDomainId: Int64) async -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                domainId <- newDomainId,
                idealAmount <- 0,
                isActive <- true
            )

            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return rowId

        } catch {
            print("Failed to add tag: \(error)")
            return nil
        }
    }

    static func editTag(id: Int64, newName: String, newIdealAmount: Int) async {
        let tag = table.filter(self.id == id)
        do {
            let update = tag.update(name <- newName, idealAmount <- newIdealAmount)
            try await DatabaseActor.shared.dbUpdate(update)
        } catch {
            print("Failed to rename tag \(id): \(error)")
        }
    }

    static func deleteTag(id: Int64) async {
        let tag = table.filter(self.id == id)
        do {
            let update = tag.update(isActive <- false)
            try await DatabaseActor.shared.dbUpdate(update)
        } catch {
            print("Failed to delete tag \(id): \(error)")
        }
    }

    static func getTags(with domainId: Int64, isActive: Bool = true) async -> [TagInfo] {
        let filter = TagsTable.table.filter(
            (TagsTable.domainId == domainId) &&
                (TagsTable.isActive == isActive)
        )
        do {
            var results: [TagInfo] = []
            for row in try await DatabaseActor.shared.dbFetch(filter) {
                let info = TagInfo(
                    id: row[id],
                    name: row[name],
                    idealAmount: row[idealAmount]
//                    inactiveLeadsCount: Int((row[3] as? Int64) ?? 0),
//                    activeLeadsCount: Int((row[4] as? Int64) ?? 0),
//                    availableLeadsCount: Int((row[5] as? Int64) ?? 0)
                )
                results.append(info)
            }
            return results
        } catch {
            print("Error retrieving tags: \(error)")
            return []
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

    static func addImport(newName: String, newTagId: Int64, newType: Int) async -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                dateCreated <- Date(),
                type <- newType,
                tagId <- newTagId
            )

            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return rowId

        } catch {
            print("Failed to add import: \(error)")
            return nil
        }
    }

    // Replace the old fetchImports function in 'ImportsTable' with this
//    static func fetchImports(for selectedTagId: Int64, limit: Int, offset: Int) -> (imports: [ImportInfo], totalCount: Int) {
//        let db = DatabaseManager.shared.db
//        var results: [ImportInfo] = []
//        var totalCount = 0
//
//        // This is a special expression to get the total count *before* limiting
//        let totalCountExpr = Expression<Int64>("COUNT(*) OVER ()")
//
//        let query = table
//            .select(
//                table[id],
//                table[name],
//                table[dateCreated],
//                table[type],
//                table[tagId],
//                LeadsTable.table[LeadsTable.id].count, // Lead count
//                totalCountExpr // Total row count
//            )
//            .join(.leftOuter,
//                  LeadsTable.table,
//                  on: table[id] == LeadsTable.table[LeadsTable.importId])
//            .filter(table[tagId] == selectedTagId)
//            .group(table[id], table[name], table[dateCreated], table[type], table[tagId])
//            .order(table[dateCreated].desc)
//            .limit(limit, offset: offset) // Apply paging here
//
//        do {
//            for row in try db.prepare(query) {
//                let info = ImportInfo(
//                    id: row[table[id]],
//                    name: row[table[name]],
//                    dateCreated: row[table[dateCreated]],
//                    importType: ImportType(rawValue: row[table[type]]) ?? .unknown,
//                    tagId: row[table[tagId]],
//                    leadCount: row[LeadsTable.table[LeadsTable.id].count]
//                )
//                results.append(info)
//
//                // The totalCount will be the same for every row
//                if totalCount == 0 {
//                    totalCount = Int(row[totalCountExpr])
//                }
//            }
//        } catch {
//            print("❌ Failed to fetch paged imports: \(error)")
//        }
//        return (results, totalCount)
//    }
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

    private static var recencyCteLogic: String {
        """
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
        """
    }

    private static var validLeadsWhereLogic: String {
        """
        FROM leads L
        JOIN tags T ON L.tagId = T.id
        LEFT JOIN globalRecent G ON L.email = G.email
        LEFT JOIN domainRecent D ON L.email = D.email
        WHERE L.tagId = ?
          AND L.isActive = 1
          AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
          AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
        """
    }

    static func getCutoffDates(domainUseLimit: Int, globalUseLimit: Int) -> (
        domainCutoffString: String,
        globalCutoffString: String,
        nowString: String
    ) {
        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -domainUseLimit, to: Date()) ?? Date.distantPast
        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast

        let domainCutoffString = dateFormatter.string(from: domainCutoffDate)
        let globalCutoffString = dateFormatter.string(from: globalCutoffDate)
        let currentTimestamp = dateFormatter.string(from: Date())

        return (domainCutoffString, globalCutoffString, currentTimestamp)
    }

    
    
    
    
    
    static func getTagStats(
        tagId: Int64,
        domainId: Int64,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) async -> (
        inactiveLeadsCount: Int,
        activeLeadsCount: Int,
        availableLeadsCount: Int
    ) {
        let cutoffDates = getCutoffDates(domainUseLimit: domainUseLimit, globalUseLimit: globalUseLimit)

        let sql = """
            \(recencyCteLogic)
            SELECT 
                (SELECT COUNT(*) FROM leads WHERE tagId = ? AND isActive = 0) as inactiveCount,
                (SELECT COUNT(*) FROM leads WHERE tagId = ? AND isActive = 1) as activeLeadsCount,
                (SELECT COUNT(*) \(validLeadsWhereLogic)) as availableLeadsCount
        """

        let bindings: [Binding?] = [
            domainId,
            tagId,
            tagId,
            tagId,
            cutoffDates.globalCutoffString,
            cutoffDates.domainCutoffString,
        ]

        do {
            let statement = try await DatabaseActor.shared.dbPrepare(
                sql: sql,
                params: bindings
            )
            guard let row = statement.makeIterator().next() else { return (0, 0, 0) }

            let inactive = Int(row[0] as? Int64 ?? 0)
            let active = Int(row[1] as? Int64 ?? 0)
            let available = Int(row[2] as? Int64 ?? 0)

            return (inactive, active, available)

        } catch {
            print("❌ getStats failed:", error)
            return (0, 0, 0)
        }
    }

    
    
    static func getBatchTagStats(
        tagIds: [Int64],
        domainId: Int64,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) async -> [Int64: (inactive: Int, active: Int, available: Int)] {
        
        if tagIds.isEmpty { return [:] }

        let cutoffDates = getCutoffDates(domainUseLimit: domainUseLimit, globalUseLimit: globalUseLimit)
        
        let placeholders = Array(repeating: "?", count: tagIds.count).joined(separator: ",")
        
       
        let sql = """
            \(recencyCteLogic)
            SELECT 
                L.tagId,
                SUM(CASE WHEN L.isActive = 0 THEN 1 ELSE 0 END) as inactiveCount,
                SUM(CASE WHEN L.isActive = 1 THEN 1 ELSE 0 END) as activeCount,
                SUM(CASE 
                    WHEN L.isActive = 1 
                     AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
                     AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
                    THEN 1 ELSE 0 
                END) as availableCount
            FROM leads L
            LEFT JOIN globalRecent G ON L.email = G.email
            LEFT JOIN domainRecent D ON L.email = D.email
            WHERE L.tagId IN (\(placeholders))
            GROUP BY L.tagId
        """
        
        var bindings: [Binding?] = [domainId, cutoffDates.globalCutoffString, cutoffDates.domainCutoffString]
        bindings.append(contentsOf: tagIds.map { $0 as Binding? })

        var results: [Int64: (Int, Int, Int)] = [:]

        do {
            let rows = try await DatabaseActor.shared.dbPrepare(sql: sql, params: bindings)
            
            for row in rows {
                let id = row[0] as? Int64 ?? 0
                let inactive = Int(row[1] as? Int64 ?? 0)
                let active = Int(row[2] as? Int64 ?? 0)
                let available = Int(row[3] as? Int64 ?? 0)
                
                results[id] = (inactive, active, available)
            }
        } catch {
            print("❌ Batch Stats Failed: \(error)")
        }
        
        return results
    }
    
    
    
    
    static func getEmails(
        tagId: Int64,
        domainId: Int64,
        amount: Int,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) async -> [String] {
        let cutoffDates = getCutoffDates(domainUseLimit: domainUseLimit, globalUseLimit: globalUseLimit)

        let updateSQL = """
            UPDATE leads
            SET isActive = 0,
                lastUsedAt = ?
            WHERE id IN (
                \(recencyCteLogic)
                SELECT L.id
                \(validLeadsWhereLogic)
                ORDER BY L.randomOrder
                LIMIT ?
            )
            RETURNING email;
        """

        let bindings: [Binding?] = [
            cutoffDates.nowString,
            domainId,
            tagId,
            cutoffDates.globalCutoffString,
            cutoffDates.domainCutoffString,
            amount,
        ]

        do {
            let stmt = try await DatabaseActor.shared.dbPrepare(sql: updateSQL, params: bindings)

            var emails: [String] = []
            for row in stmt {
                if let email = row[0] as? String {
                    emails.append(email)
                }
            }

            if !emails.isEmpty {
                print("🧹 Fetched and deactivated \(emails.count) leads.")
            }
            return emails
        }

        catch {
            print("❌ getEmails failed:", error)
            return []
        }
    }

//    static func getEmails(
//        with tagId: Int64,
//        domainId: Int64,
//        amount: Int,
//        domainUseLimit: Int,
//        globalUseLimit: Int
//    ) async -> [String] {
    ////        let db = DatabaseManager.shared.db
//
//        let domainCutoffDate = Calendar.current.date(byAdding: .day, value: -domainUseLimit, to: Date()) ?? Date.distantPast
//        let globalCutoffDate = Calendar.current.date(byAdding: .day, value: -globalUseLimit, to: Date()) ?? Date.distantPast
//
//        let domainCutoffString = dateFormatter.string(from: domainCutoffDate)
//        let globalCutoffString = dateFormatter.string(from: globalCutoffDate)
//
//        let currentTimestamp = dateFormatter.string(from: Date())
//
//        let combinedSQL = """
//        UPDATE leads
//        SET isActive = 0,
//            lastUsedAt = ?
//        WHERE id IN (
//            WITH globalRecent AS (
//                SELECT email, MAX(lastUsedAt) AS globalLastUsed
//                FROM leads
//                GROUP BY email
//            ),
//            domainRecent AS (
//                SELECT l.email, MAX(l.lastUsedAt) AS domainLastUsed
//                FROM leads l
//                JOIN tags t ON l.tagId = t.id
//                WHERE t.domainId = ?
//                GROUP BY l.email
//            )
//            SELECT L.id
//            FROM leads L
//            JOIN tags T ON L.tagId = T.id
//            LEFT JOIN globalRecent G ON L.email = G.email
//            LEFT JOIN domainRecent D ON L.email = D.email
//            WHERE L.tagId = ?
//              AND L.isActive = 1
//              AND (G.globalLastUsed < ? OR G.globalLastUsed IS NULL)
//              AND (D.domainLastUsed < ? OR D.domainLastUsed IS NULL)
//            ORDER BY L.randomOrder
//            LIMIT ?
//        )
//        RETURNING email;
//        """
//
//        var emails: [String] = []
//
//        do {
//            let bindings: [Binding?] = [
//                currentTimestamp,
//                domainId,
//                tagId,
//                globalCutoffString,
//                domainCutoffString,
//                amount
//            ]
//
//            // Now the call is clean and passes a single array argument
//            let stmt = try await DatabaseActor.shared.dbPrepare(
//                sql: combinedSQL,
//                params: bindings
//            )
//
//            for row in stmt {
//                if let email = row[0] as? String {
//                    emails.append(email)
//                }
//            }
//
//            if !emails.isEmpty {
//                print("🧹 Fetched and deactivated \(emails.count) leads in one step.")
//            }
//
//            return emails
//
//        } catch {
//            print("❌ getEmails (combined query) failed:", error)
//            return []
//        }
//    }
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

    static func findById(id: Int64) async -> Row? {
        do {
            let query = table.filter(self.id == id)
            return try await DatabaseActor.shared.dbPluck(query)
        } catch {
            print("Error fetching domain by ID: \(error)")
            return nil
        }
    }

    static func addDomain(newName: String) async -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                abbreviation <- "ABC",
                exportType <- 0,
                useLimit <- 0,
                globalUseLimit <- 0,
                isActive <- true
            )
            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return rowId

        } catch {
            print("Failed to add domain: \(error)")
            return nil
        }
    }
}
