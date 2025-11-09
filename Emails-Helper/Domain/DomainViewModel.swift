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
    var name: String
    var idealAmount: Int
    
    var inactiveLeadsCount: Int
    var activeLeadsCount: Int
    var availableLeadsCount: Int
    
    var allLeadsCount: Int {
        inactiveLeadsCount + activeLeadsCount
    }
    
    var unavailableLeadsCount: Int {
        activeLeadsCount - availableLeadsCount
    }
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
    
    var fetchTagsTask: Task<Void, Never>?
    
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
        
        _tagsInfo = .init(initialValue: [])
        
        self.dbRow = dbRow
    }
    
    func getTags() -> [(id: Int64, name: String, idealAmount: Int)]? {
        let query = TagsTable.table.filter(TagsTable.domainId == id && TagsTable.isActive == true).select(
            TagsTable.id,
            TagsTable.name,
            TagsTable.idealAmount
        )
                
        do {
            let result = try DatabaseManager.shared.db.prepare(
                query
            ).map { row in
                (
                    id: row[TagsTable.id],
                    name: row[TagsTable.name],
                    idealAmount: row[TagsTable.idealAmount]
                )
            }
            return result
        } catch {
            print("Failed to fetch tags with lead counts: \(error)")
            return nil
        }
    }
    
//    func getTagsInfo() {
//        let tags = getTags()
//        var result: [TagInfo] = []
//        
//        for tag in tags ?? [] {
//            let tagCount = getTagCount(for: tag.id)
//            
//            result
//                .append(
//                    TagInfo(
//                        id: tag.id,
//                        name: tag.name,
//                        idealAmount: tag.idealAmount,
//                        inactiveLeadsCount: tagCount.inactive,
//                        activeLeadsCount: tagCount.active,
//                        availableLeadsCount: tagCount.available
//                    )
//                )
//        }
//            
//        tagsInfo = result
//    }
    
    func getTagsInfo() {
        fetchTagsTask?.cancel()
        fetchTagsTask = Task(priority: .high) {
            

            
            let result = LeadsTable.fetchTagsInfoData(
                domainId: id,
                useLimit: useLimit,
                globalUseLimit: globalUseLimit
            )
            
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.tagsInfo = result
                self.fetchTagsTask = nil
                ToastManager.shared
                    .show(style: .info, message: "Tags Info loaded for \(name)")
            }
        }
        
    }
    
    
    
    
    
    
    
    
    
    
//    func getTagCount(for tagId: Int64) -> (inactive: Int, active: Int, available: Int) {
//        let inactiveLeadsCount = LeadsTable.countAllLeads(with: tagId, active: false)
//        let activeLeadsCount = LeadsTable.countAllLeads(with: tagId, active: true)
//        let availableLeadsCount = LeadsTable.countAvailableLeads(
//            with: tagId,
//            domainId: id,
//            domainUseLimit: useLimit,
//            globalUseLimit: globalUseLimit
//        )
//        
//        return (inactive: inactiveLeadsCount, active: activeLeadsCount, available: availableLeadsCount)
//    }
    
    enum TagUpdateType {
        case count
        case text(String, Int)
    }

    func deleteTag(tagId: Int64) {
        TagsTable.deleteTag(id: tagId)
        tagsInfo.removeAll { $0.id == tagId }
    }
    
    func addTagInfo(tagId: Int64, name: String, idealAmount: Int) {
        tagsInfo
            .append(
                TagInfo(
                    id: tagId,
                    name: name,
                    idealAmount: idealAmount,
                    inactiveLeadsCount: 0,
                    activeLeadsCount: 0,
                    availableLeadsCount: 0
                )
            )
    }
    
    func updateTagInfo(tagId: Int64, type: TagUpdateType) {
        let index = tagsInfo.firstIndex(where: { $0.id == tagId })
        guard let index else { return }
            
        switch type {
        case .text(let newName, let newIdealAmount):
            TagsTable.editTag(id: tagId, newName: newName, newIdealAmount: newIdealAmount)
            tagsInfo[index].name = newName
            tagsInfo[index].idealAmount = newIdealAmount
            
        case .count:
            print("Count Updates Not Ready")
//            let tagCount = getTagCount(for: tagId)
//            tagsInfo[index].inactiveLeadsCount = tagCount.inactive
//            tagsInfo[index].activeLeadsCount = tagCount.active
//            tagsInfo[index].availableLeadsCount = tagCount.available
        }
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
                DomainsTable.lastExportRequest <- jsonStringTagsRequests
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
    
    func copyUpdates(from domain: DomainViewModel) -> Bool {
        name = domain.name.isEmpty ? name : domain.name
        abbreviation = domain.abbreviation.isEmpty ? abbreviation : domain.name
        exportType = domain.exportType
        saveFolder = domain.saveFolder
        
        let limitsChanged = (useLimit != domain.useLimit || globalUseLimit != domain.globalUseLimit)
        
        useLimit = domain.useLimit
        globalUseLimit = domain.globalUseLimit
        
        deleted = domain.deleted
        
        saveToDb()

        
        return limitsChanged
        
        
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
