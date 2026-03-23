import SwiftUI

struct ContentView: View {
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var viewModel = HighlightViewModel()
    @StateObject private var libraryStore = LibraryStore.shared
    @StateObject private var libraryPlayer = AudioPlayerManager()
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "quickpod_onboarding_done")

    var body: some View {
        Group {
            if !authStore.isAuthenticated {
                AuthView()
            } else if !authStore.isVerified {
                VerificationView(email: authStore.email ?? "")
            } else {
                appTabs
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "quickpod_onboarding_done")
                showOnboarding = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                viewModel.stopPolling()
            } else if newPhase == .active {
                viewModel.resumePollingIfNeeded()
            }
        }
        .onAppear {
            if let jobId = notificationManager.pendingJobId {
                viewModel.openJob(jobId: jobId)
                notificationManager.pendingJobId = nil
            } else {
                viewModel.restoreLastJobIfNeeded()
            }
        }
        .onChange(of: notificationManager.pendingJobId) { _, jobId in
            guard let jobId else { return }
            viewModel.openJob(jobId: jobId)
            notificationManager.pendingJobId = nil
        }
    }

    private var appTabs: some View {
        TabView {
            NavigationStack {
                Group {
                    if let detail = viewModel.jobDetail, detail.status == .succeeded {
                        ResultView(viewModel: viewModel)
                    } else if viewModel.jobId != nil {
                        JobStatusView(viewModel: viewModel)
                    } else {
                        SubmitView(viewModel: viewModel)
                    }
                }
                .navigationTitle("QuickPod")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if viewModel.jobId != nil {
                            Button("New") { viewModel.reset() }
                                .disabled(viewModel.jobStatus == .queued || viewModel.jobStatus == .running)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showSettings = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            Button(role: .destructive) {
                                authStore.signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            .tabItem {
                Label("Create", systemImage: "wand.and.stars")
            }

            NavigationStack {
                LibraryView(store: libraryStore, player: libraryPlayer)
                    .navigationTitle("Library")
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    ContentView()
}
