//
//  EmailsInputView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//


import SwiftUI



struct FilesImportView: View {
    @ObservedObject var viewModel: EmailsInputViewModel
    
    @State var selectedFiles: [URL] = []
    @State private var isFileImporterPresented = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Files Import").font(.title3).fontWeight(.semibold)
                Spacer()
                SelectFilesButton
            }
            
            SelectedFiles
            
            Text(
                "Leads from files: \(viewModel.emailsFromFiles?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
                
        }.onChange(of: selectedFiles) { _, newSelectedFiles in
            viewModel.getLeads(from: .files(newSelectedFiles))
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
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                Text("Select Files")
                    .font(.title3)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .cornerRadius(8)
            .shadow(radius: 2)
        }.fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                selectedFiles = Array(Set(selectedFiles + urls))
            case .failure(let error):
                print("Error selecting files: \(error)")
            }
        }
    }
        
    var SelectedFiles: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(selectedFiles, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        
                        Text(file.lastPathComponent)
                            .lineLimit(1)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            if let index = selectedFiles.firstIndex(of: file) {
                                selectedFiles.remove(at: index)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain) // No ugly button highlight
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2))
                    )
                }
            }
            .padding(5)
        }
    }
}

struct TextImportView: View {
    @ObservedObject var viewModel: EmailsInputViewModel
    
    @State var textInput: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Text Import")
                Spacer()
            }
            .padding(.vertical, 5)
            .font(.title3)
            .fontWeight(.semibold)
            
            TextEditor(text: $textInput)
                .font(.body)
                .padding()
                .frame(minHeight: 150) // Adjust height like a textarea
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.4)))
            
            Text(
                "Leads from files: \(viewModel.emailsFromText?.count.formatted(.number) ?? "Calculating...")"
            )
            .padding()
            .font(.body)
            
        }.onChange(of: textInput) { _, newText in
            viewModel.getLeads(from: .text(newText))
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
