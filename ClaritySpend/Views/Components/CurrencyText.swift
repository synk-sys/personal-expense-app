import SwiftUI

// MARK: - Currency Formatter
struct CurrencyText: View {
    let amount: Double
    let currency: String
    var style: Style = .standard
    var colorBySign: Bool = false

    enum Style {
        case standard, large, small, compact
    }

    var formattedString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        switch style {
        case .compact:
            if abs(amount) >= 1_000_000 {
                return "\(formatter.currencySymbol ?? "")\(String(format: "%.1f", amount / 1_000_000))M"
            } else if abs(amount) >= 1_000 {
                return "\(formatter.currencySymbol ?? "")\(String(format: "%.1f", amount / 1_000))K"
            }
        default: break
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    var textColor: Color {
        if colorBySign {
            return amount >= 0 ? .green : .red
        }
        return .primary
    }

    var font: Font {
        switch style {
        case .large: return .title.bold()
        case .small: return .caption
        case .compact: return .subheadline
        case .standard: return .body
        }
    }

    var body: some View {
        Text(formattedString)
            .font(font)
            .foregroundColor(textColor)
    }
}

// MARK: - Category Color from Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Card Style Modifier
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Category Icon View
struct CategoryIconView: View {
    let icon: String
    let colorHex: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.2))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.45))
                .foregroundColor(Color(hex: colorHex))
        }
    }
}

// MARK: - Amount Input Field
struct AmountInputField: View {
    @Binding var amount: String
    var currency: String = "USD"
    var placeholder: String = "0.00"

    var body: some View {
        HStack(spacing: 4) {
            Text(Currency.find(currency)?.symbol ?? "$")
                .font(.title)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $amount)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Progress Bar
struct BudgetProgressBar: View {
    var value: Double  // 0.0 - 1.0+
    var isEssential: Bool = false

    var color: Color {
        if value >= 1.0 { return .red }
        if value >= 0.8 { return .orange }
        return isEssential ? .blue : .indigo
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: min(geo.size.width * CGFloat(value), geo.size.width), height: 8)
                    .animation(.spring(), value: value)
            }
        }
        .frame(height: 8)
    }
}
