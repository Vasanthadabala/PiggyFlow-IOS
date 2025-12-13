//
//  TransactionDetailView.swift
//  PiggyFlow
//
//  Created by Vasanth on 27/10/25.
//

import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    
    @State private var showEditSheet = false
    
    let item: HomeView.TransactionItem

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack {
                HStack {
                    
                    if item.type == "Expense" {
                        Text(item.emoji)
                            .font(.system(size: 24))
                        
                        Spacer().frame(width: 24)
                        
                        Text(item.title)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                    }
                    
                    
                    Spacer().frame(width: 24)
                    
                    if item.type == "Income" {
                        Text(item.emoji)
                            .font(.system(size: 24))
                        
                        Spacer().frame(width: 12)
                        
                        Text(item.type)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                        
                        Spacer().frame(width: 8)
                        
                        Text("(\(item.title))")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                    
                }
                
                Spacer().frame(height: 48)
                
                HStack {
                    Text("Type: ")
                        .font(.headline)
                    Spacer()
                    Text(item.color == .green ? "Income" : "Expense")
                        .font(.body)
                }
                
                Spacer().frame(height: 48)
                
                HStack {
                    Text("Amount: ")
                        .font(.headline)
                    Spacer()
                    Text(item.amount)
                        .font(.body)
                }
                
                Spacer().frame(height: 48)
                
                HStack {
                    Text("Date: ")
                        .font(.headline)
                    Spacer()
                    Text(formattedDate(item.date))
                        .font(.body)
                }
                
                Spacer().frame(height: 48)
                
                HStack {
                    Text("Note: ")
                        .font(.headline)
                    Spacer()
                    Text(item.note)
                        .font(.body)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            
            Spacer()
            
            Button {
                showEditSheet = true
            } label: {
                Text("Edit")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 18, weight: .medium, design: .serif))
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .foregroundColor(.white)
            .background(Color.green.gradient)
            .cornerRadius(12)
        }
        .padding()
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.all, 8)
        .sheet(isPresented: $showEditSheet) {
            AddExpenseBottomSheetView(itemToEdit: item)
        }
    }
}
