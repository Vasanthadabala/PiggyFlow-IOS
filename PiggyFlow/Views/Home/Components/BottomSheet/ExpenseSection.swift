//
//  ExpenseSection.swift
//  PiggyFlow
//
//  Created by Vasanth on 24/12/25.
//

import SwiftUI
import SwiftData

struct ExpenseSection: View {
    
    let isEditMode: Bool
    
    @Binding var userCategories: [UserCategory]
    @Binding var selectedUserCategory: UserCategory?
    @Binding var selectedCategory: AddExpenseBottomSheetView.CategoryType?
    
    // UI triggers
    let onAddCategoryTapped: () -> Void
    let onDeleteCategory: (UserCategory) -> Void
    
    @Binding var price: String
    @Binding var dateValue: Date
    @Binding var note: String
    
    let addNewCategory: () -> Void
    
    var body: some View {
        
        if isEditMode {
            HStack {
                Text("Update Expense")
                    .font(.system(size: 24, weight: .medium, design: .serif))
            }
        }
        
        VStack(alignment: .leading, spacing: 8) {
            
            if !isEditMode {
                HStack {
                    Text("Select Category")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                    
                    Spacer()
                    
                    Button("+ Add Category") {
                        onAddCategoryTapped()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(Color.green.gradient)
                    .cornerRadius(10)
                }
                
                // CATEGORY GRID
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        
                        ForEach(userCategories) { category in
                            Text("\(category.emoji) \(category.name)")
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(
                                    selectedUserCategory?.id == category.id
                                    ? Color.white
                                    : Color.blue
                                )
                                .background(
                                    selectedUserCategory?.id == category.id
                                    ? Color.green.opacity(0.8)
                                    : Color.gray.opacity(0.1)
                                )
                                .cornerRadius(12)
                                .onTapGesture {
                                    selectedUserCategory = category
                                    selectedCategory = nil
                                }
                            
                                .onLongPressGesture(minimumDuration: 1) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onDeleteCategory(category)
                                }
                        }
                        
                        ForEach(AddExpenseBottomSheetView.CategoryType.allCases) { category in
                            Text(category.rawValue)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity) // full width in grid cell
                                .foregroundColor(selectedCategory == category ? Color.white : Color.blue)
                                .background(selectedCategory == category ? Color.green.opacity(0.8) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .onTapGesture {
                                    selectedCategory = category
                                    selectedUserCategory = nil
                                }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .disabled(isEditMode)
            }
        }
        
        // Price
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter Price")
                .font(.system(size: 16, weight: .regular, design: .serif))
            
            TextField("e.g., 100", text: $price)
                .keyboardType(.decimalPad)
                .padding(.all, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(radius: 0.5)
                .font(.system(size: 18, weight: .regular, design: .serif))
        }
        
        DatePicker(selection: $dateValue, label: {
            Text("Due Date")
                .font(.system(size: 16, weight: .medium, design: .serif))
            
        })
        .padding(.all, 4)
        
        // Note
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Note")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                
                Text("(Optional)")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
            
            TextEditor(text: $note)
                .frame(height: 50)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(radius: 0.5)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .scrollContentBackground(.hidden)
        }
    }
}

