//
//  NotificationView.swift
//  PiggyFlow
//
//  Created by Vasanth on 28/10/25.
//

import SwiftUI

struct NotificationView: View {
    var body: some View {
        VStack{
            Text("No Notification")
                .font(.system(size: 18, weight: .ultraLight, design: .serif))
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NotificationView()
}
