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
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List(statusViewModel.statusMessages) { message in
                    StatusMessageView(message: message)
                }
                .listStyle(.plain) // Change to plain style for cleaner look
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
                // Add vertical alignment when there are few items
                .frame(minHeight: geometry.size.height, alignment: .center)
                .onChange(of: statusViewModel.statusMessages.count) { _, _ in
                    if let latest = statusViewModel.statusMessages.last {
                        withAnimation {
                            proxy.scrollTo(latest.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("System Status")
    }
}
