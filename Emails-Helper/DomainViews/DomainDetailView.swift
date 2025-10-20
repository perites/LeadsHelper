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
    case view
    case importLeads
    case exportLeads
    case deleted
}

struct DomainDetailView: View {
    @ObservedObject var domain: DomainViewModel
    
    @State private var mode: Mode = .view
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch mode {
            case .view:
                DomainInfoView(mode: $mode, domain: domain)
            case .edit:
//                Text("Edit View")
                EditDomainView(
                    mode: $mode,
                    originalDomain: domain
                )
            case .importLeads:
                DomainImportView(mode: $mode, domain: domain)
            case .exportLeads:
                Text("export View")
//                DomainExportView(mode: $mode, domain: $domain)
            case .deleted:
                DeleteDomainView()
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

struct DeleteDomainView: View {
    var body: some View {
        Text("Deleted Domain")
    }
}

struct EditDomainView: View {
    @Binding var mode: Mode
    @ObservedObject var originalDomain: DomainViewModel
    
    @ObservedObject var domain: DomainViewModel
    
    init(mode: Binding<Mode>, originalDomain: DomainViewModel) {
        self._mode = mode
        self.originalDomain = originalDomain
        // Create a COPY for editing
        self._domain = .init(
            initialValue: DomainViewModel(from: originalDomain.dbRow)
        )
    }

    var body: some View {
        TextField("Name", text: $domain.name)
            .textFieldStyle(.roundedBorder)
        
        TextField("Abbreviation", text: $domain.abbreviation)
            .textFieldStyle(.roundedBorder)
        
        Picker("Export Type", selection: $domain.exportType) {
            Text("Regular").tag(0)
            Text("Exact Target").tag(1)
            Text("Blueshift").tag(2)
        }
        .pickerStyle(.segmented)
        
        Text("Save Folder: \(domain.saveFolder?.path ?? "Not Set")")
        Button("Change Directory") {
            if let url = pickFolder(startingAt: domain.saveFolder) {
                print("url shoud update")
                domain.saveFolder = url
            }
        }
        
        HStack {
            Button("Cancel") {
                mode = .view
            }
            Button("Save") {
                originalDomain.name = domain.name
                originalDomain.abbreviation = domain.abbreviation
                originalDomain.exportType = domain.exportType
                originalDomain.saveFolder = domain.saveFolder
                
                originalDomain.saveToDb()
                
                mode = .view
            }
            .buttonStyle(.borderedProminent)
            
            Button("Delete Domain") {
                domain.delete()
                domain.deleted = true
                
                originalDomain.delete()
                originalDomain.deleted = true
                
                mode = .deleted
            }
        }
    }
    
    func pickFolder(startingAt initialURL: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        // Set initial directory
        if let initialURL = initialURL {
            panel.directoryURL = initialURL
        }

        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
