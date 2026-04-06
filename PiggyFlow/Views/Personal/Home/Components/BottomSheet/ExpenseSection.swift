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
        let selectedCategoryLabel = selectedUserCategory.map { "\($0.emoji) \($0.name)" } ?? selectedCategory?.rawValue ?? "No category selected"

        VStack(alignment: .center, spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                Text(isEditMode ? "Update expense" : "Add an expense")
                    .font(.system(size: 24, weight: .semibold))
                Text("Select a category, set the date, and save the outgoing transaction.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)

                HStack(spacing: 8) {
                    Text(selectedCategoryLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(dateValue.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )

            if !isEditMode {
                HStack {
                    Text("Select Category")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button("Add Category") {
                        onAddCategoryTapped()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(10)
                }

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(userCategories) { category in
                            chip(
                                label: "\(category.emoji) \(category.name)",
                                isSelected: selectedUserCategory?.id == category.id
                            )
                            .onTapGesture {
                                selectedUserCategory = category
                                selectedCategory = nil
                            }
                            .onLongPressGesture(minimumDuration: 1) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onDeleteCategory(category)
                            }
                        }

                        ForEach(AddExpenseBottomSheetView.CategoryType.expenseDefaultCategories) { category in
                            chip(label: category.rawValue, isSelected: selectedCategory == category)
                                .onTapGesture {
                                    selectedCategory = category
                                    selectedUserCategory = nil
                                }
                        }
                    }
                }
                .frame(maxHeight: 190)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.system(size: 18, weight: .medium))
                HStack(spacing: 8) {
                    Text("₹")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.gray)
                    TextField("Enter expense amount", text: $price)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
            }

            HStack {
                Text("Date")
                    .font(.system(size: 18, weight: .medium))
                Spacer()
                DatePicker("", selection: $dateValue, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )

            HStack(spacing: 10) {
                dateQuickButton("Today") { dateValue = Date() }
                dateQuickButton("Yesterday") { dateValue = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date() }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Note")
                        .font(.system(size: 18, weight: .medium))
                    Text("(Optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                }
                TextEditor(text: $note)
                    .frame(height: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                    .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private func chip(label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 16, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.2))
            )
    }

    @ViewBuilder
    private func dateQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.gray.opacity(0.2)))
            .buttonStyle(.plain)
    }
}
