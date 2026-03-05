import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct EkipView: View {
    // Data source for the list
    @State private var entries: [(name: String, initial: String)] = []

    // Sheet presentation state
    @State private var showingEntrySheet: Bool = false

    @AppStorage("userInitials") private var storedInitials: String = ""
    @AppStorage("userName") private var storedName: String = ""

    // Editing buffers
    @State private var initials: String = ""
    @State private var name: String = ""

    // Validation
    private var isInitialsValid: Bool {
        let trimmed = initials.trimmingCharacters(in: .whitespacesAndNewlines)
        // Exactly 2 English letters (A-Z), case-insensitive
        let pattern = "^[A-Za-z]{2}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item.initial)
                                .font(.headline)
                                .monospaced()
                            Text(item.name)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                // Haptic feedback
                                #if os(iOS)
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                #endif
                                if index < entries.count {
                                    entries.remove(at: index)
                                    saveEntriesToFile()
                                    updateUserInitialsCSVFromEntries()
                                }
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        // Map indices from enumerated ForEach
                        let indices = Array(indexSet)
                        // Remove in reverse order to keep indices valid
                        for i in indices.sorted(by: >) {
                            if i < entries.count {
                                entries.remove(at: i)
                            }
                        }
                        saveEntriesToFile()
                        updateUserInitialsCSVFromEntries()
                    }
                    .onMove { indices, newOffset in
                        entries.move(fromOffsets: indices, toOffset: newOffset)
                        saveEntriesToFile()
                        updateUserInitialsCSVFromEntries()
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, .constant(.active))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Ekip Sayısı: \(entries.count)")
                    .font(.headline)
                    .bold()
                    .font(.system(size: 36))
                    .foregroundStyle(.primary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingEntrySheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.blue)
                        .background(Circle().stroke(style: StrokeStyle(lineWidth: 0)))
                }
                .accessibilityLabel("Yeni kayıt ekle")
            }
        }
        .sheet(isPresented: $showingEntrySheet) {
            EkipEntryView() { name, initial in
                entries.append((name: name, initial: initial))
                saveEntriesToFile()
                updateUserInitialsCSVFromEntries()
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
    
    private func updateUserInitialsCSVFromEntries() {
        let csv = entries
            .map { $0.initial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        UserDefaults.standard.set(csv, forKey: "userInitials")
    }
    
    private func saveEntriesToFile() {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return }
        let fileURL = documentsURL.appendingPathComponent("ekip.txt")

        let content = entries.map { "\($0.name)\t\($0.initial)" }.joined(separator: "\n") + "\n"
        do {
            try content.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            updateUserInitialsCSVFromEntries()
        } catch {
            print("Dosyaya yazma hatası (save): \(error)")
        }
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
                Section(header: Text("")) {
                    TextField("Initial", text: $initial)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: initial) { _, newValue in
                            // Allow only English letters A-Z, uppercase, max 2 chars
                            let filtered = newValue
                                .uppercased()
                                .filter { $0 >= "A" && $0 <= "Z" }
                            if filtered.count > 2 {
                                initial = String(filtered.prefix(2))
                            } else if filtered != newValue {
                                initial = filtered
                            }
                        }
                    TextField("Adı", text: $name)
                        .textInputAutocapitalization(.words)
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

