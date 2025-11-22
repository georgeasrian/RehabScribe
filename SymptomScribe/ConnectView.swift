//
//  ConnectView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 10/1/24.
//

import SwiftUI

struct ConnectView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            
            Spacer()
            
            // Description or Instructional Text
            Text("Book an appointment with a specialist based on your symptoms:")
                .font(.headline)
                .padding(.horizontal)

            // Example Doctor Suggestions
            VStack(alignment: .leading, spacing: 10) {
                Text("• Dr. Jane Smith - General Practitioner")
                Text("• Dr. John Doe - Neurologist")
                Text("• Dr. Emily Brown - Cardiologist")
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Connect") // Set navigation title without nested NavigationView
    }
}
