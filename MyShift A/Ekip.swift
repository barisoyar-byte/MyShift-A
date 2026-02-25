import SwiftUI

struct EkipView: View {
    @State private var showingEntrySheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [(name: String, initial: String)] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 16) {
                    Text("Initials")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            } else {
                List {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.initial)
                                .font(.headline)
                                .monospaced()
                            Text(item.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingEntrySheet = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Yeni kayıt ekle")
            }
        }
        .sheet(isPresented: $showingEntrySheet) {
            EkipEntryView() { name, initial in
                entries.append((name: name, initial: initial))
            }
        }
        .task { loadEntriesFromFile() }
    }

    private func loadEntriesFromFile() {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return }
        let fileURL = documentsURL.appendingPathComponent("ekip.txt")
        guard let data = try? Data(contentsOf: fileURL), let content = String(data: data, encoding: .utf8) else { return }

        var loaded: [(name: String, initial: String)] = []
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let name = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let initial = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !initial.isEmpty {
                    loaded.append((name: name, initial: initial))
                }
            }
        }
        entries = loaded
    }
}

struct EkipEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var initial: String = ""

    var onSaved: ((String, String) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Bilgiler")) {
                    TextField("Adı", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Initial", text: $initial)
                        .textInputAutocapitalization(.characters)
                }
            }
            .navigationTitle("Yeni Kayıt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { saveAndDismiss() }
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            initial.trimmingCharacters(in: .whitespacesAndNewlines).count != 2
                        )
                }
            }
        }
    }

    private func saveAndDismiss() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitial = initial.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = "\(trimmedName)\t\(trimmedInitial)\n"
        do {
            try appendLineToDocumentsFile(named: "ekip.txt", line: line)
            onSaved?(trimmedName, trimmedInitial)
            dismiss()
        } catch {
            // You could present an alert; for now, print error
            print("Dosyaya yazma hatası: \(error)")
        }
    }

    private func appendLineToDocumentsFile(named fileName: String, line: String) throws {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { throw NSError(domain: "EkipEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents dizini bulunamadı"]) }
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let data = Data(line.utf8)
        if fm.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                // Fallback: rewrite whole file if handle can't be opened
                let existing = (try? Data(contentsOf: fileURL)) ?? Data()
                try (existing + data).write(to: fileURL, options: .atomic)
            }
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }
}

#Preview {
    NavigationStack { EkipView() }
}

