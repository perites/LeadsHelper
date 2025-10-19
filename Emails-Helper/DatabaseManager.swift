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
//            try db.run(DomainsTable.table.drop(ifExists: true))
//            print("Database cleaned")

            LeadsTable.createTable(in: db)
            DomainsTable.createTable(in: db)

        } catch {
            print("DB Error: \(error)")
        }
    }
}

enum LeadsTable {
    static let table = Table("leads")

    static let id = SQLite.Expression<Int64>("id")
    static let email = SQLite.Expression<String>("email")
    static let importName = SQLite.Expression<String>("importName")
    static let domain = SQLite.Expression<Int64>("domainId")
    static let isActive = SQLite.Expression<Bool>("isActive")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(email)
                    t.column(importName)
                    t.column(isActive)
                    t.column(domain)

                    t.foreignKey(
                        domain,
                        references: DomainsTable.table,
                        DomainsTable.id,
                        delete: .cascade
                    )
                })

        } catch {
            print("Error creating Leads table: \(error)")
        }
    }

    static func addLeadsBulk(newEmails: [String], newImportName: String, newDomain: Int64) {
        guard let db = DatabaseManager.shared.db else { return }

        do {
            try db.transaction {
                for newEmail in newEmails {
                    let insert = table.insert(
                        email <- newEmail,
                        importName <- newImportName,
                        domain <- newDomain,
                        isActive <- true
                    )
                    try db.run(insert)
                }
            }
            print(" Successfully inserted \(newEmails.count) leads in one transaction")
        } catch {
            print("Failed to add leads: \(error)")
        }
    }

    static func allCount() -> Int {
        guard let db = DatabaseManager.shared.db else { return 0 }
        do {
            let count = try db.scalar(table.count)
            return count
        } catch {
            print("Error fetching leads count: \(error)")
            return -1
        }
    }
}

enum DomainsTable {
    static let table = Table("domains")

    static let id = SQLite.Expression<Int64>("id")
    static let name = SQLite.Expression<String>("name")
    static let abbreviation = SQLite.Expression<String>("abbreviation")
    static let exportType = SQLite.Expression<Int>("exportType")

    static let importNames = SQLite.Expression<String>("importNames")
    static let saveFolder = SQLite.Expression<Blob?>("saveFolder")

    static func createTable(in db: Connection?) {
        guard let db else { return }
        do {
            try db.run(
                table.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(name)
                    t.column(abbreviation)
                    t.column(exportType)
                    t.column(importNames)
                    t.column(saveFolder)

                })

        } catch {
            print("Error creating Domains table: \(error)")
        }
    }

    static func fetchDomais() -> [Domain] {
        var result: [Domain] = []
        if let rows = try? DatabaseManager.shared.db.prepare(table) {
            for row in rows {
                result.append(Domain.create(from: row))
            }
        }
        return result
    }

    static func addDomain(newName: String) {
        do {
            let insert = table.insert(
                name <- newName,
                abbreviation <- "ABC",
                exportType <- 0,
                importNames <- ""
            )
            if let rowId = try DatabaseManager.shared.db?.run(insert) {
                print("domain added with name: \(newName) id: \(rowId)")
            }

        } catch {
            print("Failed to add domain: \(error)")
        }
    }
}

public struct Domain: Hashable, Identifiable{
    public let id: Int64
    var name: String
    var abbreviation: String
    var exportType: Int
    var importNames: [String]
    var maxLeads : Int = 50_000
    var saveFolder: URL?
    var deleted: Bool = false
    var strExportType: String {
        switch exportType {
        case 0: "Regular"
        case 1: "Exect Target"
        case 2: "Blueshift"
        default:
            "Unknown"
        }
    }

    static func create(from row: Row) -> Domain {
        var folderURL: URL? = nil
        if let blob = row[DomainsTable.saveFolder] { // Blob?
            let data = Data(blob.bytes) // Data from bytes
            folderURL = blob2Url(data) // Convert to URL
        }

        return Domain(
            id: row[DomainsTable.id],
            name: row[DomainsTable.name],
            abbreviation: row[DomainsTable.abbreviation],
            exportType: row[DomainsTable.exportType],
            importNames: row[DomainsTable.importNames]
                .split(separator: ",")
                .map(String.init)
                .sorted(),
            saveFolder: folderURL
        )
    }

