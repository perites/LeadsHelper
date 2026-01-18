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
        let dbURL = folder.appendingPathComponent("emails-helper-db-TEST.sqlite3")
//        let dbURL = folder.appendingPathComponent("emails-helper-db.sqlite3")

        return try Connection(dbURL.path)
    }

    func migrate() {
        do {
            let currentVersion = try db.scalar("PRAGMA user_version") as? Int64 ?? 0

            let latestVersion: Int64 = 2

            guard currentVersion < latestVersion else { return }

            print("Migrating database from v\(currentVersion) to v\(latestVersion)...")

            if currentVersion < 1 {
                print("Migrating to v1: Adding emailsCount to Imports...")

                do {
                    try db.run(ImportsTable.table.addColumn(ImportsTable.emailsAmount, defaultValue: 0))

                    try db.transaction {
                        let importIdCol = LeadsTable.importId
                        let countExpression = LeadsTable.id.count

                        let countsQuery = LeadsTable.table
                            .select(importIdCol, countExpression)
                            .group(importIdCol)

                        for row in try db.prepare(countsQuery) {
                            let targetImportId = row[importIdCol]
                            let actualCount = row[countExpression]

                            let targetImport = ImportsTable.table.filter(ImportsTable.id == targetImportId)
                            try db.run(targetImport.update(ImportsTable.emailsAmount <- actualCount))
                        }
                    }
                    print("Successfully calculated email counts for existing imports.")

                } catch {
                    print("Migration v1 failed: \(error)")
                }
            }

            if currentVersion < 2 {
                print("Migrating to v1: Adding exportId to Leads...")

                do {
                    try db
                        .run(
                            LeadsTable.table
                                .addColumn(
                                    LeadsTable.exportId
                                )
                        )

                    print("Successfully added exportId to leads.")

                } catch {
                    print("Migration v2 failed: \(error)")
                }
            }

            try db.run("PRAGMA user_version = \(latestVersion)")
            print("Migration successful.")

        } catch {
            print("Migration failed: \(error)")
        }
    }

    func createTables() {
        LeadsTable.createTable(in: db)
        DomainsTable.createTable(in: db)
        TagsTable.createTable(in: db)
        ImportsTable.createTable(in: db)
        ExportTable.createTable(in: db)

        try? db.execute("""
            CREATE INDEX IF NOT EXISTS idx_leads_tagId ON leads(tagId);
            CREATE INDEX IF NOT EXISTS idx_leads_email ON leads(email);
            CREATE INDEX IF NOT EXISTS idx_leads_isActive ON leads(isActive);
            CREATE INDEX IF NOT EXISTS idx_tags_domainId ON tags(domainId);
            CREATE INDEX IF NOT EXISTS idx_leads_tag_active ON leads(tagId, isActive);
            CREATE INDEX IF NOT EXISTS idx_leads_email_lastused ON leads(email, lastUsedAt);
            CREATE INDEX IF NOT EXISTS idx_tags_domain ON tags(id, domainId);
        """)
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

    func dbCount(_ query: Table) throws -> Int {
        return try db.scalar(query.count)
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

        let tempTableName = "temp_exclude_\(Int64.random(in: 1000 ... 9999))"

        defer {
            _ = try? db.run("DROP TABLE IF EXISTS \(tempTableName)")
        }

        try db.run("CREATE TEMPORARY TABLE \(tempTableName) (email TEXT PRIMARY KEY) WITHOUT ROWID;")

        try db.transaction {
            let stmt = try db.prepare("INSERT OR IGNORE INTO \(tempTableName) (email) VALUES (?)")
            for email in uniqueEmails {
                try stmt.run(email)
            }
        }

        var whereClause = ""
        var bindings: [Binding?] = []

        if excludeFromAll {
            whereClause = "tagId IN (SELECT id FROM tags WHERE domainId = ?)"
            bindings.append(domainId)
        } else {
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

        try db.run(updateSQL, bindings)

        print("Actor: Exclude operation finished.")
    }
}

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

    static func addTag(newDomainId: Int64) async -> (createdTagId: Int64?, newName: String) {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
            let dateString = formatter.string(from: Date())
            let newName = "New Tag \(dateString)"

            let insert = table.insert(
                name <- newName,
                domainId <- newDomainId,
                idealAmount <- 0,
                isActive <- true
            )

            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return (rowId, newName)

        } catch {
            print("Failed to add tag: \(error)")
            return (nil, "")
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
        ).order(TagsTable.name)
        do {
            var results: [TagInfo] = []
            for row in try await DatabaseActor.shared.dbFetch(filter) {
                let info = TagInfo(
                    id: row[id],
                    name: row[name],
                    idealAmount: row[idealAmount]
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
    static let emailsAmount = SQLite.Expression<Int>("emailsAmount")

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
                    t.column(emailsAmount)

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

    static func addImport(newName: String, newTagId: Int64, newType: Int, newEmailsAmount: Int) async -> Int64? {
        do {
            let insert = table.insert(
                name <- newName,
                dateCreated <- Date(),
                type <- newType,
                tagId <- newTagId,
                emailsAmount <- newEmailsAmount
            )

            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return rowId

        } catch {
            print("Failed to add import: \(error)")
            return nil
        }
    }

    static func fetchImports(for selectedTagId: Int64, limit: Int, offset: Int) async -> (imports: [ImportInfo], totalCount: Int) {
        let countQuery = table.filter(tagId == selectedTagId)

        let query = table
            .select(
                table[id],
                table[name],
                table[dateCreated],
                table[type],
                table[tagId],
                table[emailsAmount]
            )
            .filter(table[tagId] == selectedTagId)
            .group(table[id])
            .order(table[dateCreated].desc)
            .limit(limit, offset: offset)

        do {
            let totalCount = try await DatabaseActor.shared.dbCount(countQuery)

            let rows = try await DatabaseActor.shared.dbFetch(query)

            var results: [ImportInfo] = []

            for row in rows {
                let info = ImportInfo(
                    id: row[table[id]],
                    name: row[table[name]],
                    dateCreated: row[table[dateCreated]],
                    importType: ImportType(rawValue: row[table[type]])!,
                    tagId: row[table[tagId]],
                    leadCount: row[emailsAmount]
                )
                results.append(info)
            }

            return (results, totalCount)

        } catch {
            print("❌ Failed to fetch imports: \(error)")
            return ([], 0)
        }
    }
}

enum ExportTable {
    static let table = Table("exports")
    static let id = SQLite.Expression<Int64>("id")
    static let domainId = SQLite.Expression<Int64>("domainId")
    static let dateCreated = SQLite.Expression<Date>("dateCreated")

    static let fileName = SQLite.Expression<String>("fileName")
    static let folderName = SQLite.Expression<String>("folderName")
    static let isSeparateFiles = SQLite.Expression<Bool>("isSeparateFiles")

    static let tagsRequests = SQLite.Expression<String>("tagsRequests")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(domainId)
                    t.column(dateCreated)

                    t.column(fileName)
                    t.column(folderName)
                    t.column(isSeparateFiles)

                    t.column(tagsRequests)

                    t.foreignKey(
                        domainId,
                        references: DomainsTable.table,
                        DomainsTable.id,
                        delete: .cascade
                    )
                })

        } catch {
            print("Error creating Exports table: \(error)")
        }
    }

    static func addExport(domainId: Int64, exportRequest: ExportRequest) async -> Int64? {
        do {
            let insert = table.insert(
                ExportTable.domainId <- domainId,
                ExportTable.dateCreated <- Date(),
                ExportTable.fileName <- exportRequest.fileName,
                ExportTable.folderName <- exportRequest.folderName,
                ExportTable.isSeparateFiles <- exportRequest.isSeparateFiles,
                ExportTable.tagsRequests <- exportRequest.tagsJsonString
            )

            let rowId = try await DatabaseActor.shared.dbInsert(insert)
            return rowId

        } catch {
            print("Failed to add import: \(error)")
            return nil
        }
    }

    static func updateExport(id: Int64, finalRequest: ExportRequest) async {
        let row = table.filter(self.id == id)
        do {
            // Update all the fields that might have changed after processing
            let update = row.update(
                fileName <- finalRequest.fileName,
                folderName <- finalRequest.folderName,
                isSeparateFiles <- finalRequest.isSeparateFiles,
                tagsRequests <- finalRequest.tagsJsonString
            )
            try await DatabaseActor.shared.dbUpdate(update)
        } catch {
            print("❌ Failed to update export: \(error)")
        }
    }

    static func getLastExport(domainId: Int64) async -> ExportRequest? {
        let query = table
            .filter(ExportTable.domainId == domainId)
            .order(dateCreated.desc)
            .limit(1)

        do {
            guard let row = try await DatabaseActor.shared.dbPluck(query) else {
                return nil
            }

            let fileName = row[ExportTable.fileName]
            let folderName = row[ExportTable.folderName]
            let isSeparateFiles = row[ExportTable.isSeparateFiles]
            let jsonString = row[ExportTable.tagsRequests]

            let decoder = JSONDecoder()
            let tagsData = jsonString.data(using: .utf8) ?? Data()
            let tags = (try? decoder.decode([TagRequest].self, from: tagsData)) ?? []

            return ExportRequest(
                fileName: fileName,
                folderName: folderName,
                isSeparateFiles: isSeparateFiles,
                tags: tags
            )

        } catch {
            print("❌ Failed to fetch last export: \(error)")
            return nil
        }
    }

    static func fetchExports(domainId: Int64, limit: Int, offset: Int) async -> (items: [ExportHistoryItem], totalCount: Int) {
        let countQuery = table.filter(ExportTable.domainId == domainId)

        let query = table
            .filter(ExportTable.domainId == domainId)
            .order(dateCreated.desc)
            .limit(limit, offset: offset)

        do {
            let totalCount = try await DatabaseActor.shared.dbCount(countQuery)

            let rows = try await DatabaseActor.shared.dbFetch(query)

            var results: [ExportHistoryItem] = []
            let decoder = JSONDecoder()

            for row in rows {
                let jsonString = row[tagsRequests]
                let tagsData = jsonString.data(using: .utf8) ?? Data()
                let decodedTags = (try? decoder.decode([TagRequest].self, from: tagsData)) ?? []

                let item = ExportHistoryItem(
                    id: row[id],
                    dateCreated: row[dateCreated],
                    fileName: row[fileName],
                    folderName: row[folderName],
                    isSeparateFiles: row[isSeparateFiles],
                    tags: decodedTags
                )
                results.append(item)
            }

            return (results, totalCount)

        } catch {
            print("❌ Failed to fetch exports: \(error)")
            return ([], 0)
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
    static let exportId = SQLite.Expression<Int64?>("exportId")

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
                    t.column(exportId)

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

                    t.foreignKey(
                        exportId,
                        references: ExportTable.table,
                        ExportTable.id,
                        delete: .cascade
                    )

                    t.unique(email, tagId)

                })

        } catch {
            print("Error creating Leads table: \(error)")
        }
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

    private static var notUsedRecentlyLogic: String {
        """
        AND NOT EXISTS (
            SELECT 1 
            FROM leads Hl
            JOIN tags Ht ON Hl.tagId = Ht.id
            WHERE Hl.email = L.email
            AND (
                (Ht.domainId != ? AND Hl.lastUsedAt >= ?) -- Rule 1: External Usage (Global Limit)
                OR
                (Ht.domainId = ?  AND Hl.lastUsedAt >= ?) -- Rule 2: Internal Usage (Domain Limit)
            )
        )
        """
    }

    // MARK: - 1. Get Emails (Fetch & Update)

    static func getEmails(
        tagId: Int64,
        domainId: Int64,
        amount: Int,
        domainUseLimit: Int,
        globalUseLimit: Int,
        exportId: Int64
    ) async -> [String] {
        let cutoffDates = getCutoffDates(domainUseLimit: domainUseLimit, globalUseLimit: globalUseLimit)

        let updateSQL = """
            UPDATE leads
            SET isActive = 0,
                lastUsedAt = ?,
                exportId = ?
            WHERE id IN (
                SELECT L.id
                FROM leads L
                WHERE L.tagId = ?
                  AND L.isActive = 1
                  \(notUsedRecentlyLogic)
                ORDER BY L.randomOrder
                LIMIT ?
            )
            RETURNING email;
        """

        // BINDING ORDER:
        // 1. UPDATE params (Now, ExportId)
        // 2. Main Query params (TagId)
        // 3. Logic params (DomainId, GlobalDate, DomainId, DomainDate)
        // 4. LIMIT param (Amount)
        let bindings: [Binding?] = [
            cutoffDates.nowString,
            exportId,
            tagId,
            domainId, // for Ht.domainId != ?
            cutoffDates.globalCutoffString, // for Global Limit
            domainId, // for Ht.domainId = ?
            cutoffDates.domainCutoffString, // for Domain Limit
            amount
        ]

        do {
            let stmt = try await DatabaseActor.shared.dbPrepare(sql: updateSQL, params: bindings)
            var emails: [String] = []
            for row in stmt {
                if let email = row[0] as? String { emails.append(email) }
            }
            if !emails.isEmpty { print("🧹 Fetched \(emails.count) leads.") }
            return emails
        } catch {
            print("❌ getEmails failed:", error)
            return []
        }
    }

    // MARK: - 2. Single Tag Stats

    static func getTagStats(
        tagId: Int64,
        domainId: Int64,
        domainUseLimit: Int,
        globalUseLimit: Int
    ) async -> (inactiveLeadsCount: Int, activeLeadsCount: Int, availableLeadsCount: Int) {
        let cutoffDates = getCutoffDates(domainUseLimit: domainUseLimit, globalUseLimit: globalUseLimit)

        let sql = """
            SELECT
                COUNT(CASE WHEN isActive = 0 THEN 1 END),
                COUNT(CASE WHEN isActive = 1 THEN 1 END),
                COUNT(CASE 
                    WHEN isActive = 1 
                    \(notUsedRecentlyLogic)
                    THEN 1 
                END)
            FROM leads L
            WHERE L.tagId = ?
        """

        // BINDING ORDER: Logic params -> TagId
        let bindings: [Binding?] = [
            domainId,
            cutoffDates.globalCutoffString,
            domainId,
            cutoffDates.domainCutoffString,
            tagId
        ]

        do {
            let stmt = try await DatabaseActor.shared.dbPrepare(sql: sql, params: bindings)
            guard let row = stmt.makeIterator().next() else { return (0, 0, 0) }

            return (
                Int(row[0] as? Int64 ?? 0),
                Int(row[1] as? Int64 ?? 0),
                Int(row[2] as? Int64 ?? 0)
            )
        } catch {
            print("❌ getStats failed:", error)
            return (0, 0, 0)
        }
    }

    // MARK: - 3. Batch Tag Stats

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
            SELECT
                L.tagId,
                SUM(CASE WHEN L.isActive = 0 THEN 1 ELSE 0 END),
                SUM(CASE WHEN L.isActive = 1 THEN 1 ELSE 0 END),
                SUM(CASE 
                    WHEN L.isActive = 1 
                    \(notUsedRecentlyLogic)
                    THEN 1 ELSE 0 
                END)
            FROM leads L
            WHERE L.tagId IN (\(placeholders))
            GROUP BY L.tagId
        """

        // BINDING ORDER: Logic params -> TagIds
        var bindings: [Binding?] = [
            domainId,
            cutoffDates.globalCutoffString,
            domainId,
            cutoffDates.domainCutoffString
        ]
        bindings.append(contentsOf: tagIds.map { $0 as Binding? })

        var results: [Int64: (Int, Int, Int)] = [:]

        do {
            let rows = try await DatabaseActor.shared.dbPrepare(sql: sql, params: bindings)
            for row in rows {
                let id = row[0] as? Int64 ?? 0
                results[id] = (
                    Int(row[1] as? Int64 ?? 0),
                    Int(row[2] as? Int64 ?? 0),
                    Int(row[3] as? Int64 ?? 0)
                )
            }
        } catch {
            print("❌ Batch Stats Failed: \(error)")
        }
        return results
    }
}

enum DomainsTable {
    static let table = Table("domains")

    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let abbreviation = SQLite.Expression<String>("abbreviation")
    static let exportType = SQLite.Expression<Int>("exportType")
    static let saveFolder = SQLite.Expression<Blob?>("saveFolder")
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

            _ = await TagsTable.addTag(newDomainId: rowId)

            return rowId

        } catch {
            print("Failed to add domain: \(error)")
            return nil
        }
    }
}
