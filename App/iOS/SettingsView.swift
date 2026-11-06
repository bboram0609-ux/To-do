import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @State private var editing: Medication?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("내 약") {
                    ForEach(meds) { med in
                        Button {
                            editing = med
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.name).foregroundStyle(.primary)
                                Text(med.timesMinutes.map { TimeText.label(minutes: $0) }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("약 추가") { showAdd = true }
                }

                Section("알림") {
                    Button("알림 권한 요청하기") {
                        Task {
                            await ReminderScheduler.shared.requestAuthorization()
                            await AppModel.shared.refreshExternal()
                        }
                    }
                    Text("예정 시각에 한 번, 안 누르면 10분·30분 뒤에 다시 알려요. 워치를 차고 있으면 워치로도 와요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("안내") {
                    Text("콩이는 의료 조언을 하지 않아요. 약의 용량과 시간은 처방받은 대로 입력하고, 바꾸고 싶으면 의사와 상의해 주세요.")
                        .font(.footnote)
                    Text("기록은 이 iPhone 안에만 저장돼요.")
                        .font(.footnote)
                }
            }
            .navigationTitle("기록·설정")
            .sheet(item: $editing) { med in
                MedicationEditView(medication: med)
            }
            .sheet(isPresented: $showAdd) {
                MedicationEditView(medication: nil)
            }
        }
    }
}
