import SwiftUI
import WatchKit

@main
struct KongiWatchApp: App {
    @StateObject private var session = WatchSession.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(session)
        }
    }
}

struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSession
    @State private var confirmMed: MedSnapshot?
    @State private var celebrating = false

    private var stage: KongiStage { .forPoints(session.state?.points ?? 0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    KongiView(
                        stage: stage,
                        face: celebrating ? .happy : .normal,
                        prop: celebrating ? .star : .none
                    )
                    .frame(width: 72, height: 72)

                    if celebrating {
                        Text("+\(PointRules.dose)P").font(.headline)
                    }

                    if let state = session.state {
                        if state.meds.isEmpty {
                            Text("iPhone에서 약을 추가해 주세요")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }
                        ForEach(state.meds) { med in
                            row(med)
                        }
                    } else {
                        Text("iPhone에서 콩이 앱을 한 번 열어 주세요")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("콩이")
        }
        .confirmationDialog(
            "이미 드신 것 같아요",
            isPresented: Binding(get: { confirmMed != nil }, set: { if !$0 { confirmMed = nil } }),
            titleVisibility: .visible,
            presenting: confirmMed
        ) { med in
            Button("한 번 더 기록") { record(med) }
            Button("취소", role: .cancel) {}
        } message: { med in
            if let last = med.lastTaken {
                Text("\(TimeText.hm(last))에 기록돼 있어요")
            }
        }
    }

    private func row(_ med: MedSnapshot) -> some View {
        let now = Date()
        let done = med.isDone(on: now)
        let pastCutoff = DoseRules.isPastCutoff(med, now: now)
        return VStack(alignment: .leading, spacing: 4) {
            Text(med.name).font(.headline)
            Text(status(med, now: now)).font(.caption2).foregroundStyle(.secondary)
            if !done && !pastCutoff {
                Button("먹었어요") { tap(med) }
                    .tint(KongiColors.leafDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func status(_ med: MedSnapshot, now: Date) -> String {
        if med.isDone(on: now), let last = med.doses(on: now).last { return "약 ✓ \(TimeText.hm(last))" }
        if DoseRules.isPastCutoff(med, now: now) { return "오늘은 쉬어 가요" }
        if let next = med.nextPlannedMinutes(on: now) { return "\(TimeText.label(minutes: next)) 예정" }
        return ""
    }

    private func tap(_ med: MedSnapshot) {
        if DoseRules.needsDuplicateConfirm(med, now: .now) {
            confirmMed = med
        } else {
            record(med)
        }
    }

    private func record(_ med: MedSnapshot) {
        session.take(med)
        WKInterfaceDevice.current().play(.success)
        withAnimation { celebrating = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { celebrating = false }
        }
    }
}
