//
//  ContentView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var domains: [Domain] = []

    var body: some View {
        NavigationView {
            VStack {
                List(domains.filter { !$0.deleted }, id: \.id) { domain in
                    HStack {
                        NavigationLink(destination: DomainDetailView(
                            domain: $domains[domains.firstIndex(where: { $0.id == domain.id })!]))
                        {
                            Text(domain.name)
                        }
                    }
                }
                .frame(maxWidth: 600)
                
                Text("\(LeadsTable.allCount())")
                Button("Add Domain") {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd:HH:mm:ss"
                    let nowString = formatter.string(from: Date())

                    DomainsTable.addDomain(
                        newName: nowString,
                        newAbbreviation: "ABC",
                        newExportType: 0
                    )

                    domains = DomainsTable.fetchDomais()
                }
                
                Button("Refresh"){
                    domains = DomainsTable.fetchDomais()
                }
            }
            .onAppear {
                domains = DomainsTable.fetchDomais()
            }
            .padding()
            .navigationTitle("Domains")
        }
    }
}
