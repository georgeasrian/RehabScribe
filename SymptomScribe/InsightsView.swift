import SwiftUI
import CoreData

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Symptom.date, ascending: false)],
        animation: .default)
    private var allSymptoms: FetchedResults<Symptom>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)],
        animation: .default)
    private var allNotes: FetchedResults<Note>
    
    var symptomFrequency: [(name: String, count: Int)] {
        // Extract symptom names FIRST to avoid copying Core Data objects
        let presentSymptomNames = allSymptoms.filter { $0.isPresent }.compactMap { $0.symptomName }
        
        // Count occurrences
        var counts: [String: Int] = [:]
        for name in presentSymptomNames {
            counts[name, default: 0] += 1
        }
        
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    var totalRecordings: Int {
        allNotes.count
    }
    
    var totalDetectedSymptoms: Int {
        allSymptoms.filter { $0.isPresent }.count
    }
    
    var mostCommonSymptom: String {
        symptomFrequency.first?.name ?? "None"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Summary Cards
                VStack(spacing: 12) {
                    Text("Overview")
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        // Total Recordings
                        StatCard(
                            title: "Recordings",
                            value: "\(totalRecordings)",
                            icon: "waveform",
                            color: .blue
                        )
                        
                        // Total Symptoms
                        StatCard(
                            title: "Symptoms",
                            value: "\(totalDetectedSymptoms)",
                            icon: "heart.text.square",
                            color: .red
                        )
                    }
                    
                    // Most Common Symptom
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.orange)
                            Text("Most Frequent")
                                .font(.headline)
                        }
                        
                        Text(mostCommonSymptom)
                            .font(.title3)
                            .bold()
                            .foregroundColor(.orange)
                        
                        if let topSymptom = symptomFrequency.first {
                            Text("Reported \(topSymptom.count) time\(topSymptom.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Symptom Frequency Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Symptom Frequency")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    if symptomFrequency.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No symptoms recorded yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Start recording to see insights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(symptomFrequency.prefix(10), id: \.name) { item in
                                SymptomBarView(
                                    symptomName: item.name,
                                    count: item.count,
                                    maxCount: symptomFrequency.first?.count ?? 1
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    if allNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No recent activity")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(allNotes.prefix(5)), id: \.objectID) { note in
                                RecentActivityRow(note: note)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Insights")
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SymptomBarView: View {
    let symptomName: String
    let count: Int
    let maxCount: Int
    
    var percentage: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(symptomName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Filled portion
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

struct RecentActivityRow: View {
    let note: Note
    
    var symptomCount: Int {
        guard let symptoms = note.symptoms else { return 0 }
        var count = 0
        for case let symptom as Symptom in symptoms {
            if symptom.isPresent {
                count += 1
            }
        }
        return count
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.date ?? Date(), style: .date)
                    .font(.subheadline)
                    .bold()
                Text(note.date ?? Date(), style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(symptomCount > 0 ? .red : .gray)
                    Text("\(symptomCount)")
                        .font(.headline)
                }
                Text(symptomCount == 1 ? "symptom" : "symptoms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

