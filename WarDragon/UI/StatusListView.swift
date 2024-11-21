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
       ScrollView {
           LazyVStack(spacing: 16) {
               ForEach(statusViewModel.statusMessages) { message in
                   StatusMessageView(message: message)
               }
           }
           .padding()
       }
       .navigationTitle("System Status")
       .background(Color.black)
   }
}
