import SwiftUI
import Combine

struct OnBoardingScreen: View {
    @AppStorage("username") private var userName: String = ""
    @State private var currentMessageIndex: Int = 0
    @State private var navigateToAccountType: Bool = false

    private let messages = [
        "Track your daily expenses easily",
        "Visualize your spending habits",
        "Save smarter & grow financially"
    ]
    private let autoScrollTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    Text("Track money without the cluster")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)

                    Text("A simple personal and business flow for expenses,\nincome, and reminders.")
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)

                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 320, height: 320)

                    Image("onboarding_image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 10) {
                    ZStack {
                        Text(messages[currentMessageIndex])
                            .id(currentMessageIndex)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                )
                            )
                    }
                    .frame(height: 36)
                    .clipped()

                    HStack(spacing: 7) {
                        ForEach(messages.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentMessageIndex ? Color.green : Color.gray.opacity(0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                )
                .padding(.bottom, 12)

                Button {
                    navigateToAccountType = true
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18, weight: .semibold))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.green)
                )
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .onReceive(autoScrollTimer) { _ in
                withAnimation {
                    currentMessageIndex = (currentMessageIndex + 1) % messages.count
                }
            }
            .navigationDestination(isPresented: $navigateToAccountType) {
                AccountTypeView()
            }
        }
    }
}

#Preview {
    OnBoardingScreen()
}
