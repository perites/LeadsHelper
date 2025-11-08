//
//  DomainInfoView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 16/10/2025.
//

import SwiftUI

struct DomainInfoView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var mode: Mode

    // 💡 State to manage renaming
    @State private var renamingTagInfo: TagInfo? = nil
    @State private var newTagName: String = ""
    @FocusState private var focusedTagId: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DomainHeader
            Divider()
            LeadsUsageBars
//            Divider()
//            FooterButtons
        }
    }

    private var DomainHeader: some View {
        HStack(alignment: .center) {
            HeaderDomainName
            Spacer()
            Group {
                ExportButton
                BulkActionMenu
            }
            .font(.title3)
            
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .shadow(radius: 2)
            .buttonStyle(PlainButtonStyle())
            
            
        }
    }

    private var HeaderDomainName: some View {
        Text(domain.name)
            .font(.title)
            .fontWeight(.semibold)
    }

    private var ExportButton: some View {
        Button(action: { mode = .exportLeads }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.document")
                    .foregroundColor(.yellow.opacity(1))
                Text("Export")
            }
            .padding(7)
            .contentShape(Rectangle())        // ensures full tap area

        }
        
    }

    private var BulkActionMenu: some View {
        Menu {
            Group {
                menuButton("Bulk Import", icon: "person.2.badge.plus.fill", tint: .green, action: {
                    mode = .importLeads
                })

                menuButton("Bulk Exclude", icon: "person.2.slash.fill", action: {
                    ToastManager.shared.show(style: .warning, message: "Bulk Exclude not implemented yet")

                })

                menuButton("Bulk Download", icon: "arrow.down.square", action: {
                    ToastManager.shared.show(style: .warning, message: "Bulk dwoload not implemented yet")

                })
            }
            .labelStyle(.titleAndIcon)
        } label: {
            HStack{
                Image(systemName: "person.2.fill")
                    .padding(8)
            }
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
    }

    private var LeadsUsageBars: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(domain.tagsInfo) { tagInfo in
                    tagCard(tagInfo)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    func performRename() {
        guard !newTagName.isEmpty, newTagName != renamingTagInfo!.name else {
            renamingTagInfo = nil
            focusedTagId = nil
            return
        }

        // 1. Update the database
        TagsTable.renameTag(id: renamingTagInfo!.id, to: newTagName)

        // 2. Refresh the domain data using the method you provided
        domain.updateTagsInfo() // 💡 Using the provided method name

        // 3. Exit renaming mode

        // Show confirmation toast
        ToastManager.shared.show(style: .success, message: "Tag renamed to '\(newTagName)'")
        
        renamingTagInfo = nil
        focusedTagId = nil
        newTagName = ""
    }

    @ViewBuilder
    private func tagCard(_ tagInfo: TagInfo) -> some View {
        let isRenaming = renamingTagInfo?.name == tagInfo.name

        // Function to perform the rename logic

        // 💡 The Vstack is the single top-level view, no 'return' needed.
        VStack(alignment: .leading) {
            HStack {
                if isRenaming {
                    // TextField when renaming
                    TextField(
                        "New Tag Name",
                        text: $newTagName,
                        onCommit: performRename
                    )
                    .textFieldStyle(.roundedBorder)
//                    .padding(.horizontal, 4)
                    .onAppear {
                        newTagName = tagInfo.name // Pre-fill with current name
                    }
                    .focused($focusedTagId, equals: tagInfo.id)
                } else {
                    // Text when not renaming
                    Text(tagInfo.name)
                        .padding(.horizontal, 4)
                }

                Spacer()

                Menu {
                    Group {
                        menuButton("Import", icon: "person.fill.badge.plus", tint: .green, action: {
                            mode = .importLeads
                        })

                        menuButton("Imports History", icon: "clock.arrow.circlepath", action: {
                            ToastManager.shared.show(style: .warning, message: "History not implemented yet")

                        })

                        menuButton("Exclude", icon: "minus.circle", action: {
                            ToastManager.shared.show(style: .warning, message: "Exlude not implemented yet")

                        })

                        menuButton("Download", icon: "arrow.down.circle", action: {
                            ToastManager.shared.show(style: .warning, message: "Dowload not implemented yet")

                        })

                        Divider()

                        // Action to start the rename
                        menuButton("Rename", icon: "pencil", action: {
                            renamingTagInfo = tagInfo
                            focusedTagId = tagInfo.id
                        })

                        menuButton("Delete", icon: "trash", role: .destructive, tint: .red, action: { // 👈 MODIFIED
                            ToastManager.shared.show(style: .warning, message: "Delte not implemented yet")

                        })
                    }
                    .labelStyle(.titleAndIcon)
                } label: {
                    Image(systemName: "tag")
                        .padding(4)
//                        .font(.body)
//                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                        .shadow(radius: 2)
//                        .rotationEffect(.degrees(90))
//                        .foregroundColor(.gray)

//                        .frame(width: 24, height: 24)
//                        .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .buttonStyle(PlainButtonStyle())
            }

            ProgressBar(active: tagInfo.activeEmailsCount, total: domain.maxLeads)
                .frame(height: 20)
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    /// Creates a button for use inside a Menu
    private func menuButton(_ title: String, icon: String, role: ButtonRole? = nil, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon).font(.body)
        }
        .tint(tint)
    }

    private var FooterButtons: some View {
        HStack {
            ActionButton(
                title: "Import",
                systemImage: "person.fill.badge.plus",
                color: .green.opacity(0.3)
            ) {
                mode = .importLeads
            }
            Spacer()
            ActionButton(
                title: "Exclude",
                systemImage: "person.fill.badge.minus",
                color: .yellow.opacity(0.3)
            ) {
                mode = .exportLeads
            }
            Spacer()
            ActionButton(
                title: "Delete",
                systemImage: "person.slash.fill",
                color: .red.opacity(0.3)
            ) {
                mode = .exportLeads
            }
        }
    }

    private struct ProgressBar: View {
        let active: Int
        let total: Int

        var barColor: Color {
            guard total > 0 else { return .teal.opacity(0.8) }
            if active >= total { return .indigo.opacity(0.6) }
            let ratio = Double(active) / Double(total)
            return ratio < 0.20 ? .orange.opacity(0.8) : .teal.opacity(0.8)
        }

        var borderColor: Color {
            active <= 100 ? .red.opacity(0.8) : .clear
        }

        var body: some View {
            GeometryReader { geo in
                let usedWidth = total > 0 ? geo.size.width * min(CGFloat(active) / CGFloat(total), 1.0) : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geo.size.width)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(borderColor, lineWidth: 2)
                        )

                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor)
                        .frame(width: usedWidth)

                    HStack {
                        Text("\(active)")
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                    }
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.callout)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
