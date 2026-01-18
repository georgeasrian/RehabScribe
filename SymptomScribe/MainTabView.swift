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
            
            // 2. Exercise Log Tab
            NavigationView {
                ExerciseLogView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem {
                Image(systemName: "figure.strengthtraining.traditional")
                Text("Exercise Log")
            }
            
            // 3. KOOS JR Tab
            NavigationView {
                KOOSJRView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem {
                Image(systemName: "list.clipboard")
                Text("KOOS JR")
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