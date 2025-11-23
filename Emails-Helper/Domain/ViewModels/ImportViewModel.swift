//
//  ImportViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import Foundation
import SwiftUI
import TabularData

class ImportViewModel: ObservableObject {
    enum ImportResult {
        case failure
        case success
    }
    
    func importLeads(
        importName: String,
        tagId: Int64,
        allEmails: [String],
        inputType: Int
        
    ) async -> ImportResult {
        let start = Date()
        
        let importId = await ImportsTable.addImport(
            newName: importName,
            newTagId: tagId,
            newType: inputType,
            newEmailsAmount: allEmails.count
        )!
        
        await DatabaseActor.shared.addLeadsBulk(
            newEmails: allEmails,
            newImportId: importId,
            newTagId: tagId
        )
        
        let timeElapsed = Date().timeIntervalSince(start)
        print("Import took \(timeElapsed) seconds. Type : \(inputType)")
        return .success
    }
}
