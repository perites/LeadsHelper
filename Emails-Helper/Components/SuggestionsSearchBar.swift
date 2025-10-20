//
//  SuggestionsSearchBar.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

struct SearchBarWithSuggestions: View {
    @Binding var query: String
    
    @State private var suggestions: [String] = []
    
    let allItems: [String] // Full list to search from
    
    var body: some View {
        TextField("Search...", text: $query)
            .onChange(of: query) {
                updateSuggestions()
            }
            .popover(isPresented: Binding(
                get: { !query.isEmpty &&
                    !allItems.contains(query) &&
                    !suggestions.isEmpty
                },
                set: { _ in }
            ), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(suggestions.prefix(5), id: \.self) { item in
                        Text(item)
                            .font(.body)
                            .onTapGesture {
                                query = item
                            }
                    }
                }
                .frame(minWidth: 50)
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
            }
    }
    
    func updateSuggestions() {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        suggestions = allItems.filter { $0.lowercased().contains(query.lowercased()) }
            .prefix(5).map { $0 }
    }
}
   
