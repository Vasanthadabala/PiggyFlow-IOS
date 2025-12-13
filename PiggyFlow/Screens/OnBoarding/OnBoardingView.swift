import SwiftUI

struct OnBoardingScreen: View {
    @State private var showBottomSheet: Bool = false
    @AppStorage("username") private var userName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 32) {
                VStack {
                    Image("onboarding_image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .clipShape(Circle())
                }
                .padding(32)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .shadow(radius: 0)
                )
                
                Spacer().frame(height: 40)
                
                Text("Track your expenses, manage your budget, and stay in control of your money with ease.")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer().frame(height: 20)
                
                Button {
                    showBottomSheet.toggle()
                } label: {
                    Text("Get Started")
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
            .fullScreenCover(isPresented: $showBottomSheet) {
                BottomSheetView()
            }
            // ✅ Automatically navigate if username exists
            .navigationDestination(isPresented: .constant(!userName.isEmpty)) {
                MainTabView()
            }
        }
    }
}

struct BottomSheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""
    @AppStorage("username") private var userName: String = ""
    @State private var navigateToHome = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 32)
                
                // Close button pinned at top right
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                VStack(spacing: 20) {
                    VStack {
                        Image("onboarding_image")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 260, height: 260)
                            .clipShape(Circle())
                    }
                    .padding(32)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .shadow(radius: 0)
                    )
                    
                    Spacer().frame(height: 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Your Name")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                        
                        TextField("Enter User Name", text: $text)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .shadow(radius: 0.5)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                    }
                    .padding(.horizontal, 4)
                    
                    Button {
                        userName = text
                        navigateToHome = true
                    } label: {
                        Text("Let's Go")
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
                Spacer()
            }
            .navigationDestination(isPresented: $navigateToHome) {
                MainTabView()
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview {
    OnBoardingScreen()
}
