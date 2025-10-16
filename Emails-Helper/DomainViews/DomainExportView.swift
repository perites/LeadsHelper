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
            
            
            
            
            // File Name
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("File Name:")
                        .font(.headline)
                    TextField("Enter file name", text: $fileName)
                        .font(.headline)
                }
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

            // Import Rows
            Text("Import Names")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(domain.importNames, id: \.self) { importName in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(importName)
                                    .font(.headline)
                                    .bold()
                                    .padding(.vertical, 5)
                                Text("Available Leads: \(domain.leadsCount(in: importName, isActive: true))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            TextField("Amount", text: Binding(
                                get: { requestData[importName] ?? "" },
                                set: { newValue in
                                    requestData[importName] = newValue.filter { $0.isNumber }
                                }
                            ))
                            .font(.system(size: 14))
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
                Divider()
                HStack {
                    Text("Total:")
                        .font(.headline)
                    Spacer()
                    Text("\(requestData.values.compactMap { Int($0) }.reduce(0, +))")
                        .font(.headline)
                }.padding(.horizontal, 5)
            }

            // Action Buttons
            HStack {
                
                HStack {
                        Button(action: {
                            mode = .view
                        }) {
                            Image(systemName: "chevron.left")
//                                .resizable()
//                                .frame(width: 12, height: 15)
                                .foregroundColor(.secondary)
                                .padding(.vertical,5)
                            Text("Back")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                    }
                Spacer()
                
                ActionButton(
                    title: "Finish Export",
                    systemImage: "folder.circle",
                    color: .secondary
                ) {
                    exportLeads()
                }
                Spacer()
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    private struct ActionButton: View {
        let title: String
        let systemImage: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(color)
                .cornerRadius(8)
                .shadow(radius: 2)
                .frame(width: 400)
            }
            .buttonStyle(PlainButtonStyle())
        }
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
