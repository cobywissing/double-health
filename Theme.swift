import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background = Color(red: 0.12, green: 0.12, blue: 0.15) // Dark slate
    static let surface = Color(red: 0.15, green: 0.15, blue: 0.18) // Slightly lighter slate
    static let accent = Color(red: 0.75, green: 0.75, blue: 0.78) // Silver
    static let text = Color.white
    static let secondaryText = Color.gray
    
    // MARK: - Gradients
    static let buttonGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.85, blue: 0.88), // Light silver
            Color(red: 0.65, green: 0.65, blue: 0.68)  // Darker silver
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Theme.buttonGradient)
            .foregroundColor(Theme.background)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Theme.surface)
            .foregroundColor(Theme.accent)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.accent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers
extension View {
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
} 