//
//  DomainImportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 17/10/2025.
//

import SwiftUI

struct DomainImportView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode
    
    @StateObject var importViewModel: ImportViewModel = .init()
    @StateObject var emailsInputViewModel: EmailsInputViewModel = .init()
    
    @State var importName: String = ""
    @State var selectedTagId: Int64?
    
    @State var isImporting: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImportNameInputView
            TagPickerView(
                domain: domain,
                pickedTagId: $selectedTagId,
                mode: .regular
            )
            
            Divider()
            
            HStack {
                FilesImportView(viewModel: emailsInputViewModel)
                TextImportView(viewModel: emailsInputViewModel)
            }
            
            Divider()
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                Text(
                    "Total Leads: \(emailsInputViewModel.emailsAll?.count.formatted(.number) ?? "Calculating...")"
                )
                Spacer()
                ImportButton
            }
            .padding(.top, 10)
        }
        .loadingOverlay(isShowing: $isImporting, text: "Importing...")
    }
        
    private var ImportNameInputView: some View {
        HStack {
            Text("Import Name:").font(.title3)
            TextField("Enter Import Name", text: $importName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
        
    private var ImportButton: some View {
        Button(
            action: {
                Task { @MainActor in
                    isImporting = true
                    
                    guard !importName.isEmpty else {
                        ToastManager.shared.show(style: .warning, message: "Import Name is required")
                        isImporting = false
                        return
                    }
                    
                    guard let allEmails = emailsInputViewModel.emailsAll,
                          let inputType = emailsInputViewModel.inputType,
                          allEmails.count > 0
                    else {
                        ToastManager.shared.show(style: .warning, message: "Wait for Leads to load")
                        isImporting = false
                        return
                    }
                    guard let selectedTagId else {
                        ToastManager.shared.show(style: .warning, message: "Choose Tag to import")
                        isImporting = false
                        return
                    }
                    
                    let result = await importViewModel.importLeads(
                        importName: importName,
                        tagId: selectedTagId,
                        allEmails: allEmails,
                        inputType: inputType
                    )
                    
                    isImporting = false
                    
                    switch result {
                    case .failure:
                        ToastManager.shared.show(style: .error, message: "Error while importing leads")
                    case .success:
                        ToastManager.shared
                            .show(
                                style: .success,
                                message: "Import Complete"
                            )
                        mode = .info
                        domain.updateTagInfo(tagId: selectedTagId, type: .count)
                    }
                }

            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.badge.plus")
                    Text("Finish Import")
                }
                .font(.title2)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.green.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
    }
}
