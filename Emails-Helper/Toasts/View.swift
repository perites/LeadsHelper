//
//  View.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

struct ToastView: View {
    var toast: Toast
    var onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.iconName)
                .foregroundColor(toast.style.themeColor)
            Text(toast.message)
                .foregroundColor(.primary)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.primary)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: toast.width)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(toast.style.themeColor, lineWidth: 2)
        )
        .cornerRadius(10)
        .shadow(radius: 5)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    // Dismiss if dragged far enough horizontally
                    if abs(value.translation.width) > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(), value: dragOffset)
    }
}

struct ToastContainerView<Content: View>: View {
    @ObservedObject private var manager = ToastManager.shared
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
            Spacer()
            VStack(spacing: 10) {
                ForEach(manager.toasts.reversed()) { toast in
                    ToastView(toast: toast) {
                        manager.dismiss(toast)
                    }
                    .transition(
                        .asymmetric(
                            insertion:
                            .move(edge: .leading)
                                .combined(with: .opacity),
                            removal:
                            .move(edge: .leading)
                                .combined(with: .opacity)
                        )
                    )
                }
            }
            .padding(.bottom, 20)
            .padding(.leading, 20)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomLeading
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.toasts)
        }
    }
}
