//
//  ExcludeView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//

import SwiftUI

struct DomainExcludeView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode
    
    @StateObject var viewModel: ExcludeViewModel = .init()
    @StateObject var emailsInputViewModel: EmailsInputViewModel = .init()
    
    @State var excludeFromAll: Bool
    @State var selectedTagId: Int64?
    
    @State var isExcluding: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TagPickerView(
                domain: domain,
                pickedTagId: $selectedTagId,
                mode: .allowAll($excludeFromAll)
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
                ConfirmExcludeButton
            }
            .padding(.top, 10)
        }
        .loadingOverlay(isShowing: $isExcluding, text: "Excluding...")
    }
    
    private var ConfirmExcludeButton: some View {
        Button(
            action: {
                Task { @MainActor in
                    isExcluding = true
                  
                    guard let allEmails = emailsInputViewModel.emailsAll,
                          let _ = emailsInputViewModel.inputType
                    else {
                        ToastManager.shared.show(style: .warning, message: "Wait for Leads to load")
                        isExcluding = false
                        return
                    }
                    
                    if !excludeFromAll && selectedTagId == nil {
                        ToastManager.shared.show(style: .warning, message: "Choose Tag to Exclude")
                        isExcluding = false
                        return
                    }
                    
                    let result = await viewModel.excludeLeads(
                        domainId: domain.id,
                        excludeFromAll: excludeFromAll,
                        selectedTagId: selectedTagId,
                        allEmails: allEmails,
                    )
                    
                    isExcluding = false
                    
                    switch result {
                    case .failure:
                        ToastManager.shared.show(style: .error, message: "Error while excluding leads")
                    case .success:
                        ToastManager.shared
                            .show(
                                style: .success,
                                message: "Exclude Complete"
                            )
                        mode = .info
                        
                        if let selectedTagId {
                            domain.updateTagInfo(tagId: selectedTagId, type: .count)
                        } else {
                            domain.getTagsCount()
                        }
                    }
                }

            }) {
                HStack(spacing: 8) {
                    Image(systemName: "minus.circle")
                    Text("Finish Exclude")
                }
                .font(.title2)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.red.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
    }
}
