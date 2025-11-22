//
//  InsightsView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 10/1/24.
//

// InsightsView.swift
import SwiftUI
import CoreData
import Charts

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedTimePeriod: TimePeriod = .week
    @State private var customDateRange: ClosedRange<Date> = {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        return start...now
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Period Picker
                    TimePeriodPicker(selectedTimePeriod: $selectedTimePeriod, customDateRange: $customDateRange)

                    // Workout Performance Overview
                    WorkoutPerformanceChart(timePeriod: selectedTimePeriod, customDateRange: customDateRange)

                    // Muscle Group Focus Analysis
                    MuscleGroupBarChart(timePeriod: selectedTimePeriod, customDateRange: customDateRange)

                    // Pain and Discomfort Tracking
                    PainDiscomfortChart(timePeriod: selectedTimePeriod, customDateRange: customDateRange)

                    // Resistance Type Utilization
                    ResistanceTypeBarChart(timePeriod: selectedTimePeriod, customDateRange: customDateRange)

                    // Rest Time Insights
                    RestTimeChart(timePeriod: selectedTimePeriod, customDateRange: customDateRange)

                    // HealthKit Data Integration (Placeholder)
                    // Add your HealthKit integration charts here
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}

// TimePeriod.swift
import Foundation

enum TimePeriod: String, CaseIterable, Identifiable {
    case day, week, month, threeMonths, year, allTime, custom

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .year: return "Year"
        case .allTime: return "All Time"
        case .custom: return "Custom Range"
        }
    }

    func dateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            return start...now
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return start...now
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return start...now
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return start...now
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return start...now
        case .allTime:
            let start = Date.distantPast
            return start...now
        case .custom:
            return now...now // Placeholder, actual range will be set externally
        }
    }
}

// TimePeriodPicker.swift
import SwiftUI

struct TimePeriodPicker: View {
    @Binding var selectedTimePeriod: TimePeriod
    @Binding var customDateRange: ClosedRange<Date>

    @State private var showingDatePicker = false

    var body: some View {
        HStack {
            Picker("Time Period", selection: $selectedTimePeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(MenuPickerStyle())

            if selectedTimePeriod == .custom {
                Button(action: {
                    showingDatePicker.toggle()
                }) {
                    Image(systemName: "calendar")
                }
                .sheet(isPresented: $showingDatePicker) {
                    DateRangePicker(customDateRange: $customDateRange)
                }
            }
        }
        .padding()
    }
}

// DateRangePicker.swift
import SwiftUI

struct DateRangePicker: View {
    @Binding var customDateRange: ClosedRange<Date>

    @Environment(\.presentationMode) var presentationMode

    @State private var startDate: Date
    @State private var endDate: Date

    init(customDateRange: Binding<ClosedRange<Date>>) {
        _customDateRange = customDateRange
        _startDate = State(initialValue: customDateRange.wrappedValue.lowerBound)
        _endDate = State(initialValue: customDateRange.wrappedValue.upperBound)
    }

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        customDateRange = startDate...endDate
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// WorkoutPerformanceChart.swift
import SwiftUI
import CoreData
import Charts

struct WorkoutPerformanceChart: View {
    @Environment(\.managedObjectContext) private var viewContext

    var timePeriod: TimePeriod
    var customDateRange: ClosedRange<Date>

    @State private var data: [WorkoutData] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Workout Performance Overview")
                .font(.headline)

