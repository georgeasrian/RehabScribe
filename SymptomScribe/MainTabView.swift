//
//  MainTabView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        // Bottom Tabs
        TabView {
            // 1. Record Tab
            NavigationView {
                RecordView()
            }
            .tabItem {
                Image(systemName: "mic.fill")
                Text("Record")
            }
            
            // 2. Insights Tab
            NavigationView {
                InsightsView()
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Insights")
            }
            
            // 3. Workout Notes Tab
            NavigationView {
                ContentView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem {
                Image(systemName: "table.fill")
                Text("Workout Notes")
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
