//
//  StatusListView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI

struct StatusListView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            List(statusViewModel.statusMessages) { message in
                StatusMessageView(message: message)
            }
            .onChange(of: statusViewModel.statusMessages.count) { _, _ in
                if let latest = statusViewModel.statusMessages.last {
                    withAnimation {
                        proxy.scrollTo(latest.id, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("System Status")
    }
}
