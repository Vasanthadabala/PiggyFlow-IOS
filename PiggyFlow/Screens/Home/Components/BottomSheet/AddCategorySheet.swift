//
//  AddCategorySheet.swift
//  PiggyFlow
//
//  Created by Vasanth on 24/12/25.
//

import SwiftUI

struct AddCategorySheet: View {
    
    let entryType: AddExpenseBottomSheetView.EntryType
    
    @Binding var newCategoryName: String
    @Binding var newCategoryEmoji: String
    @Binding var showToast: Bool
    
    let onAddExpenseCategory: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack{
            VStack(spacing: 20) {
                
                // Close button pinned at top right
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(Color.red)
                            .padding()
                    }
                }
                VStack(spacing: 20) {
                    Text("Add New Category")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category Name")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                        
                        TextField("Enter User Name", text: $newCategoryName)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .shadow(radius: 0.5)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        
                        HStack {
                            Text("Emoji")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                            
                            Text("(Optional)")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundColor(Color.gray.opacity(0.5))
                        }
                        
                        TextField("Emoji", text: $newCategoryEmoji)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .shadow(radius: 0.5)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                    }
                    .padding(.horizontal, 4)
                    
                    HStack(spacing: 20) {
                        
                        Button {
                            newCategoryName = ""
                            newCategoryEmoji = ""
                            onDismiss()
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .font(.system(size: 18, weight: .medium, design: .serif))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .foregroundColor(.white)
                        .background(Color.red.gradient)
                        .cornerRadius(10)
                        
                        Button {
                            onAddExpenseCategory()
                            
                        } label: {
                            Text("Add")
                                .frame(maxWidth: .infinity)
                                .font(.system(size: 18, weight: .medium, design: .serif))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .foregroundColor(.white)
                        .background(Color.green.gradient)
                        .cornerRadius(10)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
                
                if showToast {
                    VStack {
                        Spacer()
                        Text("⚠️ Provide Category Name!")
                            .font(.body)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                            .padding(.bottom, 50)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeInOut, value: showToast)
                }
            }
        }
    }
}
