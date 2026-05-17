import SwiftUI
import Combine

// MARK: - Data Binding: ObservableObject, @Published, KVO
// Interview: "Compare data binding approaches in iOS"
//
// 1. ObservableObject + @Published (Combine-based, iOS 13+)
//    - Class conforms to ObservableObject
//    - @Published properties auto-notify SwiftUI
//    - Use with @StateObject (owner) or @ObservedObject (non-owner)
//
// 2. @Observable macro (Observation framework, iOS 17+)
//    - Finer-grained: only views using specific properties re-render
//    - No need for @Published — all stored properties tracked
//    - Use with @State (reference types now work with @State)
//
// 3. KVO (Key-Value Observing, legacy)
//    - NSObject subclasses, @objc dynamic properties
//    - Combine bridge: publisher(for:) on NSObject
//    - Still needed for observing UIKit/Foundation properties
//
// 4. Completion Handlers (pre-Combine)
//    - Callback closures: (Result<T, Error>) -> Void
//    - Pyramid of doom problem with nested callbacks
//
// Senior/Staff:
//   - Know when to use each approach
//   - @Observable is the future direction
//   - ObservableObject has whole-object invalidation (less efficient)
//   - @Observable has per-property tracking (more efficient)

// MARK: - ObservableObject + @Published
final class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var history: [String] = []

    func increment() {
        count += 1
        history.append("+1 → \(count)")
    }

    func decrement() {
        count -= 1
        history.append("-1 → \(count)")
    }
}

// MARK: - @Observable (iOS 17+)
@Observable
final class ModernCounterViewModel {
    var count = 0
    var label = "Counter"

    // No @Published needed — all properties are automatically tracked
    // SwiftUI only re-renders views that read the specific property that changed

    func increment() { count += 1 }
    func decrement() { count -= 1 }
}

// MARK: - KVO Example
class KVOTimer: NSObject {
    @objc dynamic var elapsed: Int = 0

    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - KVO Bridge to Combine
@MainActor
final class KVOViewModel: ObservableObject {
    @Published var elapsed = 0
    private let kvoTimer = KVOTimer()
    private var cancellable: AnyCancellable?

    func start() {
        kvoTimer.start()
        // Bridge KVO → Combine → SwiftUI
        cancellable = kvoTimer.publisher(for: \.elapsed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.elapsed = value
            }
    }

    func stop() {
        kvoTimer.stop()
        cancellable?.cancel()
    }
}

// MARK: - Demo View
struct ObservableDemoView: View {
    @StateObject private var classicVM = CounterViewModel()
    @State private var modernVM = ModernCounterViewModel()
    @StateObject private var kvoVM = KVOViewModel()

    var body: some View {
        List {
            Section("ObservableObject + @Published") {
                Text("Count: \(classicVM.count)")
                HStack {
                    Button("-") { classicVM.decrement() }
                    Spacer()
                    Button("+") { classicVM.increment() }
                }
                ForEach(classicVM.history.suffix(3), id: \.self) {
                    Text($0).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("@Observable (iOS 17+)") {
                Text("Count: \(modernVM.count)")
                HStack {
                    Button("-") { modernVM.decrement() }
                    Spacer()
                    Button("+") { modernVM.increment() }
                }
                Text("Only this section re-renders on count change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("KVO → Combine Bridge") {
                Text("Elapsed: \(kvoVM.elapsed)s")
                HStack {
                    Button("Start") { kvoVM.start() }
                    Spacer()
                    Button("Stop") { kvoVM.stop() }
                }
            }
        }
        .navigationTitle("Data Binding")
    }
}

#Preview {
    NavigationStack { ObservableDemoView() }
}
