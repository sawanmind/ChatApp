//
//  ChatBot.swift
//  ChatApp_iOS
//
//  Created by Sawan.Kumar on 26/04/25.
//

import Foundation
import SwiftUI

struct ChatBot: Identifiable, Equatable {
    var id: String
    let botName: String
    let botType: BotType
    var lastMessage: String?
    let unreadCount: Int
    let avatarImage: String
    var timestamp: Date?
    
    // Implement Equatable
    static func == (lhs: ChatBot, rhs: ChatBot) -> Bool {
        lhs.botType == rhs.botType
    }
}

enum BotType: String, Equatable {
    case support = "SupportBot"
    case sales = "SalesBot"
    case faq = "FAQBot"
    
    var color: Color {
        switch self {
        case .support: return .blue
        case .sales: return .green
        case .faq: return .orange
        }
    }
}
