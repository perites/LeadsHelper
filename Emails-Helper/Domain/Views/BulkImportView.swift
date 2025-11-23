//
//  BulkImportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 08/11/2025.
//

import SwiftUI

struct DomainBulkImportView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode

    @StateObject var viewModel: BulkImportViewModel = .init()

    @State var importName: String = ""

    @State var isImporting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImportNameInputView
            Divider()

            FilesImportView(viewModel: viewModel, domain: domain)

            Divider()
            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
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

                    guard viewModel.importFiles.count > 0 else { return }
                    guard !importName.isEmpty else {
                        ToastManager.shared
                            .show(
                                style: .warning,
                                message: "Import Name is required"
                            )
                        isImporting = false
                        return
                    }

                    let result = await viewModel.importLeads(importName: importName)

                    isImporting = false

                    switch result {
                    case .loading:
                        ToastManager.shared.show(style: .warning, message: "Wait for Leads to load")
                    case .tagNotSet:
                        ToastManager.shared.show(style: .warning, message: "Add tags to all files before importing")
                    case .failure:
                        ToastManager.shared.show(style: .error, message: "Error while importing leads")
                    case .success:
                        domain.getTagsCount()

                        ToastManager.shared
                            .show(
                                style: .success,
                                message: "Bulk Import Complete"
                            )
                        mode = .info
                    }
                }

            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.badge.plus.fill")
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

    private struct FilesImportView: View {
        @ObservedObject var viewModel: BulkImportViewModel
        @ObservedObject var domain: DomainViewModel

        @State private var isFileImporterPresented = false

        var body: some View {
            VStack {
                HStack {
                    Text("Files Import").font(.title3).fontWeight(.semibold)
                    Spacer()
                    SelectFilesButton
                }

                SelectedFiles
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }

        var SelectFilesButton: some View {
            Button(action: {
                isFileImporterPresented.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.person.crop")

                    Text("Select Files")
                }
                .font(.title3)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .cornerRadius(8)
                .shadow(radius: 2)
            }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    viewModel.updateSelectedFiles(urls)
                case .failure(let error):
                    print("Error selecting files: \(error)")
                }
            }
        }

        var SelectedFiles: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.importFiles.sorted(by: { $0.url.lastPathComponent < $1.url.lastPathComponent })) { importFile in
                        SelectedFileRow(file: importFile,
                                        domain: domain,
                                        viewModel: viewModel)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.windowBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                    }
                }
                .padding(5)
            }
        }

        private struct SelectedFileRow: View {
            @ObservedObject var file: ImportFile
            @ObservedObject var domain: DomainViewModel
            @ObservedObject var viewModel: BulkImportViewModel

            var body: some View {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)

                    Text(file.url.lastPathComponent)
                        .lineLimit(1)
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("(emails in file: \(file.emails?.count.formatted(.number) ?? "calculating..."))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 10)

                    // Make sure tagId is Int64? on ImportFile
                    Picker("Select Tag:", selection: $file.tagId) {
                        Text("None").tag(nil as Int64?)
                        ForEach(domain.tagsInfo) { tag in
                            Text(tag.name).tag(tag.id as Int64?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 300)
                    .cornerRadius(8)

                    Button(action: {
                        viewModel.removeImportFile(importFile: file)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
