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
    
    var inactiveLeadsCount: Int?
    var activeLeadsCount: Int?
    var availableLeadsCount: Int?
    
    var updateTask:Task<Void, Never>?
    
    var allLeadsCount: Int? {
        guard let inactiveLeadsCount, let activeLeadsCount else {
            return nil
        }
        return inactiveLeadsCount + activeLeadsCount
    }
    
    var unavailableLeadsCount: Int? {
        guard let activeLeadsCount, let availableLeadsCount else {
            return nil
        }
        return activeLeadsCount - availableLeadsCount
    }
}

class DomainViewModel: ObservableObject, Identifiable {
    let id: Int64
    
    @Published var name: String
    @Published var abbreviation: String
    @Published var exportType: Int
    @Published var saveFolder: URL?
    @Published var isActive: Bool
    @Published var lastExportRequest: ExportRequest?
    @Published var useLimit: Int
    @Published var globalUseLimit: Int
    
    @Published var tagsInfo: [TagInfo]
    
    @Published var fetchTagsCountTask: Task<Void, Never>?
    
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
        _isActive = .init(initialValue: dbRow[DomainsTable.isActive])
        
        self.dbRow = dbRow
    }
    
//    func getTags() -> [(id: Int64, name: String, idealAmount: Int)]? {
//        let query = TagsTable.table.filter(TagsTable.domainId == id && TagsTable.isActive == true).select(
//            TagsTable.id,
//            TagsTable.name,
//            TagsTable.idealAmount
//        )
//
//        do {
//            let result = try DatabaseManager.shared.db.prepare(
//                query
//            ).map { row in
//                (
//                    id: row[TagsTable.id],
//                    name: row[TagsTable.name],
//                    idealAmount: row[TagsTable.idealAmount]
//                )
//            }
//            return result
//        } catch {
//            print("Failed to fetch tags with lead counts: \(error)")
//            return nil
//        }
//    }
//
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
    
//    func getTagsInfo() {
//        fetchTagsCountTask?.cancel()
//        fetchTagsCountTask = Task {
//            let result = LeadsTable.getEmails(
//                with: ,
//                domainId: <#T##Int64#>,
//                amount: <#T##Int#>,
//                domainUseLimit: <#T##Int#>,
//                globalUseLimit: <#T##Int#>,
//                justCount: <#T##Bool#>
//            )
//
//
//
//            (
//                domainId: id,
//                useLimit: useLimit,
//                globalUseLimit: globalUseLimit
//            )
//
//            guard !Task.isCancelled else { return }
//            await MainActor.run {
//                self.tagsInfo = result
//                self.fetchTagsCountTask = nil
//                ToastManager.shared
//                    .show(style: .info, message: "Tags Info loaded for \(name)")
//            }
//        }
//    }
    
