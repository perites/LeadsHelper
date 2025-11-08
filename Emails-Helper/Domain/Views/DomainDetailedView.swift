//
//  DomainDetailView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import AppKit
import SwiftUI

enum Mode: String {
    case edit
    case info
    case importLeads
    case exportLeads
    case deleted
}

struct DomainDetailedView: View {
    @ObservedObject var domain: DomainViewModel

    @State private var mode: Mode = .info

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if domain.deleted {
                DomainDeletedView()
            } else {
                switch mode {
                case .info:
                    DomainInfoView(domain: domain, mode: $mode)
                case .edit:
                    DomainSettingsView(
                        domain: domain,
                        editableDomain: DomainViewModel(
                            from: domain.dbRow,
                        ),
                        mode: $mode
                    )
                case .importLeads:
                    DomainImportView(domain: domain, mode: $mode)
                case .exportLeads:
                    DomainExportView(domain: domain, mode: $mode)
                case .deleted:
                    DomainDeletedView()
                }
            }
        }
        .padding()
        .navigationTitle(domain.abbreviation)
        .toolbar {
            Button(action: { mode = .edit }) {
                Image(systemName: "gearshape")
            }
        }
        .frame(minWidth: 700, idealWidth: 700)
    }
}

struct DomainDeletedView: View {
    var body: some View {
        Text("Deleted Domain")
    }
}
