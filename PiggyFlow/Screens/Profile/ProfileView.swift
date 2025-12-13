import SwiftUI

struct ProfileView: View {
    @AppStorage("username") private var userName: String = ""
    @State private var editMode: Bool = false
    @State private var showToast: Bool = false
    @State private var text: String = ""
    
    var body: some View {
        ZStack{
            VStack(){
                ZStack{
                    Circle()
                        .fill(Color.green.gradient)
                        .frame(width: 96, height: 96)
                    
                    Text(userName.prefix(1).uppercased())
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                
                Spacer()
                    .frame(height: 24)
                
                Text(userName)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                
                Spacer()
                    .frame(height: 24)
                
                if(editMode){
                    VStack{
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        
                        HStack{
                            Button {
                                editMode.toggle()
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
                                if !text.isEmpty {
                                    userName = text
                                    editMode.toggle()
                                }else{
                                    withAnimation {
                                        showToast = true
                                    }
                                    
                                    // Hide toast after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showToast = false
                                        }
                                    }
                                }
                            } label: {
                                Text("Update")
                                    .frame(maxWidth: .infinity)
                                    .font(.system(size: 18, weight: .medium, design: .serif))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .foregroundColor(.white)
                            .background(Color.green.gradient)
                            .cornerRadius(10)
                        }
                    }
                }else {
                    Button {
                        editMode.toggle()
                    } label: {
                        Text("Edit")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .foregroundColor(.white)
                    .background(Color.green.gradient)
                    .cornerRadius(10)
                }
                
                Spacer()
                
            }
            .padding()
            
            if showToast {
                VStack {
                    Spacer()
                    Text("⚠️ Provide Name!")
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
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
}
