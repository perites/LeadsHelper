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
    
    var updateTask: Task<Void, Never>?
    
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
    
    init(from dbRow: Row) {
        self.id = dbRow[DomainsTable.id]
        _name = .init(initialValue: dbRow[DomainsTable.name])
        _abbreviation = .init(initialValue: dbRow[DomainsTable.abbreviation])
        _exportType = .init(initialValue: dbRow[DomainsTable.exportType])
        
        if let blob = dbRow[DomainsTable.saveFolder] {
            let data = Data(blob.bytes)
            _saveFolder = .init(initialValue: Self.createUrl(from: data))
        }
        
        _useLimit = .init(initialValue: dbRow[DomainsTable.useLimit])
        _globalUseLimit = .init(initialValue: dbRow[DomainsTable.globalUseLimit])
        
        _tagsInfo = .init(initialValue: [])
        _isActive = .init(initialValue: dbRow[DomainsTable.isActive])
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
    
    func getLastExportRequest() {
        Task {
            let lastExport = await ExportTable.getLastExport(domainId: id)
            await MainActor.run {
                lastExportRequest = lastExport
            }
        }
        
        
    }
    
    func getTagsCount() {
        fetchTagsCountTask?.cancel()
        
        fetchTagsCountTask = Task {
            guard !Task.isCancelled else { return }
            
            let statsMap = await LeadsTable.getBatchTagStats(
                tagIds: tagsInfo.map { $0.id },
                domainId: self.id,
                domainUseLimit: self.useLimit,
                globalUseLimit: self.globalUseLimit
            )
            
            guard !Task.isCancelled else { return }
            
            var updatedList = tagsInfo
            for index in updatedList.indices {
                let id = updatedList[index].id
                if let stats = statsMap[id] {
                    updatedList[index].inactiveLeadsCount = stats.inactive
                    updatedList[index].activeLeadsCount = stats.active
                    updatedList[index].availableLeadsCount = stats.available
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
    
    enum updateType {
        case basics
        case isActive
    }
    
    func saveToDb(updateType: updateType) {
        let setters: [Setter]
        switch updateType {
        case .basics:
            setters = [
                DomainsTable.name <- name,
                DomainsTable.abbreviation <- abbreviation,
                DomainsTable.exportType <- exportType,
                DomainsTable.saveFolder <- Self.createBlob(from: saveFolder),
                DomainsTable.useLimit <- useLimit,
                DomainsTable.globalUseLimit <- globalUseLimit
            ]
        
        case .isActive:
            setters = [DomainsTable.isActive <- isActive]
        }
        
        let domainIdFilter = DomainsTable.table.filter(DomainsTable.id == id)
        
        Task {
            do {
                try await DatabaseActor.shared.dbUpdate(domainIdFilter.update(setters))
                print("Domain updated: \(name). Type: \(updateType)")
            } catch {
                print("Failed to update domain: \(error)")
            }
        }
    }
    
    
    
    func setInactive() {
        isActive = false
        saveToDb(updateType: .isActive)
    }
    
    func copyUpdates(from domain: FakeDomainViewModel) {
        name = domain.name.isEmpty ? name : domain.name
        abbreviation = domain.abbreviation.isEmpty ? abbreviation : domain.abbreviation
        exportType = domain.exportType
        saveFolder = domain.saveFolder
        
        let limitsChanged = (useLimit != domain.useLimit || globalUseLimit != domain.globalUseLimit)
        
        useLimit = domain.useLimit
        globalUseLimit = domain.globalUseLimit
        
        saveToDb(updateType: .basics)
        
        if limitsChanged {
            getTagsCount()
        }
    }
    
    func addTag() async -> Int64? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
        let dateString = formatter.string(from: Date())
        let newName = "New Tag \(dateString)"
        let createdTagId = await TagsTable.addTag(newName: newName, newDomainId: id)
        guard let createdTagId else { return nil }
        
        await MainActor.run {
            tagsInfo.append(TagInfo(id: createdTagId, name: newName, idealAmount: 0))
            tagsInfo = tagsInfo.sorted { $0.name < $1.name }
        }
        return createdTagId
    }
    
    enum TagUpdateType {
        case basics(String, Int)
        case count
        case isActive
    }
    
    func updateTagInfo(tagId: Int64, type: TagUpdateType) {
        let index = tagsInfo.firstIndex(where: { $0.id == tagId })
        guard let index else { return }
        
        switch type {
        case .basics(let newName, let newIdealAmount):
            tagsInfo[index].name = newName
            tagsInfo[index].idealAmount = newIdealAmount
            tagsInfo = tagsInfo.sorted { $0.name < $1.name }
            Task {
                await TagsTable.editTag(id: tagId, newName: newName, newIdealAmount: newIdealAmount)
            }
            
        case .count:
            tagsInfo[index].updateTask?.cancel()
            tagsInfo[index].updateTask = Task {
                guard !Task.isCancelled else { return }
                let tagCount = await LeadsTable.getTagStats(
                    tagId: tagId,
                    domainId: self.id,
                    domainUseLimit: self.useLimit,
                    globalUseLimit: self.globalUseLimit
                )
                
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    tagsInfo[index].inactiveLeadsCount = tagCount.inactiveLeadsCount
                    tagsInfo[index].activeLeadsCount = tagCount.activeLeadsCount
                    tagsInfo[index].availableLeadsCount = tagCount.availableLeadsCount
                    tagsInfo[index].updateTask = nil
                }
            }
            
        case .isActive:
            tagsInfo.remove(at: index)
            Task { await TagsTable.deleteTag(id: tagId) }
        }
    }
}
