//
//  ChatApp_iOSApp.swift
//  ChatApp_iOS
//
//  Created by Sawan.Kumar on 26/04/25.
//

import SwiftUI
import SwiftData

@main
struct ChatApp_iOSApp: App {
    @MainActor
    
    private var modelContainer: ModelContainer {
        ModelContextProvider.shared.container
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ChatListViewBuilder.make()
            }
        }
        .modelContainer(modelContainer)
    }
}
