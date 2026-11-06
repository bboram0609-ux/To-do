import SwiftUI
import SwiftData

/// "나의 정원" 탭. 포인트로 자라는 콩이.
struct GardenView: View {
    @Query(sort: \PointEvent.date, order: .reverse) private var events: [PointEvent]

    private var total: Int { events.reduce(0) { $0 + $1.amount } }
    private var stage: KongiStage { .forPoints(total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    KongiView(stage: stage, face: .normal)
                        .frame(width: 220, height: 220)

                    Text(stage.title).font(.title2.bold())
                    Text("\(total)P").font(.largeTitle.bold().monospacedDigit())

                    if let next = stage.next {
                        VStack(spacing: 6) {
                            ProgressView(
                                value: Double(total - stage.threshold),
                                total: Double(next.threshold - stage.threshold)
                            )
                            .tint(KongiColors.accent)
                            Text("\(next.title)까지 \(next.threshold - total)P")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("콩이가 꽃을 피웠어!").font(.headline)
                    }

                    Text("포인트는 줄어들지 않아요. 며칠 쉬어도 콩이는 시들지 않아요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("최근 기록").font(.headline)
                            ForEach(Array(events.prefix(10))) { event in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(event.reason)
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("+\(event.amount)").monospacedDigit().foregroundStyle(KongiColors.accent)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("나의 정원")
        }
    }
}
