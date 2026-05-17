import SwiftUI
import Combine

// MARK: - Combine Framework
// Interview: "Explain Combine and when you'd use it vs async/await"
//
// Combine = reactive streams framework (like RxSwift)
// Core types:
//   Publisher — emits values over time
//   Subscriber — receives values
//   Operator — transforms stream (map, filter, flatMap, debounce, etc.)
//
// Key publishers:
//   - Just, Future, PassthroughSubject, CurrentValueSubject
//   - @Published property wrapper (auto-creates publisher)
//   - NotificationCenter.publisher, Timer.publish, URLSession.dataTaskPublisher
//
// Combine vs async/await:
//   - Combine: streams of values over time (search debounce, real-time updates)
//   - async/await: single async operations, structured concurrency
//   - Use Combine for event streams, async/await for request-response
//
// Senior/Staff:
//   - AnyCancellable memory management (store in Set)
//   - Backpressure handling (demand-based)
//   - Custom publishers/subscribers
//   - Schedulers (receive(on:), subscribe(on:))

// MARK: - Search ViewModel using Combine
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [String] = []
    @Published var isSearching = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Combine pipeline: debounce + deduplicate + search
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // wait for typing pause
            .removeDuplicates() // skip if same as last
            .filter { !$0.isEmpty } // skip empty
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isSearching = true
            })
            .flatMap { query in
                // Simulate network search — Future is a single-value publisher
                Future<[String], Never> { promise in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        let results = (1...5).map { "\(query) result \($0)" }
                        promise(.success(results))
                    }
                }
            }
            .receive(on: DispatchQueue.main) // deliver on main thread
            .sink { [weak self] results in
                self?.results = results
                self?.isSearching = false
            }
            .store(in: &cancellables)
    }
}

// MARK: - Timer ViewModel using Combine
@MainActor
final class TimerViewModel: ObservableObject {
    @Published var ticks = 0
    @Published var isRunning = false

    private var timerCancellable: AnyCancellable?

    func start() {
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .scan(0) { count, _ in count + 1 } // accumulate count
            .sink { [weak self] count in
                self?.ticks = count
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isRunning = false
    }
}

// MARK: - Combine Operators Demo
@MainActor
final class OperatorsDemoViewModel: ObservableObject {
    @Published var log: [String] = []
    private var cancellables = Set<AnyCancellable>()

    func demoSubjects() {
        log.append("--- Subjects ---")

        // PassthroughSubject: no initial value, only forwards new values
        let passthrough = PassthroughSubject<String, Never>()
        passthrough
            .sink { [weak self] value in self?.log.append("Passthrough: \(value)") }
            .store(in: &cancellables)

        passthrough.send("Hello")
        passthrough.send("World")

        // CurrentValueSubject: has initial value, replays latest to new subscribers
        let current = CurrentValueSubject<Int, Never>(0)
        current.value = 5 // direct access to current value
        current
            .sink { [weak self] value in self?.log.append("Current: \(value)") }
            .store(in: &cancellables)
        current.send(10)
    }

    func demoOperators() {
        log.append("--- Operators ---")
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].publisher

        // map + filter
        numbers
            .filter { $0.isMultiple(of: 2) }
            .map { "Even: \($0)" }
            .collect() // gather all into array
            .sink { [weak self] values in self?.log.append(values.joined(separator: ", ")) }
            .store(in: &cancellables)

        // reduce
        numbers
            .reduce(0, +)
            .sink { [weak self] sum in self?.log.append("Sum: \(sum)") }
            .store(in: &cancellables)

        // combineLatest
        let a = CurrentValueSubject<String, Never>("A")
        let b = CurrentValueSubject<Int, Never>(1)
        
        a.combineLatest(b)
            .sink { [weak self] letter, number in
                self?.log.append("Combined: \(letter)\(number)")
            }
            .store(in: &cancellables)
        a.send("B")
        b.send(2)

        // merge
        let s1 = PassthroughSubject<String, Never>()
        let s2 = PassthroughSubject<String, Never>()
        s1.merge(with: s2)
            .sink { [weak self] value in self?.log.append("Merged: \(value)") }
            .store(in: &cancellables)
        s1.send("from s1")
        s2.send("from s2")
    }
}

// MARK: - Demo View
struct CombineDemoView: View {
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var operatorsVM = OperatorsDemoViewModel()

    var body: some View {
        List {
            Section("Debounced Search (Combine)") {
                TextField("Search...", text: $searchVM.query)
                if searchVM.isSearching {
                    ProgressView()
                }
                ForEach(searchVM.results, id: \.self) { Text($0) }
            }

            Section("Timer (Combine)") {
                Text("Ticks: \(timerVM.ticks)")
                Button(timerVM.isRunning ? "Stop" : "Start") {
                    timerVM.isRunning ? timerVM.stop() : timerVM.start()
                }
            }

            Section("Subjects & Operators") {
                Button("Subjects Demo") { operatorsVM.demoSubjects() }
                Button("Operators Demo") { operatorsVM.demoOperators() }
                Button("Clear Log") { operatorsVM.log.removeAll() }

                ForEach(Array(operatorsVM.log.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Combine")
    }
}

#Preview {
    NavigationStack { CombineDemoView() }
}
