//
//  ContentView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var domains: [Domain] = []
    @State private var selectedDomain: Domain?
    @State private var searchText: String = ""

    var filteredDomains: [Domain] {
        if searchText.isEmpty {
            return domains.filter { !$0.deleted }
        } else {
            return domains.filter { !$0.deleted && ($0.name.localizedCaseInsensitiveContains(searchText) || $0.abbreviation.localizedCaseInsensitiveContains(searchText)) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDomain) {
                ForEach(filteredDomains) { domain in
                    Text(domain.name)
                        .font(.title3)
//                        .padding(.vertical,3)
                        .tag(domain)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250, idealWidth: 250)
            .navigationTitle("Domains List")
            .searchable(text: $searchText, placement: .sidebar)
            .toolbar {
                Spacer()
                Button(action: {
                    DomainsTable.addDomain(
                        newName: "New Domain \(domains.count + 1)"
                    )

                    domains = DomainsTable.fetchDomais()
                }) {
                    Image(systemName: "plus.circle")
                }
            }

        } detail: {
            if let domain = selectedDomain, let domainBinding = binding(for: domain) {
                DomainDetailView(domain:domainBinding ).id(domain.id)
            } else {
                Text("Select a domain")
                    .foregroundStyle(.secondary)
            }
        }.onAppear {
            domains = DomainsTable.fetchDomais()
        }
    }

    private func binding(for domain: Domain) -> Binding<Domain>? {
        guard let index = domains.firstIndex(where: { $0.id == domain.id }) else {
            print("Domain id: \(domain.id) not found in domains")
            return nil
        }
        return $domains[index]
    }
}
