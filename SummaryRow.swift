//
//  SummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/31.
//

import SwiftUI

struct SummaryRow: View {
    var body: some View {
        HStack {
            Image("test")
                .resizable()
                .frame(width: 70, height: 110)
            VStack(alignment: .leading) {
                Text("[Pixiv] 月うさぎ (3440024)]")
                    .lineLimit(1)
                    .font(.headline)
                Text("Pokom")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .imageScale(.small)
                HStack(alignment: .bottom) {
                    Text("NON-H")
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3))
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .foregroundColor(.blue)
                        )
                    Spacer()
                    Text("2020-10-31 08:38")
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 1)
            }.padding(10)
        }
        .background(Color(hex: "333333"))
        .cornerRadius(3)
    }
}

struct SummaryRow_Previews: PreviewProvider {
    static var previews: some View {
        SummaryRow()
            .preferredColorScheme(.dark)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
