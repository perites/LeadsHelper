//
//  DomainExportView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 16/10/2025.
//

import SwiftUI

struct DomainExportView: View {
    @Binding var mode: Mode
    @Binding var domain: Domain

    @State private var fileName: String = ""
    @State private var requestData: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                FileNameInputView(fileName: $fileName)
                if let folder = domain.saveFolder {
                    Text("Save Folder: \(folder.path)")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Save Folder: Not set")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(domain.importNames, id: \.self) { importName in
                        ImportNameInputView(
                            importName: importName,
                            availableLeadsCount: domain.leadsCount(in: importName, isActive: true),
                            requestData: $requestData
                        )
                    }
                }
            }
            Divider()

            HStack {
                Text("Total:")
                Spacer()
                Text("\(requestData.values.compactMap { Int($0) }.reduce(0, +))")
            }
            .padding(.horizontal, 5)
            .font(.title3)

            HStack {
                GoBackButtonView(mode: $mode)
                Spacer()
                ExportButton
            }
            .padding(.top, 10)
        }
        .padding()
    }

    private struct ImportNameInputView: View {
        let importName: String
        let availableLeadsCount: Int

        @Binding var requestData: [String: String]

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(importName)
                        .font(.body)
                        .bold()
                        .padding(.vertical, 5)
                    Text("Available Leads: \(availableLeadsCount)")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                Spacer()
                TextField("Amount", text: Binding(
                    get: { requestData[importName] ?? "" },
                    set: { newValue in
                        requestData[importName] = newValue.filter { $0.isNumber }
                    }
                ))
                .font(.body)
                .frame(width: 60)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.5)))
                .multilineTextAlignment(.center)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var ExportButton: some View {
        Button(action: {
            exportLeads()
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
            .background(.blue.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func exportLeads() {
        print(requestData)
        let leads = domain.getLeadsFromRequest(requestData: requestData)
        saveFile(content: leads, fileName: fileName)
        mode = .view
    }

    private func saveFile(content: String, fileName: String) {
        guard let folder = domain.saveFolder else {
            print("Choose a save folder first")
            return
        }
        let fileURL = folder.appendingPathComponent("\(fileName).csv")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("File saved at: \(fileURL.path)")
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}




struct FileNameInputView: View {
    @Binding var fileName: String

    var body: some View {
        HStack {
            Text("File Name:")
                .font(.title3)
            TextField("Enter file name", text: $fileName)
                .font(.title3)
        }
    }
}

struct GoBackButtonView: View {
    @Binding var mode: Mode

    var body: some View {
        Button(action: {
            mode = .view
        }) {
            HStack (spacing: 3) {
                Image(systemName: "chevron.left")
                    .padding(.vertical, 5)
                Text("Back")
                    .font(.callout)
            }.foregroundColor(.secondary)
        }
    }
}


