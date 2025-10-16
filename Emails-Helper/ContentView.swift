//
//  ContentView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 12/10/2025.
//
//
// import SwiftUI
//
// struct ContentView: View {
//    @State private var domains: [Domain] = []
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                List(domains.filter { !$0.deleted }, id: \.id) { domain in
//                    HStack {
//                        NavigationLink(destination: DomainDetailView(
//                            domain: $domains[domains.firstIndex(where: { $0.id == domain.id })!]))
//                        {
//                            Text(domain.name)
//                        }
//                    }
//                }
//                .frame(maxWidth: 600)
//
//                Text("\(LeadsTable.allCount())")
//                Button("Add Domain") {
//                    let formatter = DateFormatter()
//                    formatter.dateFormat = "yyyy-MM-dd:HH:mm:ss"
//                    let nowString = formatter.string(from: Date())
//
//                    DomainsTable.addDomain(
//                        newName: nowString,
//                        newAbbreviation: "ABC",
//                        newExportType: 0
//                    )
//
//                    domains = DomainsTable.fetchDomais()
//                }
//
//                Button("Refresh"){
//                    domains = DomainsTable.fetchDomais()
//                }
//            }
//            .onAppear {
//                domains = DomainsTable.fetchDomais()
//                print(domains.count)
//            }
//            .padding()
//            .navigationTitle("Domains")
//        }
//    }
// }

import SwiftUI




//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//        .frame(minWidth: 600, minHeight: 400)
//    }
//}


// Main View
struct ContentView: View {
    @State private var domains: [Domain] = []
    @State private var selectedDomainID: Int64?

    @State private var searchText: String = ""

    var filteredDomains: [Domain] {
        if searchText.isEmpty {
            return domains.filter { !$0.deleted }
        } else {
            return domains.filter { !$0.deleted && ($0.name.localizedCaseInsensitiveContains(searchText) || $0.abbreviation.localizedCaseInsensitiveContains(searchText))}
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                
                
                
                
                
                // Top controls
                HStack {
                    TextField("Search Domains", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 15))
                        
                    Button(action: addDomain) {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20) // size
                            .foregroundColor(.secondary)      // color
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding([.top, .horizontal])

                // Sidebar list
                List(filteredDomains, selection: $selectedDomainID) { domain in
                    Text(domain.name)
                        .font(.system(size: 15))

                        .tag(domain.id)
                }
                .listStyle(SidebarListStyle())
                
            }
            .frame(
                minWidth: 250,
                idealWidth: 250,
                maxWidth: .infinity
            )
            .navigationTitle("Domains")

        } detail: {
            if let selectedID = selectedDomainID {
                DomainDetailView(domain: $domains.first(where: { $0.id == selectedID })!)
                    .id(selectedID)  // ✅ This forces SwiftUI to recreate the view
            } else {
                Text("Select a domain")
                    .foregroundStyle(.secondary)
            }
        }


        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            domains = DomainsTable.fetchDomais()
        }
    }

    private func addDomain() {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMM-HHmmss"
        let nowString = formatter.string(from: Date())

        DomainsTable.addDomain(
            newName: "New Domain \(nowString)",
        )

        domains = DomainsTable.fetchDomais()
    }
}
