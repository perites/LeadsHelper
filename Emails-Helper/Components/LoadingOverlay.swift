//
//  LoadingView.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

struct LoadingOverlay: ViewModifier {
    @Binding var isShowing: Bool
    var text: String = "Loading..."

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isShowing ? 5 : 0)
                .disabled(isShowing)

            if isShowing {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                HStack(spacing: 5) {
                    Text(text)
                        .font(.body)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                }
                .padding()
                .cornerRadius(12)
            }
        }
        .animation(.easeInOut, value: isShowing)
    }
}

extension View {
    func loadingOverlay(isShowing: Binding<Bool>, text: String = "Loading...") -> some View {
        modifier(LoadingOverlay(isShowing: isShowing, text: text))
    }
}
