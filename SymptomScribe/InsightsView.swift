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

