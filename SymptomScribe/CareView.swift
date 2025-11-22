//
//  CareView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 10/1/24.
//

import SwiftUI

struct CareView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
           
            Spacer()
            
            // Placeholder for remedies
            Text("Here are some suggested remedies for your symptoms:")
                .font(.headline)
                .padding(.horizontal)

            // Example remedies
            VStack(alignment: .leading, spacing: 10) {
                Text("• Stay hydrated by drinking plenty of water.")
                Text("• Get adequate rest and sleep.")
                Text("• Consult a healthcare professional for personalized advice.")
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Care") // Set navigation title without nested NavigationView
    }
}

struct CareView_Previews: PreviewProvider {
    static var previews: some View {
        CareView()
    }
}
