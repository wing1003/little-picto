import SwiftUI

// MARK: - Navigation Destination

enum NavigationDestination: Hashable {
    case snapPhoto
    case materialLibrary
    case materialDetail(Material)
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if authViewModel.isLoading {
                    LoadingView()
                } else if authViewModel.currentUser != nil {
                    HomeView(
                        materials: Material.sampleLibrary,
                        userDisplayName: authViewModel.userDisplayName,
                        navigationPath: $navigationPath
                    )
                    .environmentObject(subscriptionManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            userMenuButton
                        }
                    }
                } else {
                    AuthenticationView(viewModel: authViewModel)
                        .navigationTitle("Let's Get Started! 🎨")
                }
            }
            .animation(.easeInOut, value: authViewModel.currentUser != nil)
            .navigationDestination(for: NavigationDestination.self) { destination in
                navigationDestinationView(for: destination)
            }
        }
        .task {
            // Initialize subscription manager when app launches
            if authViewModel.currentUser != nil {
                await subscriptionManager.initialize()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var userMenuButton: some View {
        Menu {
            // Subscription status
            Section {
                if subscriptionManager.isPremium {
                    Label(
                        subscriptionManager.currentSubscriptionTier == .monthly ? "Monthly Premium" : "Yearly Premium",
                        systemImage: "crown.fill"
                    )
                } else {
                    Label("Free Account", systemImage: "person.circle")
                }
            }
            
            // Actions
            Section {
                if !subscriptionManager.isPremium {
                    Button {
                        // Show paywall
                    } label: {
                        Label("Upgrade to Premium", systemImage: "star.fill")
                    }
                }
                
                Button {
                    // Show settings
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    authViewModel.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.purple)
        }
    }
    
    @ViewBuilder
    private func navigationDestinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .snapPhoto:
            SnapPhotoView()
                .environmentObject(subscriptionManager)
                .toolbar(.hidden, for: .navigationBar)
            
        case .materialLibrary:
            MaterialLibraryView(materials: Material.sampleLibrary)
            
        case .materialDetail(let material):
            MaterialDetailView(material: material)
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            Text("Opening your art studio...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Home View

private struct HomeView: View {
    let materials: [Material]
    let userDisplayName: String
    @Binding var navigationPath: NavigationPath
    
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var snapPhotoVM: SnapPhotoViewModel
    
    @State private var bounceAnimation = false
    
    init(materials: [Material], userDisplayName: String, navigationPath: Binding<NavigationPath>) {
        self.materials = materials
        self.userDisplayName = userDisplayName
        self._navigationPath = navigationPath
        
        // Initialize with shared subscription manager
        self._snapPhotoVM = StateObject(wrappedValue: SnapPhotoViewModel(subscriptionManager: .shared))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroSection
                
                // Quota display for premium users
                if subscriptionManager.isPremium, let quotaInfo = snapPhotoVM.quotaInfo {
                    quotaDisplaySection(quotaInfo)
                }
                
                materialLibraryPreview
            }
            .padding()
        }
        .navigationTitle("🎨 LittlePicto")
        .onAppear {
            snapPhotoVM.refreshQuotaInfo()
        }
        .onChange(of: snapPhotoVM.navigateToCamera) { _, shouldNavigate in
            if shouldNavigate {
                navigationPath.append(NavigationDestination.snapPhoto)
                snapPhotoVM.didNavigateToCamera()
            }
        }
        .sheet(isPresented: $snapPhotoVM.showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
                .onDisappear {
                    snapPhotoVM.didDismissPaywall()
                }
        }
        .alert(item: $snapPhotoVM.currentAlert) { alert in
            createAlert(from: alert)
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Text("👋")
                    .font(.largeTitle)
                    .scaleEffect(bounceAnimation ? 1.2 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: bounceAnimation)
                
                Text("Hey there, \(userDisplayName)!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
            }
            .onAppear { bounceAnimation = true }
            
            Text("Let's Make Art! ✨")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Take a photo and turn it into an awesome drawing! 📸")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            snapPhotoButton
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.2), .pink.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .orange.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var snapPhotoButton: some View {
        Button(action: { snapPhotoVM.snapPhoto() }) {
            HStack(spacing: 12) {
                if snapPhotoVM.viewState == .checking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                }
                
                Text(snapPhotoVM.viewState == .checking ? "Checking..." : "Snap a Photo!")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: snapPhotoVM.viewState == .checking ? [.gray, .gray.opacity(0.8)] : [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
        .disabled(snapPhotoVM.viewState == .checking)
    }
    
    // MARK: - Quota Display Section
    
    private func quotaDisplaySection(_ info: QuotaInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                
                Text("Your Monthly Usage")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(info.remaining)/\(info.limit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(info.isNearLimit ? .orange : .secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: progressGradient(for: info),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * info.percentageUsed)
                }
            }
            .frame(height: 12)
            
            // Warning if near limit
            if info.isNearLimit && !info.isAtLimit {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Running low! Consider upgrading for more.")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 2)
        )
    }
    
    private func progressGradient(for info: QuotaInfo) -> [Color] {
        if info.isAtLimit {
            return [.red, .red.opacity(0.7)]
        } else if info.isNearLimit {
            return [.orange, .yellow]
        } else {
            return [.purple, .pink]
        }
    }
    
    // MARK: - Material Library Preview
    
    private var materialLibraryPreview: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎁 Free Stuff to Draw!")
                        .font(.title2)
                        .fontWeight(.heavy)
                    Text("Cool templates just for you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    navigationPath.append(NavigationDestination.materialLibrary)
                } label: {
                    Text("See All →")
                        .font(.headline)
                        .foregroundStyle(.purple)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(materials.prefix(5)) { material in
                        Button {
                            navigationPath.append(NavigationDestination.materialDetail(material))
                        } label: {
                            MaterialPreviewCard(material: material)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 8)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // MARK: - Alert Helper
    
    private func createAlert(from config: QuotaAlert) -> Alert {
        if let secondaryButton = config.secondaryButton {
            return Alert(
                title: Text(config.title),
                message: Text(config.message),
                primaryButton: .default(Text(config.primaryButton)) {
                    snapPhotoVM.handleAlertAction(isPrimary: true)
                },
                secondaryButton: .cancel(Text(secondaryButton)) {
                    snapPhotoVM.handleAlertAction(isPrimary: false)
                }
            )
        } else {
            return Alert(
                title: Text(config.title),
                message: Text(config.message),
                dismissButton: .default(Text(config.primaryButton)) {
                    snapPhotoVM.handleAlertAction(isPrimary: true)
                }
            )
        }
    }
}

// MARK: - Material Preview Card

private struct MaterialPreviewCard: View {
    let material: Material
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: material.thumbnailSystemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(material.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(material.category)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 180)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 2)
        )
    }
}

// MARK: - Custom Button Styles

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
