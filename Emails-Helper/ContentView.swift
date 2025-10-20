//
//  ContentView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import SwiftUI

class DomainsViewModel: ObservableObject {
    @Published var domains: [DomainViewModel]

    init() {
        _domains = .init(wrappedValue: Self.fetchDomais())
    }

    static func fetchDomais() -> [DomainViewModel] {
        guard let rows = try? DatabaseManager.shared.db.prepare(DomainsTable.table) else {
            return []
        }

        let result = rows.map { row in
            DomainViewModel(from: row)
        }

        return result
    }
    
    func addDomain() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH:mm:ss" // customize format
        let dateString = formatter.string(from: Date())
        let rowId = DomainsTable.addDomain(newName: "New Domain \(dateString)")
        if let rowId {
            ToastManager.shared
                .show(
                    style: .success,
                    message: "Domain created successfully!",
                    duration: 3
                )
            
            domains.append(DomainViewModel(from: DomainsTable.findById(id: rowId)!))
            
        } else {
            ToastManager.shared
                .show(
                    style: .error,
                    message: "Could not create domain!"
                )
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = DomainsViewModel()
    
    @State private var selectedDomainId: Int64?
    @State private var searchText: String = ""
    
    var filteredDomains: [DomainViewModel] {
        if searchText.isEmpty {
            return viewModel.domains.filter { !$0.deleted }
        } else {
            return viewModel.domains.filter { !$0.deleted && ($0.name.localizedCaseInsensitiveContains(searchText) || $0.abbreviation.localizedCaseInsensitiveContains(searchText)) }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDomainId) {
                ForEach(filteredDomains) { domain in
                    Text(domain.name)
                        .font(.title3)
                        .tag(domain.id)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250, idealWidth: 250)
            .navigationTitle("Domains List")
            .searchable(text: $searchText, placement: .sidebar)
            .toolbar {
                Spacer()
                Button(action: {
                    viewModel.addDomain()
                }) {
                    Image(systemName: "plus.circle")
                }
            }
            
            Button {
                //                    toast = Toast(style: .info, message: "Btw, you are a good person.")
                ToastManager.shared.show(style: .success, message:
                    "Leadsexportedsuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfullysuccessfully ✅", duration: 5)
                
            } label: {
                Text("Run (Info)")
            }
            
            Button {
                //                    toast = Toast(style: .info, message: "Btw, you are a good person.")
                ToastManager.shared
                    .show(
                        style: .error,
                        message: "Leads exported successfully ✅"
                    )
                
            } label: {
                Text("Run (error)")
            }
            
            Button {
                //                    toast = Toast(style: .info, message: "Btw, you are a good person.")
                ToastManager.shared
                    .show(
                        style: .info,
                        message: "Leads exported successfully ✅"
                    )
                
            } label: {
                Text("Run (info)")
            }
            
            Button {
                //                    toast = Toast(style: .info, message: "Btw, you are a good person.")
                ToastManager.shared
                    .show(
                        style: .warning,
                        message: "Leads exported successfully ✅"
                    )
                
            } label: {
                Text("Run (warming)")
            }
            
        } detail: {
            if let selectedId = selectedDomainId, let domainIndex = viewModel.domains.firstIndex(where: { $0.id == selectedId }) {
                let domain = viewModel.domains[domainIndex]
                DomainDetailView(domain: domain).id(selectedId)
            } else {
                Text("Select a domain").foregroundStyle(.secondary)
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
