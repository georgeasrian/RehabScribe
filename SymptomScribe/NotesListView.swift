//
//  NotesListView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//

import SwiftUI
import CoreData

struct NotesListView: View {
    // Accessing the managed object context
    @Environment(\.managedObjectContext) private var viewContext

    // FetchRequest to retrieve all Note entities, sorted by date descending
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>

    var body: some View {
        List {
            if notes.isEmpty {
                Text("No notes available.")
                    .foregroundColor(.gray)
            } else {
                ForEach(notes) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        VStack(alignment: .leading) {
                            Text(note.summary ?? "No Summary")
                                .font(.headline)
                                .lineLimit(1)
                            Text(note.date ?? Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("My Notes") // Single navigation title
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: addNote) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // Function to add a new note
    private func addNote() {
        let newNote = Note(context: viewContext)
        newNote.date = Date()
        newNote.transcribedText = ""
        newNote.summary = ""

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    // Function to delete notes
    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct NotesListView_Previews: PreviewProvider {
    static var previews: some View {
        // Using PersistenceController's preview for SwiftUI previews
        let context = PersistenceController.preview.container.viewContext
        NotesListView()
            .environment(\.managedObjectContext, context)
    }
}
