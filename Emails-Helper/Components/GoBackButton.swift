//
//  GoBackButton.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

struct GoBackButtonView: View {
    @Binding var mode: Mode
    let goBackMode: Mode

    var body: some View {
        Button(action: {
            mode = goBackMode
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
