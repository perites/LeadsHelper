//
//  SettingsView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 22/10/2025.
//

import SwiftUI

struct DomainSettingsView: View {
    @ObservedObject var domain: DomainViewModel
    @ObservedObject var editableDomain: DomainViewModel

    @Binding var mode: Mode

    @State private var isShowingFolderPicker = false
    @State private var isShowingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NameSettingView
                    AbbreviationSettingView
                    ExportTypeSettingView
                    SaveFolderSettingView
                    UseLimitSettingView
                    GlobalUseLimitSettingView
                }
            }
            Divider()
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                SaveButton
            }
        }
    }

    private var Header: some View {
        HStack {
            Text("Settings for \(domain.name)").font(.title3).fontWeight(.semibold)
            Spacer()
            DeleteButton
        }
    }

    private var NameSettingView: some View {
        HStack {
            Text("Name")
            TextField("Name", text: $editableDomain.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var AbbreviationSettingView: some View {
        HStack {
            Text("Abbreviation")
            TextField("Abbreviation", text: $editableDomain.abbreviation)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var ExportTypeSettingView: some View {
        Picker("Export Type", selection: $editableDomain.exportType) {
            Text("Regular").tag(0)
            Text("Exact Target").tag(1)
            Text("Blueshift").tag(2)
        }
        .pickerStyle(.segmented)
    }

    private var SaveFolderSettingView: some View {
        HStack {
            Text("Save Folder: \(editableDomain.saveFolder?.path ?? "Not Set")")
            Spacer()
            Button(action: { isShowingFolderPicker = true }) {
                Label("Change", systemImage: "folder")
            }.fileImporter(
                isPresented: $isShowingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedFolder = urls.first {
                        editableDomain.saveFolder = selectedFolder
                    }
                case .failure(let error):
                    print("❌ Failed to pick folder: \(error)")
                }
            }
        }
    }

    private var UseLimitSettingView: some View {
        HStack {
            Text("Used in this domain at least")
            TextField("days", value: $editableDomain.useLimit, format: .number)
                .textFieldStyle(.roundedBorder)
            Text("days ago")
        }
    }

    private var GlobalUseLimitSettingView: some View {
        HStack {
            Text("Used overall at least")
            TextField(
                "days",
                value: $editableDomain.globalUseLimit,
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            Text("days ago")
        }
    }

    private var SaveButton: some View {
        Button(
            action: {
                let limitChanged = domain.copyUpdates(from: editableDomain)
                if limitChanged  {
                    domain.getTagsInfo()
                }
                ToastManager.shared.show(style: .info, message: "Domain \(domain.name) updated")
                mode = .info

            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gear.badge.checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Save")
                        .font(.title2)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.green.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
    }

    private var DeleteButton: some View {
        Button(
            action: {
                isShowingDeleteAlert = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                    Text("Delete Domain")
                        .font(.body)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.red.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Delete Domain?", isPresented: $isShowingDeleteAlert) {
                Button("Delete", role: .none) {
                    domain.delete()
                    ToastManager.shared.show(style: .info, message: "Domain \(domain.name) deleted successfully")
                    mode = .deleted
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this domain?")
            }
    }
}
