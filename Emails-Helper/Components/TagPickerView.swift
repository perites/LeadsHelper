//
//  TagPickerView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 11/11/2025.
//

import SwiftUI

enum TagPickerMode {
    case allowAll(Binding<Bool>)
    case regular
}

struct TagPickerView: View {
    @ObservedObject var domain: DomainViewModel
    @Binding var pickedTagId: Int64?
    
    let mode: TagPickerMode
    
    var body: some View {
        switch mode {
            case .allowAll(let useAllTagsBinding):
                VStack(alignment: .leading) {
                    if !useAllTagsBinding.wrappedValue {
                        tagPicker
                    }
                
                    Toggle("Select all tags", isOn: useAllTagsBinding.animation())
                        .toggleStyle(.checkbox)
                }
            case .regular:
                tagPicker
        }
    }
    
    var tagPicker: some View {
        Picker("Select Tag:", selection: $pickedTagId) {
            Text("Select tag").tag(Int64?.none)
            ForEach(domain.tagsInfo) { tag in
                Text(tag.name).tag(tag.id as Int64?)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(maxWidth: 300)
    }
}