//    func getTagsCount() {
//        fetchTagsCountTask?.cancel()
//        fetchTagsCountTask = Task {
//
//            var updatedList = self.tagsInfo
//            for index in updatedList.indices {
//                guard !Task.isCancelled else { return }
//                let tagId = updatedList[index].id
//                let result = await LeadsTable.getTagStats(
//                    tagId: tagId,
//                    domainId: self.id,
//                    domainUseLimit: self.useLimit,
//                    globalUseLimit: self.globalUseLimit,
//                )
//                updatedList[index].inactiveLeadsCount = result.inactiveLeadsCount
//                updatedList[index].activeLeadsCount = result.activeLeadsCount
//                updatedList[index].availableLeadsCount = result.availableLeadsCount
//            }
//
//            let finalList = updatedList
//
//            guard !Task.isCancelled else { return }
//
//            await MainActor.run {
//                self.tagsInfo = finalList
//                self.fetchTagsCountTask = nil
//
//                ToastManager.shared.show(
//                    style: .info,
//                    message: "Tags Info loaded for \(self.name)"
//                )
//            }
//        }
//    }
    
    func getTagsCount() {
        fetchTagsCountTask?.cancel()
        
        let currentTags = tagsInfo
        let tagIds = currentTags.map { $0.id }
        
        fetchTagsCountTask = Task {
            guard !Task.isCancelled else { return }
            
            let statsMap = await LeadsTable.getBatchTagStats(
                tagIds: tagIds,
                domainId: self.id,
                domainUseLimit: self.useLimit,
                globalUseLimit: self.globalUseLimit
            )
            
            guard !Task.isCancelled else { return }

            var updatedList = currentTags
            for index in updatedList.indices {
                let id = updatedList[index].id
                if let stats = statsMap[id] {
                    updatedList[index].inactiveLeadsCount = stats.inactive
                    updatedList[index].activeLeadsCount = stats.active
                    updatedList[index].availableLeadsCount = stats.available
                } else {
                    updatedList[index].inactiveLeadsCount = 0
                    updatedList[index].activeLeadsCount = 0
                    updatedList[index].availableLeadsCount = 0
                }
            }
            
            let finalList = updatedList
            await MainActor.run {
                self.tagsInfo = finalList
                self.fetchTagsCountTask = nil
                
                ToastManager.shared.show(
                    style: .info,
                    message: "Tags Info loaded for \(self.name)"
                )
            }
        }
    }
    
    enum TagUpdateType {
        case count
        case text(String, Int)
    }

    func deleteTag(tagId: Int64) async {
        await TagsTable.deleteTag(id: tagId)
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
        
        tagsInfo = tagsInfo.sorted { $0.name < $1.name }
    }
    
    func updateTagInfo(tagId: Int64, type: TagUpdateType) {
        let index = tagsInfo.firstIndex(where: { $0.id == tagId })
        guard let index else { return }
            
        switch type {
        case .text(let newName, let newIdealAmount):
            Task{
                await TagsTable.editTag(id: tagId, newName: newName, newIdealAmount: newIdealAmount)
                await MainActor.run {
                    tagsInfo[index].name = newName
                    tagsInfo[index].idealAmount = newIdealAmount
                    tagsInfo = tagsInfo.sorted { $0.name < $1.name }
                }
            }
            
        case .count:
            tagsInfo[index].updateTask =  Task {
                
                
                
                let tagCount = await LeadsTable.getTagStats(
                    tagId: tagId,
                    domainId: self.id,
                    domainUseLimit: self.useLimit,
                    globalUseLimit: self.globalUseLimit
                )
                await MainActor.run {
                    tagsInfo[index].inactiveLeadsCount = tagCount.inactiveLeadsCount
                    tagsInfo[index].activeLeadsCount = tagCount.activeLeadsCount
                    tagsInfo[index].availableLeadsCount = tagCount.availableLeadsCount
                    tagsInfo[index].updateTask = nil
                }
            }
        }
    }
    
    func updateLastExportRequest(newExportRequest: ExportRequest) async {
        lastExportRequest = newExportRequest
        let jsonTagsRequests = try? JSONEncoder().encode(newExportRequest)
        let jsonStringTagsRequests = String(
            data: jsonTagsRequests ?? Data(),
            encoding: .utf8
        )!
        
        do {
            let domainIdFilter = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try await DatabaseActor.shared.dbUpdate(domainIdFilter.update(
                DomainsTable.lastExportRequest <- jsonStringTagsRequests
            ))
            
            if let updatedRow = try await DatabaseActor.shared.dbPluck(
                domainIdFilter
            ) {
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
        Task {
            do {
                let domainIdFilter = DomainsTable.table.filter(
                    DomainsTable.id == id
                )
                try await DatabaseActor.shared.dbUpdate(domainIdFilter.update(
                    DomainsTable.name <- name,
                    DomainsTable.abbreviation <- abbreviation,
                    DomainsTable.exportType <- exportType,
                    DomainsTable.saveFolder <- Self.createBlob(from: saveFolder),
                    DomainsTable.useLimit <- useLimit,
                    DomainsTable.globalUseLimit <- globalUseLimit
                ))
                
                if let updatedRow = try await DatabaseActor.shared.dbPluck(
                    domainIdFilter
                ) {
                    dbRow = updatedRow
                }
                
                print("Domain updated: \(name)")
                
            } catch {
                print("Failed to update domain: \(error)")
            }
        }
    }
    
    func copyUpdates(from domain: DomainViewModel) -> Bool {
        name = domain.name.isEmpty ? name : domain.name
        abbreviation = domain.abbreviation.isEmpty ? abbreviation : domain.abbreviation
        exportType = domain.exportType
        saveFolder = domain.saveFolder
        
        let limitsChanged = (useLimit != domain.useLimit || globalUseLimit != domain.globalUseLimit)
        
        useLimit = domain.useLimit
        globalUseLimit = domain.globalUseLimit
        
        isActive = domain.isActive
        
        saveToDb()

        return limitsChanged
    }
    
    func delete() async {
        do {
            let domainIdFilter = DomainsTable.table.filter(
                DomainsTable.id == id
            )
            try await DatabaseActor.shared.dbUpdate(domainIdFilter.update(
                DomainsTable.isActive <- false
            ))
            
            if let updatedRow = try await DatabaseActor.shared.dbPluck(
                domainIdFilter
            ) {
                dbRow = updatedRow
            }
            
            print("Domain set inactive: \(name)")
            
        } catch {
            print("Failed to update domain: \(error)")
        }
    }
}
