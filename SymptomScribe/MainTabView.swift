import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
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
            
            // 3. Symptom Log Tab
            NavigationView {
                ContentView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem {
                Image(systemName: "list.bullet.clipboard")
                Text("Symptom Log")
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
