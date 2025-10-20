//
//  Toasts.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 18/10/2025.
//

import Combine
import SwiftUI
// MARK: - Toast Manager (Queue)

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published private(set) var toasts: [Toast] = []

    private init() {}

    func show(style: ToastStyle, message: String, duration: Double = 6) {
        let toast = Toast(style: style, message: message, duration: duration)
        toasts.append(toast)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.dismiss(toast)
        }
    }

    func dismiss(_ toast: Toast) {
        withAnimation {
            self.toasts.removeAll { $0.id == toast.id }
        }
    }

    func dismissAll() {
        withAnimation {
            self.toasts.removeAll()
        }
    }
}
