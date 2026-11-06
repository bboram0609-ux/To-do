import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// 콩이 색. 캐릭터를 바꿀 때는 이 값들만 고치면 된다.
enum KongiColors {
    static let bean = Color(hex: 0xC5E29E)
    static let beanEdge = Color(hex: 0x6C984A)
    static let belly = Color(hex: 0xE6F3D2)
    static let leaf = Color(hex: 0x6DBD67)
    static let leafDark = Color(hex: 0x3E8944)
    static let cheek = Color(hex: 0xF3A39C)
    static let eye = Color(hex: 0x2A2B26)
    static let mouth = Color(hex: 0xB4504A)
    static let petal = Color(hex: 0xF6B4C6)
    static let pollen = Color(hex: 0xFFD166)
    static let water = Color(hex: 0x86C3EE)
    static let glass = Color(hex: 0xDFF0FA)
    /// 앱 전체 강조색
    static let accent = Color(hex: 0x3D8A55)
}
