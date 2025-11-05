//
//  DomainViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 19/10/2025.
//

import SQLite
import SwiftUI

struct TagInfo: Identifiable {
    let id: Int64
    let name: String
    let activeEmailsCount: Int
    let allEmailsCount: Int
}

class DomainViewModel: ObservableObject, Identifiable {
    let id: Int64
    
    @Published var name: String
    @Published var abbreviation: String
    @Published var exportType: Int
    @Published var saveFolder: URL?
    @Published var deleted: Bool = false
    @Published var lastExportRequest: ExportRequest?
    @Published var useLimit: Int
    @Published var globalUseLimit: Int
    
    @Published var tagsInfo: [TagInfo]
    
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
    
    init(from dbRow: Row, needTags: Bool = true) {
        self.id = dbRow[DomainsTable.id]
        _name = .init(initialValue: dbRow[DomainsTable.name])
        _abbreviation = .init(initialValue: dbRow[DomainsTable.abbreviation])
        _exportType = .init(initialValue: dbRow[DomainsTable.exportType])
        
        if let blob = dbRow[DomainsTable.saveFolder] {
            let data = Data(blob.bytes)
            _saveFolder = .init(initialValue: Self.createUrl(from: data))
        }
        
        if let data = dbRow[DomainsTable.lastExportRequest]?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(
               ExportRequest.self,
               from: data
           )
        {
            _lastExportRequest = .init(initialValue: decoded)
        }
        
        _useLimit = .init(initialValue: dbRow[DomainsTable.useLimit])
        _globalUseLimit = .init(initialValue: dbRow[DomainsTable.globalUseLimit])
           
        if needTags {
            _tagsInfo = .init(initialValue: Self.getTagsInfo(for: id) ?? [])
        } else {
            _tagsInfo = .init(initialValue: [])
        }
        
        self.dbRow = dbRow
    }
    
    static func getTagsInfo(for domainId: Int64) -> [TagInfo]? {
        guard let db = DatabaseManager.shared.db else { return nil }
        
        let t = TagsTable.table
        let l = LeadsTable.table
        
        let allLeadsCountExpr = l[LeadsTable.id].count
        
        let query = t
            .join(l, on: l[LeadsTable.tagId] == t[TagsTable.id])
            .filter(t[TagsTable.domainId] == domainId)
            .select(t[TagsTable.id], t[TagsTable.name], allLeadsCountExpr)
            .group(t[TagsTable.id], t[TagsTable.name])
        
        do {
            let result = try db.prepare(query).map { row in
                TagInfo(
                    id: row[t[TagsTable.id]],
                    name: row[t[TagsTable.name]],
                    activeEmailsCount: LeadsTable.countLeads(with: row[t[TagsTable.id]]),
                    allEmailsCount: row[allLeadsCountExpr]
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
    
    func updateLastExportRequest(newExportRequest: ExportRequest) {
        lastExportRequest = newExportRequest
        let jsonTagsRequests = try? JSONEncoder().encode(newExportRequest)
        let jsonStringTagsRequests = String(
            data: jsonTagsRequests ?? Data(),
            encoding: .utf8
        )!
        
        do {
            let db = DatabaseManager.shared.db
            let domainIdFilter = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try db?.run(domainIdFilter.update(
                DomainsTable.lastExportRequest <- jsonStringTagsRequests,
            ))
            
            if let updatedRow = try db?.pluck(domainIdFilter) {
                dbRow = updatedRow
            }
            
            print("Domain updated: \(name)")
            
        } catch {
            print("Failed to update domain: \(error)")
        }
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
            guard url?.startAccessingSecurityScopedResource() != nil else {
                print("❌ Failed to access bookmark security scope.")
                return nil
            }
            
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
            let domainIdFilter = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try db?.run(domainIdFilter.update(
                DomainsTable.name <- name,
                DomainsTable.abbreviation <- abbreviation,
                DomainsTable.exportType <- exportType,
                DomainsTable.saveFolder <- Self.createBlob(from: saveFolder),
                DomainsTable.useLimit <- useLimit,
                DomainsTable.globalUseLimit <- globalUseLimit
            ))
            
            if let updatedRow = try db?.pluck(domainIdFilter) {
                dbRow = updatedRow
            }
            
            print("Domain updated: \(name)")
            
        } catch {
            print("Failed to update domain: \(error)")
        }
    }
    
    func copyUpdates(from domain: DomainViewModel) {
        name = domain.name
        abbreviation = domain.abbreviation
        exportType = domain.exportType
        saveFolder = domain.saveFolder
        useLimit = domain.useLimit
        globalUseLimit = domain.globalUseLimit
        deleted = domain.deleted
        
        saveToDb()
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
