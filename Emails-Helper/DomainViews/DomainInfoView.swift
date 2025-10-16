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
        VStack(alignment: .leading, spacing: 20) {
            DomainHeaderView(domain: $domain, mode: $mode)
            
            // MARK: Overall Progress

            OverallProgressView(domain: domain, mode: $mode)
            
            Divider()
            
            HStack {
                ScrollView(.vertical) {
                    ImportNamesListView(domain: domain)
                }
                
                Spacer()
                
                Button(action: { mode = .exportLeads }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 45, height: 45)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.secondary)
                    .clipShape(Circle())
                    .shadow(radius: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(16)
                
                Spacer()
            }
        }
    }

    // MARK: Header View

    private struct DomainHeaderView: View {
        @Binding var domain: Domain
        @Binding var mode: Mode
        
        var body: some View {
            HStack {
                Text(domain.name)
                Text("(\(domain.abbreviation))")
                Spacer()
                Button(action: { mode = .edit }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 5)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .font(.largeTitle)
            .bold()
            .padding(.bottom, 15)
        }
    }
    
    // MARK: Overall Progress

    private struct OverallProgressView: View {
        let domain: Domain
        @Binding var mode: Mode
        
        var body: some View {
            HStack {
                Text("All Contacts")
                    .font(.system(size: 18, weight: .bold))
                
                ProgressBar(
                    active: domain.leadsCount(isActive: true),
                    total: domain.leadsCount(),
                )
                .frame(height: 24)
                
                ActionButton(
                    title: "Import",
                    systemImage: "person.fill.badge.plus",
                    color: .secondary
                ) {
                    mode = .importLeads
                }
            }
        }
    }
    
    // MARK: Action Button

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
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(color)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: Import Names List

    private struct ImportNamesListView: View {
        let domain: Domain
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(domain.importNames, id: \.self) { importName in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(importName)
                            .font(.system(size: 15))
                            .padding(.bottom, 4)
                        
                        ProgressBar(
                            active: domain.leadsCount(in: importName, isActive: true),
                            total: domain.maxLeads
                        )
                        .frame(height: 20)
                    }
                }
            }
            .frame(width: 400)
        }
    }
    
    // MARK: Progress Bar

    private struct ProgressBar: View {
        let active: Int
        let total: Int
        
        var barColor: Color {
            guard total > 0 else { return .green.opacity(0.8) }
            if active >= total { return .blue }
            let ratio = Double(active) / Double(total)
            return ratio < 0.10 ? .orange : .green.opacity(0.8)
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
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                    }
                }
            }
        }
    }
}
