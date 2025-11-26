//
//  DomainDetailView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import AppKit
import SwiftUI

enum Mode: Equatable {
    case edit
    case info
    case importLeads(Int64)
    case exportLeads
    case deleted
    case bulkImport
    case download(Bool, Int64?)
    case exclude(Bool, Int64?)
    case history(Int64)
    case exportsHistory

    var name: String {
        switch self {
        case .info: return "Dashboard"
        case .deleted: return "Deleted"
        case .edit: return "Settings"
        case .importLeads: return "Leads Import"
        case .exportLeads: return "Leads Export"
        case .bulkImport: return "Bulk Import"
        case .download: return "Leads Download"
        case .exclude: return "Leads Exclude"
        case .history: return "Imports History"
        case .exportsHistory: return "Exports History"
        case _: return "404"
        }
    }

    var transition: AnyTransition {
        switch self {
        case .edit:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )

        case .exportLeads, .exportsHistory:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )

        case .importLeads, .bulkImport, .history:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )

        case .download, .exclude:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )

        default:
            return .opacity
        }
    }
}

struct DomainDetailedView: View {
    @ObservedObject var domain: DomainViewModel

    @State private var mode: Mode

    init(domain: DomainViewModel, initialMode: Mode = .info) {
        self.domain = domain
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                if !domain.isActive {
                    DomainDeletedView()
                } else {
                    switch mode {
                    case .info:
                        DomainInfoView(domain: domain, mode: $mode)
                    case .edit:
                        DomainSettingsView(
                            domain: domain,
                            mode: $mode
                        )
                    case .importLeads(let tagId):
                        DomainImportView(
                            domain: domain,
                            mode: $mode,
                            selectedTagId: tagId
                        )
                    case .exportLeads:
                        DomainExportView(domain: domain, mode: $mode)
                    case .deleted:
                        DomainDeletedView()
                    case .bulkImport:
                        DomainBulkImportView(domain: domain, mode: $mode)
                    case .download(let downloadAllTags, let tagId):
                        DomainDownloadView(
                            domain: domain,
                            mode: $mode,
                            downloadAllTags: downloadAllTags,
                            selectedTagId: tagId
                        )
                    case .exclude(let excludeAllTags, let tagId):
                        DomainExcludeView(
                            domain: domain,
                            mode: $mode,
                            excludeFromAll: excludeAllTags,
                            selectedTagId: tagId
                        )
                    case .history(let tagId):
                        DomainImportHistoryView(domain: domain, initialTagId: tagId, mode: $mode)
                    case .exportsHistory:
                        DomainExportHistoryView(domain: domain, mode: $mode)
                    }
                }
            }
            .transition(mode.transition)
        }
        .padding()
        .navigationTitle("\(domain.abbreviation) - \(mode.name)")
        .toolbar {
            Button(action: { mode = .edit }) {
                Image(systemName: "gearshape")
            }
        }
        .frame(minWidth: 700, idealWidth: 700)
        .animation(.easeInOut(duration: 0.3), value: mode)
    }
}

struct DomainDeletedView: View {
    var body: some View {
        Text("Deleted Domain")
    }
}
