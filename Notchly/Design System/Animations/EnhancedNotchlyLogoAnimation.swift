import SwiftUI
import Combine

/// An enhanced version of the NotchlyLogoAnimation that draws an "N"
/// and then reveals the rest of the "otchly" text with smooth animations
struct EnhancedNotchlyLogoAnimation: View {
    // Animation state variables
    @State private var nProgress = 0.0                 // Progress of N drawing (0-1)
    @State private var showRainbow = false             // Controls rainbow effect
    @State private var gradientOffset = 0.0            // For rotating gradient effect
    @State private var showFullText = false            // Controls "otchly" text visibility
    @State private var textProgress = 0.0              // Text reveal animation (0-1)
    @State private var logoShift: CGFloat = 0          // Controls horizontal shift of the N
    @State private var logoScale: CGFloat = 1.0        // Start at full size with no scaling
    @State private var notificationSubscription: AnyCancellable?

    // Control flag to determine if animations should start
    var startAnimation: Bool = true
    // Coordinate with notch expansion flag
    var coordinateWithNotch: Bool = false
    
    // Visual style - THINNER LINE for better proportion
    private let style = StrokeStyle(lineWidth: 4, lineCap: .round)
    
    // Animation timing
    private let nDrawDuration: Double = 3.0
    private let rainbowFadeDuration: Double = 1.0
    private let fullTextDelay: Double = 4.5
    private let textRevealDuration: Double = 1.5
    private let logoShiftDuration: Double = 0.7
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Center container for the full content
                HStack(spacing: 0) {
                    // N Logo container - begins centered
                    ZStack {
                        // White stroke path animation for N
                        NotchlyLogoShape()
                            .trim(from: 0, to: nProgress)
                            .stroke(Color.white, style: style)
                            .opacity(showRainbow ? 0 : 1)
                        
                        // Rainbow gradient path with blur glow
                        if showRainbow {
                            let base = NotchlyLogoShape()
                                .trim(from: 0, to: nProgress)
                                .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)
                            
                            // Add blur for glow effect
                            base.blur(radius: 5)
                            base.blur(radius: 2)
                            base // Crisp outline on top
                        }
                    }
                    .scaleEffect(logoScale)
                    .frame(width: 80, height: 80) // Fixed size for the N
                    .offset(x: logoShift)
                    
                    // "otchly" Text container
                    if showFullText {
                        Text("otchly")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(textProgress)
                            .mask(
                                Rectangle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.white, .clear]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .scaleEffect(x: textProgress * 2)
                            )
                            .padding(.leading, 10)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            if coordinateWithNotch {
                // Set up notification observer for text reveal
                notificationSubscription = NotificationCenter.default
                    .publisher(for: Notification.Name("NotchlyRevealText"))
                    .receive(on: RunLoop.main)
                    .sink { _ in
                        revealText()
                    }
            }
            
            if startAnimation {
                startAnimationSequence()
            }
        }
        .onDisappear {
            notificationSubscription?.cancel()
        }
    }

    // MARK: - Animation Control
    
    private func startAnimationSequence() {
        // Step 1: Draw the N with white stroke
        withAnimation(.easeInOut(duration: nDrawDuration)) {
            nProgress = 1.0
        }
        
        // Step 2: Crossfade to rainbow
        DispatchQueue.main.asyncAfter(deadline: .now() + nDrawDuration) {
            withAnimation(.easeInOut(duration: rainbowFadeDuration)) {
                showRainbow = true
            }
            
            // Start the rainbow rotation animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
        
        // If we're coordinating with notch expansion, don't show text yet
        // The fullNameStageView will handle that
        if !coordinateWithNotch {
            // Handle normal flow when not coordinating
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                showFullText = true
                textProgress = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: textRevealDuration)) {
                        textProgress = 1.0
                    }
                }
                
                // Shift N logo to the left
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    logoShift = -120
                    logoScale = 0.85
                }
            }
        }
    }
    
    func revealText() {
        showFullText = true
        textProgress = 0
        
        // First show the text with animation
        withAnimation(.easeInOut(duration: textRevealDuration)) {
            textProgress = 1.0
        }
        
        // Simultaneously shift the N logo to the left
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoShift = -120
            logoScale = 0.85
        }
    }
}
