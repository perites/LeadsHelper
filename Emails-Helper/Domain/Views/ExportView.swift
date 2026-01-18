//
//  DomainExportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 16/10/2025.
//

import SwiftUI

struct DomainExportView: View {
    @StateObject var viewModel: ExportViewModel
    @Binding var mode: Mode

    @State private var isExporting: Bool = false

    init(domain: DomainViewModel, mode: Binding<Mode>) {
        _viewModel = StateObject(
            wrappedValue: ExportViewModel(domain: domain)
        )
        _mode = mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HeaderView
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($viewModel.tagsRequests) { $tagRequest in
                        TagRequestView(
                            tagName: tagRequest.tagName,
                            availableLeadsCount: tagRequest.tagCount,
                            requestedAmount: $tagRequest.requestedAmount
                        )
                    }
                }
            }

            Divider()

            HStack {
                Text("Total:")
                Spacer()
                Button("Clear Requests") {
                    viewModel.clearAllRequests()

                }.font(.callout)
                Text(
                    "\(viewModel.tagsRequests.map { Int($0.requestedAmount ?? 0) }.reduce(0, +))"
                )
            }
            .padding(.horizontal, 5)
            .font(.title3)

            HStack {
                GoBackButtonView(mode: $mode, goBackMode: .info)
                Spacer()
                RepeatInput
                ExportButton
            }
            .padding(.top, 10)
        }
        .loadingOverlay(isShowing: $isExporting, text: "Exporting...")
    }

    private var HeaderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            FileNameInputView
            Toggle("Save each tag in separate file", isOn: $viewModel.isSeparateFiles)
                .toggleStyle(.checkbox)
            SaveFolderView
            Text(
                "Export Type: \(viewModel.domain.strExportType)"
            )
            .font(.caption)
            .foregroundColor(.gray)
        }
    }

    private var FileNameInputView: some View {
        HStack {
            if viewModel.isSeparateFiles {
                Text("Folder Name:")
                    .font(.body)

                TextField("Folder name", text: $viewModel.folderName)
                    .font(.body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()

            } else {
                EmptyView()
            }

            Text("File Name:")
                .font(.body)

            TextField("File name", text: $viewModel.fileName)
                .font(.body)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer()
            MergeTagsMenu
        }
    }

    private var MergeTagsMenu: some View {
        Menu {
            Text("Merge Tags (Click to Copy)")
            Divider()
            ForEach(viewModel.allMergeTags, id: \.self) { tag in
                Button {
                    copyToClipboard(tag)
                    ToastManager.shared
                        .show(
                            style: .info,
                            message: "Copied to clipboard: \(tag)",
                            duration: 1.5
                        )
                } label: {
                    Text(tag)
                    Image(systemName: "doc.on.doc")
                }
            }
        } label: {
            Image(systemName: "info.circle")
            Text("Merge Tags")
        }
        .buttonStyle(PlainButtonStyle())
        .padding(4)
        .contentShape(Rectangle())
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private var SaveFolderView: some View {
        if let folder = viewModel.domain.saveFolder {
            if !viewModel.isSeparateFiles {
                Text(
                    "Save Path Preview: \(folder.path)/\(viewModel.applyMergeTags(to: viewModel.fileName)).csv"
                )
                .font(.caption)
                .foregroundColor(.gray)
            } else {
                Text(
                    "Save Path Preview: \(folder.path)/\(viewModel.applyMergeTags(to: viewModel.folderName))/\(viewModel.applyMergeTags(to: viewModel.fileName)).csv"
                )
                .font(.caption)
                .foregroundColor(.gray)
            }

        } else {
            Text("Save Folder: Not set")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private struct TagRequestView: View {
        let tagName: String
        let availableLeadsCount: Int

        @Binding var requestedAmount: Int?

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(tagName)
                        .font(.body)
                        .bold()
                        .padding(.vertical, 5)
                    Text("Available Leads: \(availableLeadsCount)")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                Spacer()
                TextField("Amount", value: $requestedAmount, format: .number)
                    .font(.body)
                    .frame(width: 60)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.5)))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var RepeatInput: some View {
        HStack {
            Text("Repeat export for")
                .font(.body)
            TextField(
                "\(viewModel.repeatCount)",
                value: $viewModel.repeatCount,
                format: .number,
            )
            .font(.body)
            .frame(width: 40)
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
            .multilineTextAlignment(.center)
            .textFieldStyle(PlainTextFieldStyle())
            Text(viewModel.repeatCount == 1 ? "time" : "times")
                .font(.body)
                .padding(.trailing, 10)
        }.onChange(of: viewModel.repeatCount) { _, newValue in
            if newValue < 1 {
                viewModel.repeatCount = 1
            }
        }
    }

    private var ExportButton: some View {
        Button(
            action: {
                isExporting = true
                Task {
                    let result = await viewModel.exportLeads()
                    await MainActor.run {
                        isExporting = false

                        switch result {
                        case .noFolder:
                            ToastManager.shared.show(style: .warning, message: "Specify a folder to export to")
                        case .failure:
                            ToastManager.shared.show(style: .error, message: "Error while exporting leads")
                        case .success:
                            ToastManager.shared.show(style: .success, message: "Export Complete")
                            mode = .info
                            viewModel.domain.getLastExportRequest()
                            viewModel.domain.getTagsCount()
                        }
                    }
                }

            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.document")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                    Text("Finish Export")
                        .font(.title2)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.yellow.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
    }
}
