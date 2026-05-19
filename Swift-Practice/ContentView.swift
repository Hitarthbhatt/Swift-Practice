import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Topic 1: UI & Navigation") {
                    NavigationLink("SwiftUI Basics") {
                        SwiftUIBasicsView()
                    }
                    NavigationLink("UIKit Interop") {
                        UIKitInteropView()
                    }
                    NavigationLink("Lifecycle") {
                        LifecycleDemoView()
                    }
                    NavigationLink("NavigationStack") {
                        NavigationStackDemoView()
                    }
                    NavigationLink("Coordinator Pattern") {
                        CoordinatorDemoView()
                    }
                }

                Section("Topic 2: Concurrency & Data Binding") {
                    NavigationLink("GCD") {
                        GCDDemoView()
                    }
                    NavigationLink("OperationQueue") {
                        OperationQueueDemoView()
                    }
                    NavigationLink("async/await & Tasks") {
                        AsyncAwaitDemoView()
                    }
                    NavigationLink("Actors & Sendable") {
                        ActorsDemoView()
                    }
                    NavigationLink("Combine") {
                        CombineDemoView()
                    }
                    NavigationLink("Data Binding (@Observable, KVO)") {
                        ObservableDemoView()
                    }
                }

                Section("Topic 3: Networking") {
                    NavigationLink("Network Clients Demo") {
                        NetworkingDemoView()
                    }
                }

                Section("Topic 4: Realtime Networking") {
                    NavigationLink("HTTP Polling") {
                        HTTPPollingView()
                    }
                    NavigationLink("Server-Sent Events") {
                        SSEDemoView()
                    }
                    NavigationLink("WebSockets") {
                        WebSocketDemoView()
                    }
                    NavigationLink("Push Notifications") {
                        PushNotificationDemoView()
                    }
                }
                
                Section("Topic 5: Data Races") {
                    NavigationLink("Data Race Prevention") {
                        DataRaceDemoView()
                    }
                }

                Section("Topic 6: LRU Cache") {
                    NavigationLink("LRU Cache") {
                        LRUCacheDemoView()
                    }
                }

                Section("Topic 7: Concurrent Image Loader") {
                    NavigationLink("Image Loader (max 4 concurrent)") {
                        ImageLoaderDemoView()
                    }
                }

                Section("Topic 8: Network Resilience") {
                    NavigationLink("Backoff, Circuit Breaker & OAuth") {
                        NetworkResilienceDemoView()
                    }
                }

                Section("Topic 9: Performance — Infinite Image Feed") {
                    NavigationLink("UICollectionView · Diffable DS · Prefetch") {
                        InfiniteFeedDemoView()
                            .ignoresSafeArea(.container, edges: .bottom)
                            .navigationTitle("Infinite Feed")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }

                Section("Topic 10: Offline & Sync") {
                    NavigationLink("Persistent Operation Queue") {
                        QueueingDemoView()
                    }
                }

                Section("Topic 11: Audio Streaming (HLS)") {
                    NavigationLink("HLS Audio Player") {
                        AudioStreamingDemoView()
                    }
                }

                Section("Topic 12: Network Interceptor") {
                    NavigationLink("Adapter · Retrier · Observer chain") {
                        NetworkInterceptorDemoView()
                    }
                }

            }
            .navigationTitle("iOS System Design")
        }
    }
}

#Preview {
    ContentView()
}
