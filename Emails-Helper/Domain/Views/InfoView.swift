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
    @State private var editedTagInfo: TagInfo? = nil
    @State private var newTagName: String = ""
    @State private var newIdealAmount: Int = 0
    @State private var isShowingDeleteAlert: Bool = false

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
                Text("Create Export")
            }
            .padding(7)
            .contentShape(Rectangle())
        }
    }

    private var BulkActionMenu: some View {
        Menu {
            Group {
                menuButton("Bulk Import", icon: "person.2.badge.plus.fill", tint: .green, action: {
//                    mode = .importLeads
                    ToastManager.shared.show(style: .warning, message: "Bulk IMport not implemented yet")

                })

                menuButton("Bulk Exclude", icon: "person.2.slash.fill", action: {
                    ToastManager.shared.show(style: .warning, message: "Bulk Exclude not implemented yet")

                })

                menuButton("Bulk Download", icon: "arrow.down.square", action: {
                    ToastManager.shared.show(style: .warning, message: "Bulk dwoload not implemented yet")

                })

                Divider()

                menuButton(
                    "Add new tag",
                    icon: "plus.circle",
                    action: {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
                        let dateString = formatter.string(from: Date())
                        let newName = "New Tag \(dateString)"
                        let createdTagId = TagsTable
                            .addTag(
                                newName: newName,
                                newDomainId: domain.id
                            )

                        guard let createdTagId else {
                            ToastManager.shared
                                .show(
                                    style: .error,
                                    message: "Tag creation failed"
                                )
                            return
                        }
                        ToastManager.shared.show(style: .success, message: "Tag created successfully")
                        domain
                            .addTagInfo(
                                tagId: createdTagId,
                                name: newName,
                                idealAmount: 0
                            )
                        editedTagInfo = domain.tagsInfo.first { $0.id == createdTagId }
                        focusedTagId = createdTagId
                    }
                )
            }
            .labelStyle(.titleAndIcon)
        } label: {
            HStack {
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

    @ViewBuilder
    private func tagCard(_ tagInfo: TagInfo) -> some View {
        let isEdited = editedTagInfo?.name == tagInfo.name

        // Function to perform the rename logic

        // 💡 The Vstack is the single top-level view, no 'return' needed.
        VStack(alignment: .leading) {
            if isEdited {
                EditedTagCardElements(tagInfo)
            } else {
                TagCardElements(tagInfo)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func TagCardElements(_ tagInfo: TagInfo) -> some View {
        HStack {
            Text(tagInfo.name)
                .padding(.horizontal, 4)

            Spacer()

            Menu {
                Group {
                    menuButton("Import", icon: "person.fill.badge.plus", tint: .green, action: {
                        mode = .importLeads(tagInfo.id)
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
                    menuButton("Edit", icon: "pencil", action: {
                        editedTagInfo = tagInfo
                        focusedTagId = tagInfo.id
                    })

                    menuButton(
                        "Delete",
                        icon: "trash",
                        role: .destructive,
                        tint: .red,
                        action: {
                            isShowingDeleteAlert = true
                        }
                    )
                }
                .labelStyle(.titleAndIcon)
            } label: {
                Image(systemName: "tag")
                    .padding(4)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            .menuIndicator(.hidden)
            .buttonStyle(PlainButtonStyle())
        }.alert("Delete Tag?", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .none) {
                domain.deleteTag(tagId: tagInfo.id)

                ToastManager.shared
                    .show(
                        style: .info,
                        message: "Tag \(tagInfo.name) deleted"
                    )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete tag \(tagInfo.name)?")
        }

        ProgressBar(tagInfo: tagInfo)
            .frame(height: 20)
    }

    @ViewBuilder
    private func EditedTagCardElements(_ tagInfo: TagInfo) -> some View {
        VStack {
            // TextField when renaming
            TextField(
                "New Tag Name",
                text: $newTagName
            )
            .textFieldStyle(.roundedBorder)
            //                    .padding(.horizontal, 4)
            .onAppear {
                newTagName = tagInfo.name // Pre-fill with current name
            }
            .focused($focusedTagId, equals: tagInfo.id)

            TextField(
                "Ideal Leads Amount",
                value: $newIdealAmount,
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            //                    .padding(.horizontal, 4)
            .onAppear {
                newIdealAmount = tagInfo.idealAmount // Pre-fill with current name
            }

            Button("Save", action: {
                editedTagInfo = nil
                focusedTagId = nil
                guard !newTagName.isEmpty else { return }
                domain.updateTagInfo(tagId: tagInfo.id, type: .text(newTagName, newIdealAmount))
                ToastManager.shared.show(style: .info, message: "Tag saved")
            })
        }
    }

    /// Creates a button for use inside a Menu
    private func menuButton(_ title: String, icon: String, role: ButtonRole? = nil, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon).font(.body)
        }
        .tint(tint)
    }

    private struct ProgressBar: View {
        let tagInfo: TagInfo

        enum BarColor {
            static let allGood = Color.green.opacity(0.8)
            static let alright = Color.blue.opacity(0.6)
            static let notSoGood = Color.orange.opacity(0.8)
            static let bad = Color.red.opacity(0.8)
        }

        enum BarColorScheme {
            static let `default` = (barColor: BarColor.alright, borderColor: Color.clear)
            static let great = (barColor: BarColor.allGood, borderColor: Color.clear)
            static let warning = (barColor: BarColor.notSoGood, borderColor: Color.clear)
            static let critical = (barColor: BarColor.bad, borderColor: BarColor.bad)
        }

        var colorScheme: (barColor: Color, borderColor: Color) {
            guard tagInfo.idealAmount > 0 else {
                return BarColorScheme.default
            }

            let ratio = Double(tagInfo.availableLeadsCount) / Double(
                tagInfo.idealAmount
            )

            switch ratio {
            case 0..<0.2:
                return BarColorScheme.critical
            case 0.2..<0.4:
                return BarColorScheme.warning
            case 0.4..<1:
                return BarColorScheme.default
            case 1...:
                return BarColorScheme.great
            default:
                return BarColorScheme.default
            }
        }

        var body: some View {
            GeometryReader { geo in
                let usedWidth = tagInfo.idealAmount > 0 ? geo.size.width * min(
                    CGFloat(tagInfo.activeLeadsCount) / CGFloat(
                        tagInfo.idealAmount
                    ),
                    1.0
                ) : 0

                let unavailableWidth = tagInfo.idealAmount > 0 ? geo.size.width * min(
                    CGFloat(tagInfo.unavailableLeadsCount) / CGFloat(tagInfo.idealAmount),
                    1.0
                ) : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geo.size.width)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(colorScheme.borderColor, lineWidth: 2)
                        )

                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme.barColor)
                        .frame(width: usedWidth)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.8))
                        .frame(width: unavailableWidth)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    HStack {
                        Text("\(tagInfo.availableLeadsCount)")
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
