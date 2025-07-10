import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @Binding var showOnboarding: Bool
    
    let onboardingPages = [
        OnboardingPage(
            title: "Welcome to IELTS Practice AI",
            subtitle: "Your personal AI-powered IELTS speaking coach",
            imageName: "mic.circle.fill",
            imageColor: .blue,
            description: "Practice speaking with our intelligent AI examiner anytime, anywhere"
        ),
        OnboardingPage(
            title: "Real Exam Experience",
            subtitle: "Practice all three parts of IELTS speaking",
            imageName: "person.2.fill",
            imageColor: .green,
            description: "Part 1: Introduction & Interview\nPart 2: Individual Long Turn\nPart 3: Two-way Discussion"
        ),
        OnboardingPage(
            title: "Instant Feedback",
            subtitle: "Improve with AI-powered analysis",
            imageName: "chart.line.uptrend.xyaxis",
            imageColor: .orange,
            description: "Get detailed feedback on fluency, vocabulary, grammar, and pronunciation"
        ),
        OnboardingPage(
            title: "Track Your Progress",
            subtitle: "Review your practice history",
            imageName: "clock.arrow.circlepath",
            imageColor: .purple,
            description: "Access all your past sessions and monitor your improvement over time"
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color("AppBackground"),
                    Color("Primary").opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(Color("SecondaryTextColor"))
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page indicators and buttons
                VStack(spacing: 30) {
                    // Custom page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color("Primary") : Color("SecondaryTextColor").opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(Color("Primary"))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color("Primary"), lineWidth: 2)
                                )
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if currentPage < onboardingPages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                completeOnboarding()
                            }
                        }) {
                            HStack {
                                Text(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next")
                                Image(systemName: currentPage == onboardingPages.count - 1 ? "arrow.right.circle.fill" : "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color("Primary"), Color("Primary").opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .shadow(color: Color("Primary").opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
    
    private func completeOnboarding() {
        hasSeenOnboarding = true
        withAnimation(.easeInOut) {
            showOnboarding = false
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let imageColor: Color
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.imageColor)
                .padding(.bottom, 20)
            
            // Title
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(Color("PrimaryTextColor"))
            
            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundColor(Color("SecondaryTextColor"))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(Color("SecondaryTextColor"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(5)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}
