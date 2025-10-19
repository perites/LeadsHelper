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
    @State private var folderName: String = ""

    @State private var requestData: [String: String] = [:]

    @State private var isSeparateFiles: Bool = false

    @State var mergeTags: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeaderView
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
        .onAppear {
            mergeTags = [
                "%d-name%": domain.name,
                "%d-abrr%": domain.abbreviation,
                "%day%": String(Calendar.current.component(.day, from: Date())),
                "%month%": String(Calendar.current.component(.month, from: Date())),
                "%t-all%": requestData2String(requestData: requestData),
                "%t-name%": requestData.keys.first ?? "",
                "%t-amount%": requestData[requestData.keys.first ?? ""] ?? ""
            ]
        }
        .onChange(of: requestData) {
            mergeTags["%t-all%"] = requestData2String(requestData: requestData)
            mergeTags["%t-name%"] = requestData.keys.first ?? ""
            mergeTags["%t-amount%"] = requestData[requestData.keys.first ?? ""] ?? ""
        }
        .padding()
    }

    private func requestData2String(requestData: [String: String]) -> String {
        var result: [String] = []
        let keys = Array(requestData.keys).sorted()
        for key in keys {
            let value = requestData[key] ?? ""
            if value != "" && value != "0" {
                result.append("\(key)_\(value)")
            }
        }
        return result.joined(separator: "-")
    }

    private var HeaderView: some View {
        VStack(alignment: .leading, spacing: 5) {
            FileNameInputView

            SaveFolderView

            Toggle("Save each type in separate file", isOn: $isSeparateFiles)
                .toggleStyle(.checkbox)
        }
    }

    private var FileNameInputView: some View {
        HStack {
            if !isSeparateFiles {
                Text("File Name:")
                    .font(.title3)
                SearchBarWithSuggestions(
                    query: $fileName,
                    allItems: Array(mergeTags.keys)
                ).font(.title3)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

            } else {
                Text("Folder Name:")
                    .font(.title3)
                SearchBarWithSuggestions(
                    query: $folderName,
                    allItems: Array(mergeTags.keys)
                )
                .font(.title3)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()

                Text("File Name:")
                    .font(.title3)
                SearchBarWithSuggestions(
                    query: $fileName,
                    allItems: Array(mergeTags.keys)
                ).font(.title3)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }

    private var SaveFolderView: some View {
        if let folder = domain.saveFolder {
            if !isSeparateFiles {
                Text(
                    "Save Path: \(folder.path)/\(applyMergeTags(to: fileName)).csv"
                )
                .font(.caption)
                .foregroundColor(.gray)
            } else {
                Text("Save Path e.g: \(folder.path)/\(applyMergeTags(to: folderName))/\(applyMergeTags(to: fileName)).csv etc.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

        } else {
            Text("Save Folder: Not set")
                .font(.caption)
                .foregroundColor(.red)
        }
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
                .textFieldStyle(PlainTextFieldStyle())
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

    func applyMergeTags(to template: String) -> String {
        var result = template
        for (key, value) in mergeTags {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }

    private func exportLeads() {
        guard let folder = domain.saveFolder else {
            print("Choose a save folder first")
            return
        }
        
        let results = domain.getLeadsFromRequest(requestData: requestData)
        if !isSeparateFiles {
            let emails = results.values.flatMap { $0 }
            let content = formatEmails(for: emails)
            let fileURL = folder.appendingPathComponent("\(applyMergeTags(to: fileName)).csv")
            saveFile(content: content, path: fileURL)
        } else {
            for (importName, emails) in results {
                mergeTags["%t-name%"] = importName
                mergeTags["%t-amount%"] = String(emails.count)
                
                let content = formatEmails(for: emails)
                let subfolder = folder.appendingPathComponent(
                    "\(applyMergeTags(to: folderName))/"
                )
                ensureFolderExists(at: subfolder)
                let fileURL = subfolder.appendingPathComponent("\(applyMergeTags(to: fileName)).csv")
                saveFile(content: content, path: fileURL)
            }
        }

        mode = .view
    }
    
    func ensureFolderExists(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }


    private func formatEmails(for emails: [String]) -> String {
        switch domain.exportType {
        case 1:
            var strEmails = ""
            for email in emails {
                let domainAbbrivation = domain.abbreviation

                let row = "\(email), \(email.replacingOccurrences(of: "@", with: domainAbbrivation))\n"
                strEmails += row
            }

            let content = "Email Address,Subscriber Key\n" + strEmails
            return content

        case 2:
            var strEmails = ""
            for email in emails {
                let domainName = domain.name
                let domainAbbrivation = domain.abbreviation

                let row = "\(email), \(email + domainAbbrivation), \(domainName)\n"
                strEmails += row
            }

            let content = "email,customer_id,domain\n" + strEmails
            return content

        default:
            let strEmails = emails.joined(separator: "\n")
            let content = "Email\n" + strEmails
            return content
        }
    }

    private func saveFile(content: String, path: URL) {
        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            print("File saved at: \(path.path)")
        } catch {
            print("Failed to save file: \(error)")
        }

        
    }
}

struct GoBackButtonView: View {
    @Binding var mode: Mode

    var body: some View {
        Button(action: {
            mode = .view
        }) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .padding(.vertical, 5)
                Text("Back")
                    .font(.callout)
            }.foregroundColor(.secondary)
        }
    }
}