            Chart {
                ForEach(data) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Total Weight", dataPoint.totalWeight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.blue)
                    .symbol(Circle())
                    .symbolSize(50)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let location = value.location
                                    if let date: Date = proxy.value(atX: location.x),
                                       let totalWeight: Double = proxy.value(atY: location.y) {
                                        // Display tooltip with date and totalWeight
                                    }
                                }
                                .onEnded { _ in
                                    // Hide tooltip
                                }
                        )
                }
            }
            .onAppear(perform: fetchData)
            .onChange(of: timePeriod) { _ in fetchData() }
            .onChange(of: customDateRange) { _ in fetchData() }
        }
    }

    private func fetchData() {
        let fetchRequest: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        let dateRange = timePeriod == .custom ? customDateRange : timePeriod.dateRange()
        fetchRequest.predicate = NSPredicate(format: "note.date >= %@ AND note.date <= %@", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let groupedData = Dictionary(grouping: results, by: { Calendar.current.startOfDay(for: $0.note?.date ?? Date()) })

            data = groupedData.map { (date, trainings) in
                let totalWeight = trainings.reduce(0) { $0 + $1.totalWeightLifted }
                return WorkoutData(date: date, totalWeight: totalWeight)
            }
            .sorted { $0.date < $1.date }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct WorkoutData: Identifiable {
    var id = UUID()
    var date: Date
    var totalWeight: Double
}

// MuscleGroupBarChart.swift
import SwiftUI
import CoreData
import Charts

struct MuscleGroupBarChart: View {
    @Environment(\.managedObjectContext) private var viewContext

    var timePeriod: TimePeriod
    var customDateRange: ClosedRange<Date>

    @State private var data: [MuscleGroupData] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Muscle Group Focus Analysis")
                .font(.headline)

            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Muscle Group", item.muscleGroup),
                        y: .value("Total Weight", item.totalWeight)
                    )
                    .foregroundStyle(by: .value("Muscle Group", item.muscleGroup))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .onEnded { value in
                                    // Handle tap gesture if needed
                                }
                        )
                }
            }
            .onAppear(perform: fetchData)
            .onChange(of: timePeriod) { _ in fetchData() }
            .onChange(of: customDateRange) { _ in fetchData() }
        }
    }

    private func fetchData() {
        let fetchRequest: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        let dateRange = timePeriod == .custom ? customDateRange : timePeriod.dateRange()
        fetchRequest.predicate = NSPredicate(format: "note.date >= %@ AND note.date <= %@", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let groupedData = Dictionary(grouping: results, by: { $0.muscleGroup ?? "Unspecified" })

            data = groupedData.map { (muscleGroup, trainings) in
                let totalWeight = trainings.reduce(0) { $0 + $1.totalWeightLifted }
                return MuscleGroupData(muscleGroup: muscleGroup, totalWeight: totalWeight)
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct MuscleGroupData: Identifiable {
    var id = UUID()
    var muscleGroup: String
    var totalWeight: Double
}

// PainDiscomfortChart.swift
import SwiftUI
import CoreData
import Charts

struct PainDiscomfortChart: View {
    @Environment(\.managedObjectContext) private var viewContext

    var timePeriod: TimePeriod
    var customDateRange: ClosedRange<Date>

    @State private var data: [PainData] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Pain and Discomfort Tracking")
                .font(.headline)

            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Count", item.count)
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .onEnded { value in
                                    // Handle tap gesture if needed
                                }
                        )
                }
            }
            .onAppear(perform: fetchData)
            .onChange(of: timePeriod) { _ in fetchData() }
            .onChange(of: customDateRange) { _ in fetchData() }
        }
    }

    private func fetchData() {
        let fetchRequest: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        let dateRange = timePeriod == .custom ? customDateRange : timePeriod.dateRange()
        fetchRequest.predicate = NSPredicate(format: "note.date >= %@ AND note.date <= %@ AND painOrDiscomfortYN == YES", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let groupedData = Dictionary(grouping: results, by: { Calendar.current.startOfDay(for: $0.note?.date ?? Date()) })

            data = groupedData.map { (date, trainings) in
                return PainData(date: date, count: trainings.count)
            }
            .sorted { $0.date < $1.date }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct PainData: Identifiable {
    var id = UUID()
    var date: Date
    var count: Int
}

// ResistanceTypeBarChart.swift
import SwiftUI
import CoreData
import Charts

struct ResistanceTypeBarChart: View {
    @Environment(\.managedObjectContext) private var viewContext

    var timePeriod: TimePeriod
    var customDateRange: ClosedRange<Date>

    @State private var data: [ResistanceTypeData] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Resistance Type Utilization")
                .font(.headline)

            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Resistance Type", item.resistanceType),
                        y: .value("Total Weight", item.totalWeight)
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .onEnded { value in
                                    // Handle tap gesture if needed
                                }
                        )
                }
            }
            .onAppear(perform: fetchData)
            .onChange(of: timePeriod) { _ in fetchData() }
            .onChange(of: customDateRange) { _ in fetchData() }
        }
    }

    private func fetchData() {
        let fetchRequest: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        let dateRange = timePeriod == .custom ? customDateRange : timePeriod.dateRange()
        fetchRequest.predicate = NSPredicate(format: "note.date >= %@ AND note.date <= %@", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let groupedData = Dictionary(grouping: results, by: { $0.resistanceType ?? "Unspecified" })

            data = groupedData.map { (resistanceType, trainings) in
                let totalWeight = trainings.reduce(0) { $0 + $1.totalWeightLifted }
                return ResistanceTypeData(resistanceType: resistanceType, totalWeight: totalWeight)
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct ResistanceTypeData: Identifiable {
    var id = UUID()
    var resistanceType: String
    var totalWeight: Double
}

// RestTimeChart.swift
import SwiftUI
import CoreData
import Charts

struct RestTimeChart: View {
    @Environment(\.managedObjectContext) private var viewContext

    var timePeriod: TimePeriod
    var customDateRange: ClosedRange<Date>

    @State private var data: [RestTimeData] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Rest Time Insights")
                .font(.headline)

            Chart {
                ForEach(data) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Average Rest Time", dataPoint.averageRestTime)
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Handle drag gesture if needed
                                }
                        )
                }
            }
            .onAppear(perform: fetchData)
            .onChange(of: timePeriod) { _ in fetchData() }
            .onChange(of: customDateRange) { _ in fetchData() }
        }
    }

    private func fetchData() {
        let fetchRequest: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        let dateRange = timePeriod == .custom ? customDateRange : timePeriod.dateRange()
        fetchRequest.predicate = NSPredicate(format: "note.date >= %@ AND note.date <= %@", dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let results = try viewContext.fetch(fetchRequest)
            let groupedData = Dictionary(grouping: results, by: { Calendar.current.startOfDay(for: $0.note?.date ?? Date()) })

            data = groupedData.map { (date, trainings) in
                let totalRestTime = trainings.reduce(0) { $0 + ($1.restTimeInSecondsBeforeCurrentSetOptional?.doubleValue ?? 0) }
                let averageRestTime = totalRestTime / Double(trainings.count)
                return RestTimeData(date: date, averageRestTime: averageRestTime)
            }
            .sorted { $0.date < $1.date }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}

struct RestTimeData: Identifiable {
    var id = UUID()
    var date: Date
    var averageRestTime: Double
}

////OLD INSIGHTS VIEW SWIFT CODE
//import SwiftUI
//import CoreData
//import HealthKit
//import Charts
//
//// Extend HKSample to conform to Identifiable
//extension HKSample: Identifiable {
//    public var id: UUID {
//        return self.uuid
//    }
//}
//
//// Define data structures for aggregated health data
//struct HeartRateDataPoint: Identifiable {
//    let id = UUID()
//    let date: Date
//    let averageHeartRate: Double
//}
//
//struct StepCountDataPoint: Identifiable {
//    let id = UUID()
//    let date: Date
//    let totalSteps: Double
//}
//
//struct SleepDataPoint: Identifiable {
//    let id = UUID()
//    let date: Date
//    let totalSleep: Double // Total sleep in hours
//}
//
//struct AlignedDataPoint {
//    let date: Date
//    let value1: Double
//    let value2: Double
//}
//
//struct InsightsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//
//    // Existing state variables
//    @State private var selectedTimeFrame: TimeFrame = .lastWeek
//    @State private var symptomFrequencyData: [SymptomFrequency] = []
//
//    // New state variables for HealthKit data
//    @State private var heartRateSamples: [HKQuantitySample] = []
//    @State private var stepCountSamples: [HKQuantitySample] = []
//    @State private var sleepSamples: [HKCategorySample] = []
//    @State private var isAuthorized = false
//
//    // State variables for correlation and Chi-Squared
//    @State private var selectedDataType1: DataType = .symptom
//    @State private var selectedDataType2: DataType = .sleep
//    @State private var correlationResult: Double?
//    @State private var showChiSquared = false
//    @State private var chiSquaredResult: (statistic: Double, interpretation: String)?
//
//    // Lists for symptoms, contexts, medications
//    @State private var symptomList: [String] = []
//    @State private var contextList: [String] = []
//    @State private var medicationList: [String] = []
//
//    // Selected specific items (made non-optional)
//    @State private var selectedItem1: String = ""
//    @State private var selectedItem2: String = ""
//
//    // HealthStore instance
//    private var healthStore = HealthStore()
//
//    var body: some View {
//        ScrollView {
//            VStack {
//                // Picker to select time frame
//                Picker("Select Time Frame", selection: $selectedTimeFrame) {
//                    ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
//                        Text(timeFrame.displayName).tag(timeFrame)
//                    }
//                }
//                .pickerStyle(SegmentedPickerStyle())
//                .padding()
//
//                // Data Type Pickers
//                VStack {
//                    HStack {
//                        Picker("Select Data Type 1", selection: $selectedDataType1) {
//                            ForEach(DataType.allCases) { dataType in
//                                Text(dataType.displayName).tag(dataType)
//                            }
//                        }
//                        .pickerStyle(MenuPickerStyle())
//
//                        if let items = getItems(for: selectedDataType1), !items.isEmpty {
//                            Picker("Select Item", selection: $selectedItem1) {
//                                ForEach(items, id: \.self) { item in
//                                    Text(item).tag(item)
//                                }
//                            }
//                            .pickerStyle(MenuPickerStyle())
//                            .onAppear {
//                                if selectedItem1.isEmpty {
//                                    selectedItem1 = items.first ?? ""
//                                }
//                            }
//                        }
//                    }
//                    .padding()
//
//                    HStack {
//                        Picker("Select Data Type 2", selection: $selectedDataType2) {
//                            ForEach(DataType.allCases) { dataType in
//                                Text(dataType.displayName).tag(dataType)
//                            }
//                        }
//                        .pickerStyle(MenuPickerStyle())
//
//                        if let items = getItems(for: selectedDataType2), !items.isEmpty {
//                            Picker("Select Item", selection: $selectedItem2) {
//                                ForEach(items, id: \.self) { item in
//                                    Text(item).tag(item)
//                                }
//                            }
//                            .pickerStyle(MenuPickerStyle())
//                            .onAppear {
//                                if selectedItem2.isEmpty {
//                                    selectedItem2 = items.first ?? ""
//                                }
//                            }
//                        }
//                    }
//                    .padding()
//                }
//
//                // Toggle to select between correlation and Chi-Squared
//                Toggle("Use Chi-Squared Test", isOn: $showChiSquared)
//                    .padding()
//
//                // Button to compute correlation or Chi-Squared
//                Button("Compute Analysis") {
//                    if showChiSquared {
//                        computeChiSquared()
//                    } else {
//                        computeCorrelation()
//                    }
//                }
//                .padding()
//
//                // Display correlation or Chi-Squared result
//                if showChiSquared, let chiSquared = chiSquaredResult {
//                    Text("Chi-Squared: \(chiSquared.statistic, specifier: "%.2f")")
//                        .font(.headline)
//                        .padding()
//                    Text(chiSquared.interpretation)
//                        .padding()
//                } else if let correlation = correlationResult {
//                    Text("Correlation: \(correlation, specifier: "%.2f")")
//                        .font(.headline)
//                        .padding()
//                }
//
//                // Symptom Frequency Chart
//                if symptomFrequencyData.isEmpty {
//                    Text("No symptom data available for the selected timeframe.")
//                        .foregroundColor(.gray)
//                        .padding(.top, 50)
//                } else {
//                    Chart {
//                        ForEach(symptomFrequencyData) { data in
//                            BarMark(
//                                x: .value("Symptom", data.symptom),
//                                y: .value("Frequency", data.frequency)
//                            )
//                        }
//                    }
//                    .frame(height: 300)
//                    .padding()
//                }
//
//                // Health Data Section
//                if isAuthorized {
//                    healthDataSection
//                } else {
//                    Text("Please authorize HealthKit access to view health data.")
//                        .padding()
//                }
//            }
//            .navigationTitle("Insights")
//            .onAppear {
//                healthStore.requestAuthorization { success in
//                    DispatchQueue.main.async {
//                        if success {
//                            isAuthorized = true
//                            fetchHealthData()
//                        } else {
//                            isAuthorized = false
//                            print("HealthKit authorization denied.")
//                        }
//                    }
//                }
//                fetchSymptomData()
//                fetchContextList()
//                fetchMedicationList()
//            }
//            .onChange(of: selectedTimeFrame) { _ in
//                fetchSymptomData()
//                if isAuthorized {
//                    fetchHealthData()
//                }
//            }
//        }
//    }
//
//    // Helper function to get items based on selected data type
//    private func getItems(for dataType: DataType) -> [String]? {
//        switch dataType {
//        case .symptom:
//            return symptomList
//        case .context:
//            return contextList
//        case .medication:
//            return medicationList
//        default:
//            return nil
//        }
//    }
//
//    private func computeCorrelation() {
//        let data1 = fetchDataPoints(for: selectedDataType1, selectedItem: selectedItem1)
//        let data2 = fetchDataPoints(for: selectedDataType2, selectedItem: selectedItem2)
//
//        let alignedData = alignDataPoints(data1: data1, data2: data2)
//
//        if alignedData.count > 1 {
//            let values1 = alignedData.map { $0.value1 }
//            let values2 = alignedData.map { $0.value2 }
//            correlationResult = calculateCorrelation(x: values1, y: values2)
//        } else {
//            correlationResult = nil
//        }
//    }
//
//    private func computeChiSquared() {
//        let data1 = fetchDataPoints(for: selectedDataType1, selectedItem: selectedItem1)
//        let data2 = fetchDataPoints(for: selectedDataType2, selectedItem: selectedItem2)
//
//        let alignedData = alignDataPoints(data1: data1, data2: data2)
//
//        if alignedData.count > 1 {
//            let values1 = alignedData.map { $0.value1 }
//            let values2 = alignedData.map { $0.value2 }
//
//            chiSquaredResult = calculateChiSquared(x: values1, y: values2)
//        } else {
//            chiSquaredResult = nil
//        }
//    }
//
//    private func calculateChiSquared(x: [Double], y: [Double], numBins: Int = 3) -> (statistic: Double, interpretation: String) {
//        let xBinned = binData(x, numBins: numBins)
//        let yBinned = binData(y, numBins: numBins)
//
//        let contingencyTable = createContingencyTable(xBinned: xBinned, yBinned: yBinned, numBins: numBins)
//
//        var chiSquared: Double = 0
//        let rowTotals = contingencyTable.map { $0.reduce(0, +) }
//        let colTotals = (0..<numBins).map { col in contingencyTable.reduce(0) { $0 + $1[col] } }
//        let total = Double(x.count)
//
//        for i in 0..<numBins {
//            for j in 0..<numBins {
//                let expected = Double(rowTotals[i]) * Double(colTotals[j]) / total
//                if expected > 0 {
//                    chiSquared += pow(Double(contingencyTable[i][j]) - expected, 2) / expected
//                }
//            }
//        }
//
//        let interpretation: String
//        if chiSquared > 5.99 { // Approx. critical value for 2 degrees of freedom, p < 0.05
//            interpretation = "There is a statistically significant association between the selected variables."
//        } else {
//            interpretation = "No statistically significant association detected between the selected variables."
//        }
//
//        return (chiSquared, interpretation)
//    }
//
//    private func binData(_ data: [Double], numBins: Int) -> [Int] {
//        guard let minVal = data.min(), let maxVal = data.max(), minVal < maxVal else {
//            return Array(repeating: 0, count: data.count)
//        }
//
//        let binWidth = (maxVal - minVal) / Double(numBins)
//        return data.map { Int(($0 - minVal) / binWidth) }
//    }
//
//    private func createContingencyTable(xBinned: [Int], yBinned: [Int], numBins: Int) -> [[Int]] {
//        var table = Array(repeating: Array(repeating: 0, count: numBins), count: numBins)
//        for (xCategory, yCategory) in zip(xBinned, yBinned) {
//            if xCategory < numBins && yCategory < numBins {
//                table[xCategory][yCategory] += 1
//            }
//        }
//        return table
//    }
//
//    // Fetch symptom frequency data and list of symptoms
//    private func fetchSymptomData() {
//        let now = Date()
//        let startDate = selectedTimeFrame.startDate
//
//        let request: NSFetchRequest<Symptom> = Symptom.fetchRequest()
//        request.predicate = NSPredicate(format: "timestamp >= %@ && timestamp <= %@", startDate as NSDate, now as NSDate)
//
//        do {
//            let symptoms = try viewContext.fetch(request)
//
//            // Grouping by symptom
//            let frequencyDict = Dictionary(grouping: symptoms, by: { $0.symptom ?? "Unspecified" })
//                .map { SymptomFrequency(symptom: $0.key, frequency: $0.value.count) }
//
//            // Sort by frequency
//            symptomFrequencyData = frequencyDict.sorted(by: { $0.frequency > $1.frequency })
//
//            // Get unique symptom list
//            symptomList = Set(symptoms.compactMap { $0.symptom }).sorted()
//
//            // Set default selection if needed
//            if selectedDataType1 == .symptom && selectedItem1.isEmpty {
//                selectedItem1 = symptomList.first ?? ""
//            }
//            if selectedDataType2 == .symptom && selectedItem2.isEmpty {
//                selectedItem2 = symptomList.first ?? ""
//            }
//        } catch {
//            print("Error fetching symptom data: \(error.localizedDescription)")
//            symptomFrequencyData = []
//        }
//    }
//
//    private func fetchContextList() {
//        let request: NSFetchRequest<Context> = Context.fetchRequest()
//        do {
//            let contexts = try viewContext.fetch(request)
//            contextList = Set(contexts.compactMap { $0.specificContextDetail }).sorted()
//
//            // Set default selection if needed
//            if selectedDataType1 == .context && selectedItem1.isEmpty {
//                selectedItem1 = contextList.first ?? ""
//            }
//            if selectedDataType2 == .context && selectedItem2.isEmpty {
//                selectedItem2 = contextList.first ?? ""
//            }
//        } catch {
//            print("Error fetching context data: \(error.localizedDescription)")
//            contextList = []
//        }
//    }
//
//    private func fetchMedicationList() {
//        let request: NSFetchRequest<Medication> = Medication.fetchRequest()
//        do {
//            let medications = try viewContext.fetch(request)
//            medicationList = Set(medications.compactMap { $0.medicationName }).sorted()
//
//            // Set default selection if needed
//            if selectedDataType1 == .medication && selectedItem1.isEmpty {
//                selectedItem1 = medicationList.first ?? ""
//            }
//            if selectedDataType2 == .medication && selectedItem2.isEmpty {
//                selectedItem2 = medicationList.first ?? ""
//            }
//        } catch {
//            print("Error fetching medication data: \(error.localizedDescription)")
//            medicationList = []
//        }
//    }
//
//    // Fetch HealthKit data
//    private func fetchHealthData() {
//        fetchHeartRateData()
//        fetchStepCountData()
//        fetchSleepData()
//    }
//
//    private func fetchHeartRateData() {
//        healthStore.fetchHeartRateData(timeFrame: selectedTimeFrame) { samples in
//            DispatchQueue.main.async {
//                self.heartRateSamples = samples ?? []
//            }
//        }
//    }
//
//    private func fetchStepCountData() {
//        healthStore.fetchStepCountData(timeFrame: selectedTimeFrame) { samples in
//            DispatchQueue.main.async {
//                self.stepCountSamples = samples ?? []
//            }
//        }
//    }
//
//    private func fetchSleepData() {
//        healthStore.fetchSleepAnalysis(timeFrame: selectedTimeFrame) { samples in
//            DispatchQueue.main.async {
//                self.sleepSamples = samples ?? []
//            }
//        }
//    }
//
//    private func computePearsonCorrelation() {
//        let data1 = fetchDataPoints(for: selectedDataType1, selectedItem: selectedItem1)
//        let data2 = fetchDataPoints(for: selectedDataType2, selectedItem: selectedItem2)
//
//        let alignedData = alignDataPoints(data1: data1, data2: data2)
//
//        if alignedData.count > 1 {
//            let values1 = alignedData.map { $0.value1 }
//            let values2 = alignedData.map { $0.value2 }
//            correlationResult = calculateCorrelation(x: values1, y: values2)
//        } else {
//            correlationResult = nil
//        }
//    }
//
//    private func fetchDataPoints(for dataType: DataType, selectedItem: String) -> [Date: Double] {
//        let calendar = Calendar.current
//        switch dataType {
//        case .symptom:
//            let symptom = selectedItem
//            let now = Date()
//            let startDate = selectedTimeFrame.startDate
//
//            let request: NSFetchRequest<Symptom> = Symptom.fetchRequest()
//            request.predicate = NSPredicate(format: "timestamp >= %@ && timestamp <= %@ && symptom == %@", startDate as NSDate, now as NSDate, symptom)
//
//            do {
//                let symptoms = try viewContext.fetch(request)
//                let groupedSymptoms = Dictionary(grouping: symptoms) { sample -> Date in
//                    return calendar.startOfDay(for: sample.timestamp ?? Date())
//                }
//                let dataPoints = groupedSymptoms.mapValues { samples -> Double in
//                    return Double(samples.count)
//                }
//                return dataPoints
//            } catch {
//                print("Error fetching symptom data: \(error.localizedDescription)")
//                return [:]
//            }
//        case .context:
//            let contextDetail = selectedItem
//            let now = Date()
//            let startDate = selectedTimeFrame.startDate
//
//            let request: NSFetchRequest<Context> = Context.fetchRequest()
//            request.predicate = NSPredicate(format: "date >= %@ && date <= %@ && specificContextDetail == %@", startDate as NSDate, now as NSDate, contextDetail)
//
//            do {
//                let contexts = try viewContext.fetch(request)
//                let groupedContexts = Dictionary(grouping: contexts) { sample -> Date in
//                    return calendar.startOfDay(for: sample.date ?? Date())
//                }
//                let dataPoints = groupedContexts.mapValues { samples -> Double in
//                    return Double(samples.count)
//                }
//                return dataPoints
//            } catch {
//                print("Error fetching context data: \(error.localizedDescription)")
//                return [:]
//            }
//        case .medication:
//            let medicationName = selectedItem
//            let now = Date()
//            let startDate = selectedTimeFrame.startDate
//
//            let request: NSFetchRequest<Medication> = Medication.fetchRequest()
//            request.predicate = NSPredicate(format: "date >= %@ && date <= %@ && medicationName == %@", startDate as NSDate, now as NSDate, medicationName)
//
//            do {
//                let medications = try viewContext.fetch(request)
//                let groupedMedications = Dictionary(grouping: medications) { sample -> Date in
//                    return calendar.startOfDay(for: sample.date ?? Date())
//                }
//                let dataPoints = groupedMedications.mapValues { samples -> Double in
//                    return Double(samples.count)
//                }
//                return dataPoints
//            } catch {
//                print("Error fetching medication data: \(error.localizedDescription)")
//                return [:]
//            }
//        case .sleep:
//            let sleepData = aggregateSleepData(samples: sleepSamples)
//            let dataPoints = Dictionary(uniqueKeysWithValues: sleepData.map { ($0.date, $0.totalSleep) })
//            return dataPoints
//        case .heartRate:
//            let heartRateData = aggregateHeartRateData(samples: heartRateSamples)
//            let dataPoints = Dictionary(uniqueKeysWithValues: heartRateData.map { ($0.date, $0.averageHeartRate) })
//            return dataPoints
//        case .stepCount:
//            let stepData = aggregateStepCountData(samples: stepCountSamples)
//            let dataPoints = Dictionary(uniqueKeysWithValues: stepData.map { ($0.date, $0.totalSteps) })
//            return dataPoints
//        }
//    }
//
//    private func alignDataPoints(data1: [Date: Double], data2: [Date: Double]) -> [AlignedDataPoint] {
//        let dates = Set(data1.keys).intersection(Set(data2.keys))
//        let alignedData = dates.map { date -> AlignedDataPoint in
//            return AlignedDataPoint(date: date, value1: data1[date]!, value2: data2[date]!)
//        }
//        return alignedData.sorted { $0.date < $1.date }
//    }
//
//    private func calculateCorrelation(x: [Double], y: [Double]) -> Double {
//        let n = Double(x.count)
//        let sumX = x.reduce(0, +)
//        let sumY = y.reduce(0, +)
//        let sumXY = zip(x, y).map(*).reduce(0, +)
//        let sumXSquare = x.map { $0 * $0 }.reduce(0, +)
//        let sumYSquare = y.map { $0 * $0 }.reduce(0, +)
//
//        let numerator = n * sumXY - sumX * sumY
//        let denominator = sqrt((n * sumXSquare - sumX * sumX) * (n * sumYSquare - sumY * sumY))
//
//        if denominator == 0 {
//            return 0
//        } else {
//            return numerator / denominator
//        }
//    }
//
//    private var healthDataSection: some View {
//        VStack(alignment: .leading) {
//            Text("Health Data")
//                .font(.headline)
//                .padding(.top)
//
//            // Heart Rate Chart
//            if !heartRateSamples.isEmpty {
//                let aggregatedData = aggregateHeartRateData(samples: heartRateSamples)
//                Text("Average Heart Rate")
//                    .font(.subheadline)
//                Chart(aggregatedData) { dataPoint in
//                    LineMark(
//                        x: .value("Date", dataPoint.date),
//                        y: .value("Heart Rate (bpm)", dataPoint.averageHeartRate)
//                    )
//                }
//                .frame(height: 200)
//            } else {
//                Text("No heart rate data available for selected time frame.")
//                    .foregroundColor(.gray)
//            }
//
//            // Step Count Chart
//            if !stepCountSamples.isEmpty {
//                let aggregatedData = aggregateStepCountData(samples: stepCountSamples)
//                Text("Total Steps")
//                    .font(.subheadline)
//                Chart(aggregatedData) { dataPoint in
//                    BarMark(
//                        x: .value("Date", dataPoint.date),
//                        y: .value("Steps", dataPoint.totalSteps)
//                    )
//                }
//                .frame(height: 200)
//            } else {
//                Text("No step count data available for selected time frame.")
//                    .foregroundColor(.gray)
//            }
//
//            // Sleep Data Chart
//            if !sleepSamples.isEmpty {
//                let aggregatedData = aggregateSleepData(samples: sleepSamples)
//                Text("Total Sleep")
//                    .font(.subheadline)
//                Chart(aggregatedData) { dataPoint in
//                    BarMark(
//                        x: .value("Date", dataPoint.date),
//                        y: .value("Sleep Hours", dataPoint.totalSleep)
//                    )
//                }
//                .frame(height: 200)
//            } else {
//                Text("No sleep data available for selected time frame.")
//                    .foregroundColor(.gray)
//            }
//        }
//        .padding()
//    }
//
//    // Aggregation functions
//    private func aggregateHeartRateData(samples: [HKQuantitySample]) -> [HeartRateDataPoint] {
//        let calendar = Calendar.current
//        let groupedSamples = Dictionary(grouping: samples) { sample -> Date in
//            // Group by day
//            return calendar.startOfDay(for: sample.startDate)
//        }
//        let dataPoints = groupedSamples.map { (date, samples) -> HeartRateDataPoint in
//            let averageHeartRate = samples.map {
//                $0.quantity.doubleValue(for: HKUnit(from: "count/min"))
//            }.reduce(0, +) / Double(samples.count)
//            return HeartRateDataPoint(date: date, averageHeartRate: averageHeartRate)
//        }
//        return dataPoints.sorted { $0.date < $1.date }
//    }
//
//    private func aggregateStepCountData(samples: [HKQuantitySample]) -> [StepCountDataPoint] {
//        let calendar = Calendar.current
//        let groupedSamples = Dictionary(grouping: samples) { sample -> Date in
//            // Group by day
//            return calendar.startOfDay(for: sample.startDate)
//        }
//        let dataPoints = groupedSamples.map { (date, samples) -> StepCountDataPoint in
//            let totalSteps = samples.map {
//                $0.quantity.doubleValue(for: .count())
//            }.reduce(0, +)
//            return StepCountDataPoint(date: date, totalSteps: totalSteps)
//        }
//        return dataPoints.sorted { $0.date < $1.date }
//    }
//
//    private func aggregateSleepData(samples: [HKCategorySample]) -> [SleepDataPoint] {
//        let calendar = Calendar.current
//        // Group samples by day
//        let groupedSamples = Dictionary(grouping: samples) { sample -> Date in
//            return calendar.startOfDay(for: sample.startDate)
//        }
//
//        let dataPoints = groupedSamples.map { (date, samples) -> SleepDataPoint in
//            // For each day, get all intervals
//            let intervals = samples.map { sample in
//                return (start: sample.startDate, end: sample.endDate)
//            }.sorted { $0.start < $1.start }
//
//            // Merge overlapping intervals to avoid double-counting
//            var mergedIntervals: [(start: Date, end: Date)] = []
//            for interval in intervals {
//                if let lastInterval = mergedIntervals.last, interval.start <= lastInterval.end {
//                    // Overlapping intervals, merge them
//                    let newEnd = max(lastInterval.end, interval.end)
//                    mergedIntervals[mergedIntervals.count - 1] = (start: lastInterval.start, end: newEnd)
//                } else {
//                    // No overlap, add interval
//                    mergedIntervals.append(interval)
//                }
//            }
//
//            // Sum durations of merged intervals
//            let totalSleep = mergedIntervals.reduce(0) { (result, interval) -> TimeInterval in
//                return result + interval.end.timeIntervalSince(interval.start)
//            }
//
//            return SleepDataPoint(date: date, totalSleep: totalSleep / 3600) // Convert to hours
//        }
//        return dataPoints.sorted { $0.date < $1.date }
//    }
//}
//
//// Define TimeFrame enum to toggle between time ranges
//enum TimeFrame: Hashable, CaseIterable {
//    case lastDay
//    case lastWeek
//    case lastMonth
//    case lastYear
//
//    static var allCases: [TimeFrame] {
//        return [.lastDay, .lastWeek, .lastMonth, .lastYear]
//    }
//
//    var displayName: String {
//        switch self {
//        case .lastDay:
//            return "Last Day"
//        case .lastWeek:
//            return "Last Week"
//        case .lastMonth:
//            return "Last Month"
//        case .lastYear:
//            return "Last Year"
//        }
//    }
//
//    var startDate: Date {
//        let calendar = Calendar.current
//        let now = Date()
//        switch self {
//        case .lastDay:
//            return calendar.date(byAdding: .day, value: -1, to: now)!
//        case .lastWeek:
//            return calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
//        case .lastMonth:
//            return calendar.date(byAdding: .month, value: -1, to: now)!
//        case .lastYear:
//            return calendar.date(byAdding: .year, value: -1, to: now)!
//        }
//    }
//}
//
//// Data structure for Symptom Frequency
//struct SymptomFrequency: Identifiable {
//    let id = UUID()
//    let symptom: String
//    let frequency: Int
//}
//
//// DataType enum for selecting data types
//enum DataType: String, CaseIterable, Identifiable {
//    case symptom
//    case context
//    case medication
//    case sleep
//    case heartRate
//    case stepCount
//
//    var id: String { self.rawValue }
//
//    var displayName: String {
//        switch self {
//        case .symptom: return "Symptom"
//        case .context: return "Context"
//        case .medication: return "Medication"
//        case .sleep: return "Sleep"
//        case .heartRate: return "Heart Rate"
//        case .stepCount: return "Step Count"
//        }
//    }
//}
//
//// Preview
//struct InsightsView_Previews: PreviewProvider {
//    static var previews: some View {
//        InsightsView()
//            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//    }
//}
//
////
////  HealthStore.swift
////  SymptomScribe
////
////  Created by Aashni Shah on 10/1/24.
////
//
//import Foundation
//import HealthKit
//
//class HealthStore {
//    let healthStore = HKHealthStore()
//
//    // Define the data types you want to read
//    var readDataTypes: Set<HKObjectType> {
//        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
//        let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!
//        let sleepAnalysisType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
//
//        return [heartRateType, stepCountType, sleepAnalysisType]
//    }
//
//    func requestAuthorization(completion: @escaping (Bool) -> Void) {
//        if HKHealthStore.isHealthDataAvailable() {
//            healthStore.requestAuthorization(toShare: nil, read: readDataTypes) { (success, error) in
//                if let error = error {
//                    print("HealthKit authorization error: \(error.localizedDescription)")
//                }
//                completion(success)
//            }
//        } else {
//            print("Health data not available on this device.")
//            completion(false)
//        }
//    }
//
//    func fetchHeartRateData(timeFrame: TimeFrame, completion: @escaping ([HKQuantitySample]?) -> Void) {
//        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
//        let predicate = HKQuery.predicateForSamples(withStart: timeFrame.startDate, end: Date(), options: [])
//
//        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
//            if let error = error {
//                print("Error fetching heart rate samples: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//            if let samples = samples as? [HKQuantitySample] {
//                completion(samples)
//            } else {
//                completion(nil)
//            }
//        }
//        healthStore.execute(query)
//    }
//
//    func fetchStepCountData(timeFrame: TimeFrame, completion: @escaping ([HKQuantitySample]?) -> Void) {
//        let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
//        let predicate = HKQuery.predicateForSamples(withStart: timeFrame.startDate, end: Date(), options: [])
//
//        let query = HKSampleQuery(sampleType: stepCountType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
//            if let error = error {
//                print("Error fetching step count samples: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//            if let samples = samples as? [HKQuantitySample] {
//                completion(samples)
//            } else {
//                completion(nil)
//            }
//        }
//        healthStore.execute(query)
//    }
//
//    func fetchSleepAnalysis(timeFrame: TimeFrame, completion: @escaping ([HKCategorySample]?) -> Void) {
//        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
//        let datePredicate = HKQuery.predicateForSamples(withStart: timeFrame.startDate, end: Date(), options: [])
//        let asleepPredicate = HKQuery.predicateForCategorySamples(with: .equalTo, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
//        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, asleepPredicate])
//
//        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
//            if let error = error {
//                print("Error fetching sleep samples: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//            if let samples = samples as? [HKCategorySample] {
//                completion(samples)
//            } else {
//                completion(nil)
//            }
//        }
//        healthStore.execute(query)
//    }
//}
