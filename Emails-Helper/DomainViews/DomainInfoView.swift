//
//  DomainInfoView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 16/10/2025.
//

import SwiftUI

struct DomainInfoView: View {
    @Binding var mode: Mode
    @Binding var domain: Domain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DomainHeader
            Divider()
            LeadsUsageBars
            Divider()
            FooterButtons
        }
    }

    private var DomainHeader: some View {
        HStack {
            Text(domain.name)
                .font(.title)
                .fontWeight(.semibold)
            Spacer()
            
            Button(action: {
                mode = .exportLeads
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.document")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                    Text("Export")
                        .font(.title3)
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
        
    }

    private var LeadsUsageBars: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(domain.importNames, id: \.self) { importName in
                    VStack(alignment: .leading) {
                        Text(importName)
                            .font(.body)
                            .padding(.horizontal, 4)

                        ProgressBar(
                            active: domain.leadsCount(in: importName, isActive: true),
                            total: domain.maxLeads
                        )
                        .frame(height: 20)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)
        }
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

        var body: some View {
            GeometryReader { geo in
                let usedWidth = total > 0 ? geo.size.width * min(CGFloat(active) / CGFloat(total), 1.0) : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geo.size.width)

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


