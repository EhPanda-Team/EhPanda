//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                SummaryRow()
                SummaryRow()
                SummaryRow()
                SummaryRow()
                SummaryRow()
                SummaryRow()
                Spacer()
            }
            .padding()
            .navigationBarTitle(Text("首页"))
            .navigationBarItems(trailing: Button(action: { }) {
                Image(systemName: "magnifyingglass")
                    .imageScale(.large)
                    .accessibility(label: Text("User Profile"))
                    .padding()
                    .foregroundColor(.white)
            }
            .offset(x: 0, y: 45)
            )
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
