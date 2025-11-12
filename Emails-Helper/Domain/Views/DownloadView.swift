//
//  DownloadView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 09/11/2025.
//


//
//  DomainDownloadView.swift
//  Emails-Helper
//
//  Created by Gemini
//

import SwiftUI

struct DomainDownloadView: View {
    @StateObject var viewModel: DownloadViewModel = .init()
    
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode
    
    
    @State var fileName: String = ""
    
    @State var downloadAllTags: Bool
    @State var selectedTagId: Int64?
    @State var activityState: ActivityState = .all
    @State var fieldsToInclude: Set<DownloadField> = [.email]
    
    @State private var isDownloading: Bool = false
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    TagPickerView(
                        domain: domain,
                        pickedTagId: $selectedTagId,
                        mode: .allowAll($downloadAllTags)
                    )
                    Divider()
                    ActivitySelectionView
                    Divider()
                    FieldSelectionView
                }
            }
            
            Divider()
            
            FooterView
        }
        .loadingOverlay(isShowing: $isDownloading, text: "Downloading...")
    }
    
    
    private var HeaderView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("File Name:").font(.title3)
                TextField("Download file name", text: $fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            SavePathView
        }
    }
    
    private var SavePathView: some View {
        Group {
            if let folder = domain.saveFolder {
                Text("Save Path: \(folder.path)/\(fileName).csv")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("Save Folder: Not set")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var ActivitySelectionView: some View {
        Picker("Include:", selection: $activityState) {
            ForEach(ActivityState.allCases) { state in
                Text(state.rawValue).tag(state)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var FieldSelectionView: some View {
        VStack(alignment: .leading) {
            Text("Fields to Include:").font(.headline)
            
            let columns = [GridItem(.adaptive(minimum: 200))]
            
            LazyVGrid(columns: columns, alignment: .leading) {
                ForEach(DownloadField.allCases) { field in
                    // We use a custom binding to ensure at least one
                    // field is always selected (i.e., .email)
                    Toggle(field.label, isOn: bindingForField(field))
                        .toggleStyle(.checkbox)
                        .disabled(field == .email) // Can't disable email
                }
            }
        }
    }
    
    private var FooterView: some View {
        HStack {
            GoBackButtonView(mode: $mode, goBackMode: .info)
            Spacer()
            DownloadButton
        }
        .padding(.top, 10)
    }
    
    private var DownloadButton: some View {
        Button(
action: {
            Task { @MainActor in
                isDownloading = true
                
                
                guard let saveFolderURL = domain.saveFolder else {
                    ToastManager.shared.show(style: .warning, message: "Save folder not set for this domain")
                    isDownloading = false
                    return
                }
                
                guard !fileName.isEmpty else {
                    ToastManager.shared.show(style: .warning, message: "File name is required")
                    isDownloading = false
                    return
                }
                
                
                let fileUrl = saveFolderURL.appendingPathComponent("\(fileName).csv")
                if !downloadAllTags && selectedTagId == nil {
                    ToastManager.shared.show(style: .warning, message: "Choose Tag to download")
                    isDownloading = false
                    return
                }
                
                
                let result = await viewModel.downloadLeads(
                    domainId: domain.id,
                    fileURL: fileUrl,
                    fieldsToInclude: fieldsToInclude,
                    downloadAllTags:downloadAllTags ,
                    selectedTagId :selectedTagId,
                    activityState: activityState
                )
                isDownloading = false
                
                switch result {
                case .success:
                    ToastManager.shared.show(style: .success, message: "Download Complete")
                    mode = .info
                case .failure:
                    ToastManager.shared.show(style: .error, message: "Download Failed")
                    
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Finish Download")
            }
            .font(.title2)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.blue.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    private func bindingForField(_ field: DownloadField) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                fieldsToInclude.contains(field)
            },
            set: { isSelected in
                if isSelected {
                    fieldsToInclude.insert(field)
                } else {
                    fieldsToInclude.remove(field)
                }
            }
        )
    }
}
