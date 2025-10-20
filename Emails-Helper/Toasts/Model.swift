//
//  Models.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 20/10/2025.
//

import SwiftUI

// MARK: - Toast Model

struct Toast: Equatable, Identifiable {
    let id = UUID()
    var style: ToastStyle
    var message: String
    var duration: Double
    var width: CGFloat = 300
}

enum ToastStyle {
    case error, warning, success, info

    var themeColor: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .success: return .green
        }
    }

    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}
