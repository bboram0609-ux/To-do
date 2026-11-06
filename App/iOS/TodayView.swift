import SwiftUI
import SwiftData

/// "오늘" 탭. 지금 할 일 하나를 크게 보여 준다.
struct TodayView: View {
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @Query(sort: \DoseLog.takenAt, order: .reverse) private var logs: [DoseLog]

    @State private var showAdd = false
    @State private var confirmMed: MedSnapshot?
    @State private var celebration: Celebration?
    // 화면이 다시 그려질 때마다 문구가 바뀌지 않도록 한 번만 고른다
    @State private var greeting = KongiLines.pick(KongiLines.greet)
    @State private var doneLine = KongiLines.pick(KongiLines.allDone)
    @State private var cutoffLine = KongiLines.pick(KongiLines.pastCutoff)

    private var now: Date { .now }
    private var snapshots: [MedSnapshot] { meds.map { $0.snapshot(logs: logs, now: now) } }

    /// 오늘 아직 안 먹었고, 마감 전인 첫 번째 약
    private var nextMed: MedSnapshot? {
        snapshots
            .filter { !$0.isDone(on: now) && !DoseRules.isPastCutoff($0, now: now) }
            .min { ($0.nextPlannedMinutes(on: now) ?? .max) < ($1.nextPlannedMinutes(on: now) ?? .max) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if meds.isEmpty {
                        emptyState
                    } else {
                        nextActionCard
                        refillBanners
                        medList
                    }
                }
                .padding()
            }
            .navigationTitle("오늘")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("약 추가")
                }
            }
            .sheet(isPresented: $showAdd) {
                MedicationEditView(medication: nil)
            }
            .confirmationDialog(
                "이미 드신 것 같아요",
                isPresented: Binding(get: { confirmMed != nil }, set: { if !$0 { confirmMed = nil } }),
                titleVisibility: .visible,
                presenting: confirmMed
            ) { med in
                Button("한 번 더 기록하기") { take(med, force: true) }
                Button("취소", role: .cancel) {}
            } message: { med in
                Text(duplicateMessage(med))
            }
            .overlay {
                if let celebration {
                    CelebrationView(celebration: celebration)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 부분 화면

    private var header: some View {
        HStack(spacing: 12) {
            KongiView(stage: KongiStage.forPoints(AppModel.shared.totalPoints()), face: .normal)
                .frame(width: 72, height: 72)
            Text(headerLine)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerLine: String {
        if meds.isEmpty { return greeting }
        if nextMed != nil { return greeting }
        let anyPastCutoff = snapshots.contains { !$0.isDone(on: now) && DoseRules.isPastCutoff($0, now: now) }
        return anyPastCutoff ? cutoffLine : doneLine
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("먹는 약을 추가하면 시간에 맞춰 알려 줄게")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("약 추가하기") { showAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var nextActionCard: some View {
        if let med = nextMed {
            VStack(alignment: .leading, spacing: 12) {
                Text("지금 할 일").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(med.name).font(.title2.bold())
                if let minutes = med.nextPlannedMinutes(on: now) {
                    Text("\(TimeText.label(minutes: minutes)) 예정").foregroundStyle(.secondary)
                }
                Button {
                    take(med, force: false)
                } label: {
                    Text("먹었어요")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KongiColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    private var refillBanners: some View {
        ForEach(meds) { med in
            if let days = DoseRules.daysLeft(remainingCount: med.remainingCount, plannedPerDay: med.plannedPerDay),
               days <= DoseRules.refillWarningDays {
                Label("\(med.name) 약이 \(days)일분 남았어요. 병원 예약·처방 챙길 때예요.", systemImage: "cross.case")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var medList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 약").font(.headline)
            ForEach(snapshots) { med in
                MedRow(med: med, now: now) { take(med, force: false) }
            }
        }
    }

    // MARK: - 동작

    private func take(_ med: MedSnapshot, force: Bool) {
        if !force && DoseRules.needsDuplicateConfirm(med, now: .now) {
            confirmMed = med
            return
        }
        guard let result = AppModel.shared.logDose(medicationID: med.id) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let line = result.comeback ? KongiLines.pick(KongiLines.comeback) : KongiLines.pick(KongiLines.tookMed)
        withAnimation(.spring) {
            celebration = Celebration(points: result.points, line: line, comeback: result.comeback)
        }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { celebration = nil }
        }
    }

    private func duplicateMessage(_ med: MedSnapshot) -> String {
        guard let last = med.lastTaken else { return "\(med.name)을 한 번 더 기록할까요?" }
        return "\(med.name)은 \(TimeText.hm(last))에 기록돼 있어요. 정말 한 번 더 드셨으면 기록해 주세요."
    }
}

private struct MedRow: View {
    let med: MedSnapshot
    let now: Date
    let onTake: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.body.weight(.semibold))
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if med.isDone(on: now) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(KongiColors.accent)
                    .accessibilityLabel("오늘 완료")
            } else if !DoseRules.isPastCutoff(med, now: now) {
                Button("먹었어요", action: onTake).buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var status: String {
        let taken = med.doses(on: now)
        if med.isDone(on: now), let last = taken.last { return "✓ \(TimeText.hm(last))" }
        if DoseRules.isPastCutoff(med, now: now) { return "마감 시간이 지나서 오늘은 쉬어 가요" }
        let times = med.timesMinutes.sorted().map { TimeText.label(minutes: $0) }.joined(separator: ", ")
        return "\(taken.count)/\(med.plannedPerDay) · \(times)"
    }
}

struct Celebration: Equatable {
    let points: Int
    let line: String
    let comeback: Bool
}

private struct CelebrationView: View {
    let celebration: Celebration

    var body: some View {
        VStack(spacing: 8) {
            KongiView(
                stage: KongiStage.forPoints(AppModel.shared.totalPoints()),
                face: celebration.comeback ? .sparkle : .happy,
                prop: celebration.comeback ? .heart : .star
            )
            .frame(width: 140, height: 140)
            Text("+\(celebration.points)P").font(.title.bold())
            Text(celebration.line).font(.headline).multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(40)
        .accessibilityElement(children: .combine)
    }
}
