import SwiftUI
import SwiftData

struct MedicationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let medication: Medication?

    @State private var name: String
    @State private var times: [TimeEntry]
    @State private var useCutoff: Bool
    @State private var cutoff: Date
    @State private var trackRemaining: Bool
    @State private var remaining: Int

    init(medication: Medication?) {
        self.medication = medication
        _name = State(initialValue: medication?.name ?? "")
        let minutes = medication?.timesMinutes ?? [8 * 60]
        _times = State(initialValue: minutes.map { TimeEntry(date: Self.date(minutes: $0)) })
        _useCutoff = State(initialValue: medication?.cutoffMinutes != nil)
        _cutoff = State(initialValue: Self.date(minutes: medication?.cutoffMinutes ?? 15 * 60))
        _trackRemaining = State(initialValue: medication?.remainingCount != nil)
        _remaining = State(initialValue: medication?.remainingCount ?? 30)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("약 이름") {
                    TextField("예: 아침 ADHD 약", text: $name)
                }

                Section {
                    ForEach($times) { $entry in
                        DatePicker("시간", selection: $entry.date, displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }
                    Button("시간 추가") { times.append(TimeEntry(date: Self.date(minutes: 12 * 60))) }
                } header: {
                    Text("먹는 시간")
                } footer: {
                    Text("처방받은 대로 입력해 주세요. 콩이는 용량이나 시간을 추천하지 않아요.")
                }

                Section {
                    Toggle("늦은 복용 마감 시간", isOn: $useCutoff)
                    if useCutoff {
                        DatePicker("이 시간 이후엔 알림 끄기", selection: $cutoff, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("늦게 먹으면 잠들기 어려운 약이라면 의사와 정한 시간을 넣어 주세요. 이 시간이 지나면 다시 알리지 않아요.")
                }

                Section {
                    Toggle("남은 약 개수 세기", isOn: $trackRemaining)
                    if trackRemaining {
                        Stepper("남은 개수: \(remaining)개", value: $remaining, in: 0...999)
                    }
                } footer: {
                    Text("\(DoseRules.refillWarningDays)일분 이하로 남으면 처방 받을 때라고 알려 줄게요.")
                }

                if medication != nil {
                    Section {
                        Button("이 약 삭제", role: .destructive, action: delete)
                    }
                }
            }
            .navigationTitle(medication == nil ? "약 추가" : "약 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || times.isEmpty)
                }
            }
        }
    }

    private func save() {
        let minutes = Array(Set(times.map { DoseRules.minutesOfDay($0.date) })).sorted()
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let cutoffMinutes = useCutoff ? DoseRules.minutesOfDay(cutoff) : nil
        let count = trackRemaining ? remaining : nil

        if let medication {
            medication.name = trimmed
            medication.timesMinutes = minutes
            medication.cutoffMinutes = cutoffMinutes
            medication.remainingCount = count
        } else {
            context.insert(Medication(name: trimmed, timesMinutes: minutes, cutoffMinutes: cutoffMinutes, remainingCount: count))
        }
        try? context.save()

        Task {
            await ReminderScheduler.shared.requestAuthorization()
            await AppModel.shared.refreshExternal()
        }
        dismiss()
    }

    private func delete() {
        if let medication {
            context.delete(medication)
            try? context.save()
            Task { await AppModel.shared.refreshExternal() }
        }
        dismiss()
    }

    private static func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}

private struct TimeEntry: Identifiable {
    let id = UUID()
    var date: Date
}