    static func blob2Url(_ data: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)

            if url.startAccessingSecurityScopedResource() {
                return url
            } else {
                print("❌ Failed to access bookmark security scope.")
                return nil
            }

        } catch {
            print("Error creating url : \(error)")
            return nil
        }
    }

    static func url2Blob(_ url: URL?) -> Blob? {
        do {
            if let data = try url?.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            {
                return Blob(bytes: [UInt8](data))
            } else {
                print("No Url")
                return nil
            }

        } catch {
            print("Error creating url : \(error)")
            return nil
        }
    }

    func update() {
        do {
            let db = DatabaseManager.shared.db
            let domainRow = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try db?.run(domainRow.update(
                DomainsTable.name <- name,
                DomainsTable.abbreviation <- abbreviation,
                DomainsTable.exportType <- exportType,
                DomainsTable.importNames <- importNames.joined(separator: ","),
                DomainsTable.saveFolder <- Domain.url2Blob(saveFolder)
            ))

            print("Domain updated: \(name)")

        } catch {
            print("Failed to update domain: \(error)")
        }
    }

    func delete() {
        do {
            let db = DatabaseManager.shared.db
            let domainRow = DomainsTable.table.filter(DomainsTable.id == id)
            try db?.run(domainRow.delete())
            print("Domain deleted: \(name)")

        } catch {
            print("Failed to delete domain: \(error)")
        }
    }

    func leadsCount(in importName: String? = nil, isActive: Bool? = nil) -> Int {
        guard let db = DatabaseManager.shared.db else { return 0 }

        var filterExpr = LeadsTable.domain == id

        if let importName = importName {
            filterExpr = filterExpr && (LeadsTable.importName == importName)
        }

        if let isActive = isActive {
            filterExpr = filterExpr && (LeadsTable.isActive == isActive)
        }

        do {
            let query = LeadsTable.table.filter(filterExpr)
            let count = try db.scalar(query.count)
            return count
        } catch {
            print("Failed to count leads: \(error)")
            return 0
        }
    }

    func importNamesForDomain() -> [String] {
        guard let db = DatabaseManager.shared.db else { return [] }

        do {
            let query = LeadsTable.table
                .select(LeadsTable.importName)
                .filter(LeadsTable.domain == id)
                .group(LeadsTable.importName)

            var names: [String] = []
            for row in try db.prepare(query) {
                let name = row[LeadsTable.importName] // ✅ Direct access
                names.append(name)
            }
            return names
        } catch {
            print("Failed to get import names: \(error)")
            return []
        }
    }

    func getLeadsFromRequest(requestData: [String: String]) -> [String: [String]] {
        guard let db = DatabaseManager.shared.db else { return ["":[""]] }
        var result: [String: [String]] = [:]
        var deactivateIDs: [Int64] = []

        do {
            try db.transaction {
                for (exportImportName, amountStr) in requestData {
                    guard let amount = Int(amountStr) else { continue }
                    let total = leadsCount(in: exportImportName, isActive: true)
                    let offset = total > amount ? Int.random(in: 0 ..< (total - amount)) : 0
                    let query = LeadsTable.table
                        .filter(
                            (LeadsTable.domain == id) &&
                                (LeadsTable.importName == exportImportName) &&
                                (LeadsTable.isActive == true)
                        )
                        .limit(amount, offset: offset)
                    
                    result[exportImportName] = []
                    for row in try db.prepare(query) {
                        result[exportImportName]!.append(row[LeadsTable.email])
                        deactivateIDs.append(row[LeadsTable.id])
                    }
                }

                // BULK DELETE
                if !deactivateIDs.isEmpty {
                    let deactivateQuery = LeadsTable.table.filter(deactivateIDs.contains(LeadsTable.id))
                    try db.run(deactivateQuery.update(LeadsTable.isActive <- false))
                    print("🧹 Deactivated \(deactivateIDs.count) leads")
                }
            }
        } catch {
            print("❌ Transaction Failed: \(error)")
        }

        return result
    }
}
