import SwiftUI
import CoreData

struct NotesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>
    
    var body: some View {
        List {
            if notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No recordings yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Record your first symptom entry using the Record tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .listRowBackground(Color.clear)
            } else {
                ForEach(notes) { note in
                    NavigationLink(destination: SymptomDetailView(note: note)) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Summary with symptom count
                            HStack {
                                Text(note.summary ?? "No Summary")
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Badge showing number of detected symptoms
                                if let symptoms = note.symptoms as? Set<Symptom> {
                                    let presentCount = symptoms.filter { $0.isPresent }.count
                                    if presentCount > 0 {
                                        Text("\(presentCount)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            
                            // Date and time
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(note.date ?? Date(), style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                Text(note.date ?? Date(), style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Preview of transcribed text
                            if let transcript = note.transcribedText, !transcript.isEmpty {
                                Text(transcript)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("My Recordings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Delete error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct NotesListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        NotesListView()
            .environment(\.managedObjectContext, context)
    }
}
