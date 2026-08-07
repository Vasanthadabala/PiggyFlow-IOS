import SwiftUI

struct AddCategorySheet: View {
    let entryType: AddExpenseBottomSheetView.EntryType
    @Binding var isPresented: Bool
    
    @Binding var newCategoryName: String
    @Binding var newCategoryEmoji: String
    @Binding var showToast: Bool
    
    let onAddExpenseCategory: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button pinned at top right
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white, .red)
                            .padding()
                    }
                }
                
                VStack(spacing: 24) {
                    Text("Add New Category")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Category Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category Name")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        TextField("e.g. Subscriptions, Groceries", text: $newCategoryName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Category Emoji Field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Emoji")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("(Optional)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        TextField("e.g. 🍿, 🚗, 🏡", text: $newCategoryEmoji)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button {
                            newCategoryName = ""
                            newCategoryEmoji = ""
                            isPresented = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.primary)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onAddExpenseCategory()
                        } label: {
                            Text("Add Category")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(Color.appGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                if showToast {
                    VStack {
                        Spacer()
                        Text("⚠️ Please enter a category name")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(12)
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
