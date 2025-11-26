//
//  ContentView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import SFSymbols
import SwiftUI

class DomainsViewModel: ObservableObject {
    @Published var domains: [DomainViewModel] = []

    func fetchDomais() async {
        let query = DomainsTable.table.filter(DomainsTable.isActive)
        guard let rows = try? await DatabaseActor.shared.dbFetch(query) else {
            return
        }

        let result = rows.map { row in DomainViewModel(from: row) }

        for domain in result {
            domain.tagsInfo = await TagsTable.getTags(with: domain.id)
            domain.getLastExportRequest()
        }

        for domain in result {
            domain.getTagsCount()
        }

        guard !Task.isCancelled else { return }
        await MainActor.run {
            domains = result
        }
    }

    func addDomain() async -> DomainViewModel? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
        let dateString = formatter.string(from: Date())
        let rowId = await DomainsTable.addDomain(newName: "New Domain \(dateString)")
        guard let rowId else { return nil }
        let domainRow = await DomainsTable.findById(id: rowId)!
        let domain = DomainViewModel(from: domainRow)
        domain.tagsInfo = await TagsTable.getTags(with: domain.id)
        return domain
    }
}

struct DomainRowView: View {
    @ObservedObject var domain: DomainViewModel

    var body: some View {
        if !domain.isActive {
            EmptyView()
        } else {
            Text(domain.name)
                .font(.title3)
                .tag(domain.id)
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = DomainsViewModel()
    @State private var selectedDomainId: Int64?
    @State private var searchText: String = ""

    @State private var justCreatedDomainId: Int64?

    var filteredDomains: [DomainViewModel] {
        if searchText.isEmpty {
            return viewModel.domains.filter { $0.isActive }
        } else {
            return viewModel.domains
                .filter {
                    $0.isActive && (
                        $0.name
                            .localizedCaseInsensitiveContains(
                                searchText
                            ) || $0.abbreviation
                            .localizedCaseInsensitiveContains(searchText)
                    )
                }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDomainId) {
                ForEach(filteredDomains) { domain in
                    DomainRowView(domain: domain)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250, idealWidth: 250)
            .navigationTitle("Domains List")
            .searchable(text: $searchText, placement: .sidebar)
            .toolbar {
                Spacer()
                Button(action: {
                    Task {
                        let createdDomain = await viewModel.addDomain()
                        guard let createdDomain else {
                            ToastManager.shared.show(
                                style: .error,
                                message: "Could not create domain!"
                            )
                            return
                        }
                        await MainActor.run {
                            viewModel.domains.append(createdDomain)
                            selectedDomainId = createdDomain.id
                            justCreatedDomainId = createdDomain.id
                            ToastManager.shared.show(
                                style: .success,
                                message: "Domain created successfully!",
                                duration: 3
                            )
                        }
                    }
                }) {
                    Image(systemName: "plus.circle")
                }
            }

        } detail: {
            if let selectedId = selectedDomainId, let domainIndex = viewModel.domains.firstIndex(where: { $0.id == selectedId }) {
                let domain = viewModel.domains[domainIndex]
                let startMode: Mode = (justCreatedDomainId == selectedId) ? .edit : .info
                
                DomainDetailedView(domain: domain, initialMode: startMode).id(selectedId)

            } else {
                Text("Select a domain").foregroundStyle(.secondary)
            }
        }.task {
            await viewModel.fetchDomais()
        }.onChange(of: selectedDomainId) { _, selectedId in
            if justCreatedDomainId != selectedId {
                justCreatedDomainId = nil
            }
        }
    }

    private func binding(for domainId: Int64) -> Binding<DomainViewModel>? {
        guard let index = viewModel.domains.firstIndex(where: { $0.id == domainId }) else {
            print("Domain id: \(domainId) not found in domains")
            return nil
        }
        return $viewModel.domains[index]
    }
}
