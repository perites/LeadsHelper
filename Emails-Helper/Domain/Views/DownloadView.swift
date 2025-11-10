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
    
    @StateObject var viewModel: DownloadViewModel
    @Binding var mode: Mode
    
    @State private var isDownloading: Bool = false
    
    init(domain: DomainViewModel, mode: Binding<Mode>, downloadAllTags: Bool, selectedTagId:Int64?) {
        _viewModel = StateObject(
            wrappedValue: DownloadViewModel(
                domain: domain,
                downloadAllTags:downloadAllTags,
                selectedTagId: selectedTagId
            )
        )
        _mode = mode
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    TagSelectionView
                    Divider()
                    ActivitySelectionView
                    Divider()
                    FieldSelectionView
                }
            }
            
            Divider()
            
            FooterView
        }
        .padding() // Add padding to match other views
        .loadingOverlay(isShowing: $isDownloading, text: "Downloading...")
    }
    
    // MARK: - Subviews
    
    private var HeaderView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("File Name:").font(.title3)
                TextField("Download file name", text: $viewModel.fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            SavePathView
        }
    }
    
    private var SavePathView: some View {
        Group {
            if let folder = viewModel.domain.saveFolder {
                let fileName = viewModel.fileName.isEmpty ? "download" : viewModel.fileName
                Text("Save Path: \(folder.path)/\(fileName).csv")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("Save Folder: Not set in domain settings")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var TagSelectionView: some View {
        VStack(alignment: .leading) {
            Toggle("Download from all tags", isOn: $viewModel.downloadAllTags.animation())
                .toggleStyle(.checkbox)
            
            if !viewModel.downloadAllTags {
                Picker("Select Tag:", selection: $viewModel.selectedTagId) {
                    // Use .constant(nil) for the "None" tag,
                    // but the picker requires a non-nil selection if possible.
                    // We assume selectedTagId is set in init.
                    ForEach(viewModel.domain.tagsInfo) { tag in
                        Text(tag.name).tag(tag.id as Int64?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 300)
            }
        }
    }
    
    private var ActivitySelectionView: some View {
        Picker("Include:", selection: $viewModel.activityState) {
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
                    Toggle(field.rawValue, isOn: bindingForField(field))
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
        Button(action: {
            Task { @MainActor in
                isDownloading = true
                let result = await viewModel.downloadLeads()
                isDownloading = false
                
                switch result {
                case .success:
                    ToastManager.shared.show(style: .success, message: "Download Complete")
                    mode = .info
                case .failure:
                    ToastManager.shared.show(style: .error, message: "Download Failed")
                case .noFolder:
                    ToastManager.shared.show(style: .warning, message: "Save folder not set for this domain")
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
        .disabled(viewModel.domain.saveFolder == nil)
    }
    
    // MARK: - Helper Methods
    
    /// Custom binding to manage the Set of fields
    private func bindingForField(_ field: DownloadField) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                viewModel.fieldsToInclude.contains(field)
            },
            set: { isSelected in
                if isSelected {
                    viewModel.fieldsToInclude.insert(field)
                } else {
                    // Prevent un-checking the last item
                    if viewModel.fieldsToInclude.count > 1 {
                        viewModel.fieldsToInclude.remove(field)
                    }
                }
            }
        )
    }
}
