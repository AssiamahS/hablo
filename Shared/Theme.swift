import SwiftUI

enum Theme {
    static let blue = Color(red: 0.16, green: 0.45, blue: 0.96)
    static let blueSoft = Color(red: 0.16, green: 0.45, blue: 0.96).opacity(0.12)

    static let gradient = LinearGradient(
        colors: [Color(red: 0.17, green: 0.42, blue: 0.95), Color(red: 0.36, green: 0.72, blue: 0.98)],
        startPoint: .top, endPoint: .bottom)
}
