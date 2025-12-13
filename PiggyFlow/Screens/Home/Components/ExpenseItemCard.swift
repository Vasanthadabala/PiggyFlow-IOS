//
//  ExpenseItem.swift
//  PiggyFlow
//
//  Created by Vasanth on 11/12/25.
//

import SwiftUI

struct ExpenseItemCard: View {
    let emoji: String
    let title: String
    let date: Date
    let amount: String
    let color: Color
    let isIncome: Bool
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            // Left side: Icon + Title
            HStack(spacing: 12) {
                Text(emoji.isEmpty ? title.prefix(1).uppercased() : emoji)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                    Text(formattedDate)
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Right side: Price
            HStack(spacing: 4) {
                if isIncome {
                    Text("+₹\(amount)")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                } else {
                    Text("-₹\(amount)")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                }                
            }
            .foregroundColor(color)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
        )
    }
}
