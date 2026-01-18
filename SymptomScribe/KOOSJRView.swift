import SwiftUI
import CoreData
import UIKit

struct KOOSJRView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \KOOSJRResponse.date, ascending: false)],
        animation: .default)
    private var koosJRResponses: FetchedResults<KOOSJRResponse>
    
    @State private var isGeneratingCSV = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Export Button
                VStack(spacing: 12) {
                    Button(action: shareCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export CSV")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isGeneratingCSV)
                    
                    if isGeneratingCSV {
                        Text("Generating your export file...")
                            .foregroundColor(.gray)
                            .padding(.bottom, 16)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // KOOS JR Table
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Row
                        HStack(spacing: 0) {
                            Text("Date & Time")
                                .bold()
                                .frame(width: 160, alignment: .leading)
                                .padding(.horizontal, 6)
                            
                            Text("Stiffness")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Twisting")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Straightening")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Stairs")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Standing")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Rising")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Bending")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("Raw Score")
                                .bold()
                                .frame(width: 70, alignment: .center)
                                .padding(.horizontal, 4)
                            
                            Text("KOOS JR Score")
                                .bold()
                                .frame(width: 90, alignment: .center)
                                .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .border(Color.black, width: 1)
                        .font(.caption)
                        
                        // Data Rows
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                if koosJRResponses.isEmpty {
                                    Text("No KOOS JR responses recorded yet")
                                        .foregroundColor(.gray)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    ForEach(koosJRResponses, id: \.objectID) { response in
                                        HStack(spacing: 0) {
                                            Text(response.date ?? Date(), formatter: itemFormatter)
                                                .frame(width: 160, alignment: .leading)
                                                .padding(.horizontal, 6)
                                                .font(.caption)
                                            
                                            Text(scaleLabel(response.stiffnessAfterWaking))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.twistingPivotingPain))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.straighteningKneeFully))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.goingUpDownStairs))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.standingUpright))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.risingFromSitting))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text(scaleLabel(response.bendingToFloor))
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption2)
                                            
                                            Text("\(response.rawScore)")
                                                .frame(width: 70, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption)
                                            
                                            Text(String(format: "%.1f", response.transformedScore))
                                                .frame(width: 90, alignment: .center)
                                                .padding(.horizontal, 4)
                                                .font(.caption)
                                                .bold()
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .border(Color.gray.opacity(0.2), width: 0.5)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Summary Stats
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if let latestResponse = koosJRResponses.first {
                        HStack {
                            Text("Latest KOOS JR Score:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", latestResponse.transformedScore))
                                .font(.caption)
                                .bold()
                                .foregroundColor(latestResponse.transformedScore >= 70 ? .green : (latestResponse.transformedScore >= 50 ? .orange : .red))
                            
                            Spacer()
                            
                            Text("Total Responses:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(koosJRResponses.count)")
                                .font(.caption)
                                .bold()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    } else {
                        HStack {
                            Text("No KOOS JR responses recorded yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("KOOS JR Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func scaleLabel(_ value: Int16) -> String {
        switch value {
        case 0: return "None"
        case 1: return "Mild"
        case 2: return "Mod"
        case 3: return "Sev"
        case 4: return "Ext"
        default: return "-"
        }
    }
    
    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - CSV Export
    
    func shareCSV() {
        isGeneratingCSV = true
        DispatchQueue.global(qos: .userInitiated).async {
            let csvString = generateCSVString()
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "KOOSJR_\(Date().timeIntervalSince1970).csv"
            let csvURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    isGeneratingCSV = false
                    presentShareSheet(with: [csvURL])
                }
            } catch {
                print("Error writing CSV file: \(error)")
                DispatchQueue.main.async {
                    isGeneratingCSV = false
                }
            }
        }
    }
    
    func presentShareSheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true)
    }
    
    func generateCSVString() -> String {
        var csvText = "Date,Time,Stiffness After Waking,Twisting/Pivoting Pain,Straightening Knee Fully,Going Up/Down Stairs,Standing Upright,Rising From Sitting,Bending To Floor,Raw Score,KOOS JR Score\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        func scaleLabel(_ value: Int16) -> String {
            switch value {
            case 0: return "None"
            case 1: return "Mild"
            case 2: return "Moderate"
            case 3: return "Severe"
            case 4: return "Extreme"
            default: return "-"
            }
        }
        
        for response in koosJRResponses {
            let date = response.date ?? Date()
            let dateString = dateFormatter.string(from: date)
            let timeString = timeFormatter.string(from: date)
            
            let line = "\"\(dateString)\",\"\(timeString)\",\"\(scaleLabel(response.stiffnessAfterWaking))\",\"\(scaleLabel(response.twistingPivotingPain))\",\"\(scaleLabel(response.straighteningKneeFully))\",\"\(scaleLabel(response.goingUpDownStairs))\",\"\(scaleLabel(response.standingUpright))\",\"\(scaleLabel(response.risingFromSitting))\",\"\(scaleLabel(response.bendingToFloor))\",\"\(response.rawScore)\",\"\(String(format: "%.1f", response.transformedScore))\"\n"
            csvText += line
        }
        
        return csvText
    }
}