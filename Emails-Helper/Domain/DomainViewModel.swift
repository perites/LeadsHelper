//
//  DomainViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 19/10/2025.
//

import SQLite
import SwiftUI

struct TagsInfo: Identifiable {
    let id: Int64
    let name: String
    let count: Int
}

class DomainViewModel: ObservableObject, Identifiable {
    let id: Int64
    
    @Published var name: String
    @Published var abbreviation: String
    @Published var exportType: Int
    @Published var saveFolder: URL?
    @Published var deleted: Bool = false
    @Published var tagsInfo: [TagsInfo]
    
    let maxLeads: Int = 50_000
    var strExportType: String {
        switch exportType {
        case 0: "Regular"
        case 1: "Exact Target"
        case 2: "Blueshift"
        default:
            "Unknown"
        }
    }
    
    var dbRow: Row
    
    init(from dbRow: Row) {
        self.id = dbRow[DomainsTable.id]
        _name = .init(initialValue: dbRow[DomainsTable.name])
        _abbreviation = .init(initialValue: dbRow[DomainsTable.abbreviation])
        _exportType = .init(initialValue: dbRow[DomainsTable.exportType])
        
        if let blob = dbRow[DomainsTable.saveFolder] {
            let data = Data(blob.bytes)
            _saveFolder = .init(initialValue: Self.createUrl(from: data))
        }
        
        _tagsInfo = .init(initialValue: Self.getTagsInfo(for: id) ?? [])
        
        self.dbRow = dbRow
    }
    
    static func getTagsInfo(for domainId: Int64) -> [TagsInfo]? {
        guard let db = DatabaseManager.shared.db else { return nil }
        
        let t = TagsTable.table
        let l = LeadsTable.table
        
        // Correct aggregate expression
        let leadsCountExpr = l[LeadsTable.id].count // ✅ not SQLite.count
        
        // Query
        let query = t
            .join(.leftOuter, l, on: l[LeadsTable.tagId] == t[TagsTable.id])
            .filter(t[TagsTable.domainId] == domainId)
            .select(t[TagsTable.id], t[TagsTable.name], leadsCountExpr)
            .group(t[TagsTable.id], t[TagsTable.name])
        
        do {
            let result = try db.prepare(query).map { row in
                TagsInfo(
                    id: row[t[TagsTable.id]],
                    name: row[t[TagsTable.name]],
                    count: row[leadsCountExpr]
                )
            }
            return result
        } catch {
            print("Failed to fetch tags with lead counts: \(error)")
            return nil
        }
    }
    
    func updateTagsInfo() {
        tagsInfo = Self.getTagsInfo(for: id) ?? []
    }
    
