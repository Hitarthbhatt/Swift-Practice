import Foundation

struct InterceptorScenario: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let run: () async -> [String]
}

enum InterceptorScenarios {
    static func all() -> [InterceptorScenario] {
        [success, retryThenSuccess, exhausted, nonRetryable]
    }

    private static func runChain(_ server: MockServer, maxAttempts: Int = 3) async -> [String] {
        let recorder = Recorder()
        let client = APIClient(
            interceptors: [
                AuthInterceptor(token: "abc123", recorder: recorder),
                RetryInterceptor(maxAttempts: maxAttempts, baseDelay: 0.1, recorder: recorder),
                LogInterceptor(recorder: recorder)
            ],
            transport: { await server.respond($0) }
        )
        do {
            let response = try await client.send(HTTPRequest(path: "/orders"))
            recorder.log("✅ done · final \(response.status)")
        } catch {
            recorder.log("❌ failed · \(error.localizedDescription)")
        }
        return recorder.lines
    }

    private static var success: InterceptorScenario {
        InterceptorScenario(
            title: "Success",
            detail: "All 3 interceptors. 200 on first try → Retry stays idle."
        ) {
            await runChain(MockServer(alwaysStatus: 200))
        }
    }

    private static var retryThenSuccess: InterceptorScenario {
        InterceptorScenario(
            title: "Retry → success",
            detail: "Server fails twice (503), then 200. Watch the backoff grow."
        ) {
            await runChain(MockServer(failFirst: 2, finalStatus: 200))
        }
    }

    private static var exhausted: InterceptorScenario {
        InterceptorScenario(
            title: "Retry exhausted",
            detail: "Server always 503. Retries run out, last 503 returned."
        ) {
            await runChain(MockServer(alwaysStatus: 503))
        }
    }

    private static var nonRetryable: InterceptorScenario {
        InterceptorScenario(
            title: "Non-retryable (401)",
            detail: "401 is not 5xx, so Retry never kicks in."
        ) {
            await runChain(MockServer(alwaysStatus: 401))
        }
    }
}
