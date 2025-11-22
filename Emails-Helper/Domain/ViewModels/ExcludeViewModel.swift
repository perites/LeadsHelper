//
//  ExcludeViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//

import Foundation
import SQLite



class ExcludeViewModel: ObservableObject {
    enum ExcludeResult {
        case failure
        case success
    }

    func excludeLeads(
        domainId: Int64,
        excludeFromAll: Bool,
        selectedTagId: Int64?,
        allEmails: [String]
    ) async -> ExcludeResult {
        
        let start = Date()
        
        // 1. Validation (Fast fail)
        if allEmails.isEmpty {
            print("ℹ️ Exclude complete: 0 leads provided.")
            return .success
        }

        // 2. Call the Actor
        do {
            // The Actor handles the Temp Table, Transaction, and Update safely
            try await DatabaseActor.shared.bulkExcludeLeads(
                domainId: domainId,
                excludeFromAll: excludeFromAll,
                selectedTagId: selectedTagId,
                emails: allEmails
            )
            
            let timeElapsed = Date().timeIntervalSince(start)
            print("✅ Exclude complete in \(String(format: "%.4f", timeElapsed)) seconds")
            return .success
            
        } catch {
            print("❌ Exclude leads failed: \(error)")
            return .failure
        }
    }
}