    static func createUrl(from data: Data) -> URL? {
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
    
    static func createBlob(from url: URL?) -> Blob? {
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
    
    func saveToDb() {
        do {
            let db = DatabaseManager.shared.db
            let domainRow = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try db?.run(domainRow.update(
                DomainsTable.name <- name,
                DomainsTable.abbreviation <- abbreviation,
                DomainsTable.exportType <- exportType,
                DomainsTable.saveFolder <- Self.createBlob(from: saveFolder)
            ))
            
            
            if let updatedRow = try db?.pluck(domainRow) {
                dbRow = updatedRow
            }
            
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
            deleted = true
            print("Domain deleted: \(name)")
            
        } catch {
            print("Failed to delete domain: \(error)")
        }
    }
}

//    func getLeads(from requestData: [String: String]) -> [String: [String]] {
//        guard let db = DatabaseManager.shared.db else { return ["": [""]] }
//        var result: [String: [String]] = [:]
//        var deactivateIDs: [Int64] = []
//
//        do {
//            try db.transaction {
//                for (exportImportName, amountStr) in requestData {
//                    guard let amount = Int(amountStr) else { continue }
//                    let total = leadsCount(in: exportImportName, isActive: true)
//                    let offset = total > amount ? Int.random(in: 0 ..< (total - amount)) : 0
//                    let query = LeadsTable.table
//                        .filter(
//                            (LeadsTable.domain == id) &&
//                                (LeadsTable.importName == exportImportName) &&
//                                (LeadsTable.isActive == true)
//                        )
//                        .limit(amount, offset: offset)
//
//                    result[exportImportName] = []
//                    for row in try db.prepare(query) {
//                        result[exportImportName]!.append(row[LeadsTable.email])
//                        deactivateIDs.append(row[LeadsTable.id])
//                    }
//                }
//
//                // BULK DELETE
//                if !deactivateIDs.isEmpty {
//                    let deactivateQuery = LeadsTable.table.filter(deactivateIDs.contains(LeadsTable.id))
//                    try db.run(deactivateQuery.update(LeadsTable.isActive <- false))
//                    print("🧹 Deactivated \(deactivateIDs.count) leads")
//                }
//            }
//        } catch {
//            print("❌ Transaction Failed: \(error)")
//        }
//
//        return result
//    }
    
//
// struct Domain: Hashable, Identifiable {
//    let id: Int64
//    var name: String
//    var abbreviation: String
//    var exportType: Int
//    var saveFolder: URL?
//
//    var importNames: [String]
//
//    var maxLeads: Int = 50_000
//    var deleted: Bool = false
//    var strExportType: String {
//        switch exportType {
//        case 0: "Regular"
//        case 1: "Exact Target"
//        case 2: "Blueshift"
//        default:
//            "Unknown"
//        }
//    }
//
//    static func create(from row: Row) -> Domain {
//        var folderURL: URL? = nil
//        if let blob = row[DomainsTable.saveFolder] {
//            let data = Data(blob.bytes)
//            folderURL = createUrl(from: data)
//        }
//
//        return Domain(
//            id: row[DomainsTable.id],
//            name: row[DomainsTable.name],
//            abbreviation: row[DomainsTable.abbreviation],
//            exportType: row[DomainsTable.exportType],
//            importNames: row[DomainsTable.importNames]
//                .split(separator: ",")
//                .map(String.init)
//                .sorted(),
//            saveFolder: folderURL
//        )
//    }
//
//    static func createUrl(from data: Data) -> URL? {
//        do {
//            var isStale = false
//            let url = try URL(resolvingBookmarkData: data,
//                              options: .withSecurityScope,
//                              relativeTo: nil,
//                              bookmarkDataIsStale: &isStale)
//
//            if url.startAccessingSecurityScopedResource() {
//                return url
//            } else {
//                print("❌ Failed to access bookmark security scope.")
//                return nil
//            }
//
//        } catch {
//            print("Error creating url : \(error)")
//            return nil
//        }
//    }
//
//    static func createBlob(from url: URL?) -> Blob? {
//        do {
//            if let data = try url?.bookmarkData(options: .withSecurityScope,
//                                                includingResourceValuesForKeys: nil,
//                                                relativeTo: nil)
//            {
//                return Blob(bytes: [UInt8](data))
//            } else {
//                print("No Url")
//                return nil
//            }
//
//        } catch {
//            print("Error creating url : \(error)")
//            return nil
//        }
//    }
//
//    func update() {
//        do {
//            let db = DatabaseManager.shared.db
//            let domainRow = DomainsTable.table.filter(
//                DomainsTable.id == id
//            )
//            try db?.run(domainRow.update(
//                DomainsTable.name <- name,
//                DomainsTable.abbreviation <- abbreviation,
//                DomainsTable.exportType <- exportType,
//                DomainsTable.saveFolder <- Domain.url2Blob(saveFolder)
//            ))
//
//            print("Domain updated: \(name)")
//
//        } catch {
//            print("Failed to update domain: \(error)")
//        }
//    }
//
//    func delete() {
//        do {
//            let db = DatabaseManager.shared.db
//            let domainRow = DomainsTable.table.filter(DomainsTable.id == id)
//            try db?.run(domainRow.delete())
//            print("Domain deleted: \(name)")
//
//        } catch {
//            print("Failed to delete domain: \(error)")
//        }
//    }
//
//    func leadsCount(in importName: String? = nil, isActive: Bool? = nil) -> Int {
//        print("db hit")
//
//        guard let db = DatabaseManager.shared.db else { return 0 }
//
//        var filterExpr = LeadsTable.domain == id
//
//        if let importName = importName {
//            filterExpr = filterExpr && (LeadsTable.importName == importName)
//        }
//
//        if let isActive = isActive {
//            filterExpr = filterExpr && (LeadsTable.isActive == isActive)
//        }
//
//        do {
//            let query = LeadsTable.table.filter(filterExpr)
//            let count = try db.scalar(query.count)
//            return count
//        } catch {
//            print("Failed to count leads: \(error)")
//            return 0
//        }
//    }
//
//    func importNamesForDomain() -> [String] {
//        guard let db = DatabaseManager.shared.db else { return [] }
//
//        do {
//            let query = LeadsTable.table
//                .select(LeadsTable.importName)
//                .filter(LeadsTable.domain == id)
//                .group(LeadsTable.importName)
//
//            var names: [String] = []
//            for row in try db.prepare(query) {
//                let name = row[LeadsTable.importName] // ✅ Direct access
//                names.append(name)
//            }
//            return names
//        } catch {
//            print("Failed to get import names: \(error)")
//            return []
//        }
//    }
//
//    func getLeadsFromRequest(requestData: [String: String]) -> [String: [String]] {
//        guard let db = DatabaseManager.shared.db else { return ["": [""]] }
//        var result: [String: [String]] = [:]
//        var deactivateIDs: [Int64] = []
//
//        do {
//            try db.transaction {
//                for (exportImportName, amountStr) in requestData {
//                    guard let amount = Int(amountStr) else { continue }
//                    let total = leadsCount(in: exportImportName, isActive: true)
//                    let offset = total > amount ? Int.random(in: 0 ..< (total - amount)) : 0
//                    let query = LeadsTable.table
//                        .filter(
//                            (LeadsTable.domain == id) &&
//                                (LeadsTable.importName == exportImportName) &&
//                                (LeadsTable.isActive == true)
//                        )
//                        .limit(amount, offset: offset)
//
//                    result[exportImportName] = []
//                    for row in try db.prepare(query) {
//                        result[exportImportName]!.append(row[LeadsTable.email])
//                        deactivateIDs.append(row[LeadsTable.id])
//                    }
//                }
//
//                // BULK DELETE
//                if !deactivateIDs.isEmpty {
//                    let deactivateQuery = LeadsTable.table.filter(deactivateIDs.contains(LeadsTable.id))
//                    try db.run(deactivateQuery.update(LeadsTable.isActive <- false))
//                    print("🧹 Deactivated \(deactivateIDs.count) leads")
//                }
//            }
//        } catch {
//            print("❌ Transaction Failed: \(error)")
//        }
//
//        return result
//    }
// }
