import SwiftUI
import SwiftData

struct ExpenseSection: View {
    let isEditMode: Bool
    
    @Binding var userCategories: [UserCategory]
    @Binding var selectedUserCategory: UserCategory?
    @Binding var selectedCategory: AddExpenseBottomSheetView.CategoryType?
    
    let onAddCategoryTapped: () -> Void
    let onDeleteCategory: (UserCategory) -> Void
    
    @Binding var price: String
    @Binding var dateValue: Date
    @Binding var note: String
    
    let addNewCategory: () -> Void
    
    var body: some View {
        let selectedCategoryLabel = selectedUserCategory.map { "\($0.emoji) \($0.name)" } ?? selectedCategory?.rawValue ?? "No category selected"

        VStack(alignment: .center, spacing: 18) {
            // Header Info Card
            VStack(alignment: .center, spacing: 8) {
                Text(isEditMode ? "Update expense" : "Add an expense")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Select a category, set the date, and save the outgoing transaction.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(selectedCategoryLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundColor(.secondary)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(dateValue.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundColor(.secondary)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .groupedCard()

            if !isEditMode {
                // Category selection header
                HStack {
                    Text("Select Category")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        onAddCategoryTapped()
                    } label: {
                        Text("Add Custom")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(.white)
                            .background(Color.appGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Grid selection chips
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
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 180)
            }

            // Input: Amount
            VStack(alignment: .leading, spacing: 6) {
                Text("Amount")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    Text("₹")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("Enter expense amount", text: $price)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Input: Date picker row
            HStack {
                Text("Date")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                DatePicker("", selection: $dateValue, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Date Quick Filters
            HStack(spacing: 10) {
                dateQuickButton("Today") { dateValue = Date() }
                dateQuickButton("Yesterday") {
                    dateValue = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }
                Spacer()
            }

            // Input: Note text editor
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Note")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("(Optional)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                TextEditor(text: $note)
                    .frame(height: 72)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private func chip(label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.appGreen : Color.primary.opacity(0.06))
            )
    }

    @ViewBuilder
    private func dateQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(.primary.opacity(0.8))
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }
}
