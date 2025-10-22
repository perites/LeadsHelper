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
                }
            }
            Divider()
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                SaveButton
            }
        }.padding()
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

    private var SaveButton: some View {
        Button(
            action: {
                domain.copyUpdates(from: editableDomain)
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
                domain.delete()
                ToastManager.shared.show(style: .info, message: "Domain \(domain.name) deleted successfully")
                mode = .deleted
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
    }
}
