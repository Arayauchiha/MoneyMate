import SwiftUI
import UIKit

extension Color {
    nonisolated init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return "AAAAAA" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return unsafe String(format: "%02X%02X%02X", r, g, b)
    }
}

extension UIColor {
    convenience nonisolated init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 3 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        unsafe Scanner(string: cleaned).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
