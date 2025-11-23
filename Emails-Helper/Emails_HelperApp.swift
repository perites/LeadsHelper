//
//  Emails_HelperApp.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import SwiftUI

@main
struct Emails_HelperApp: App {
    init() {
        Task {
            await DatabaseActor.shared.createTables()
            await DatabaseActor.shared.migrate()
//            await DatabaseActor.shared.cleanupDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ToastContainerView {
                ContentView()
            }
        }
    }
}
