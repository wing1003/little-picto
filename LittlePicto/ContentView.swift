import SwiftUI

// Navigation destination enum for programmatic navigation
enum NavigationDestination: Hashable {
    case snapPhoto
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(role: .destructive) {
                                    authViewModel.signOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                } else {
                    AuthenticationView(viewModel: authViewModel)
                        .navigationTitle("Let's Get Started! 🎨")
                }
            }
            .animation(.easeInOut, value: authViewModel.currentUser != nil)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .snapPhoto:
                    SnapPhotoView()
                        // Hide the default navigation bar while the camera is open
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
    }
}

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

private struct HomeView: View {
    let materials: [Material]
    let userDisplayName: String

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var snapPhotoVM: SnapPhotoViewModel
    @Binding var navigationPath: NavigationPath
    @State private var bounceAnimation = false
    @State private var isShowingPaywall = false
    @State private var isShowingQuotaAlert = false
    @State private var quotaAlertMessage: String?
    
    init(materials: [Material], userDisplayName: String, navigationPath: Binding<NavigationPath>) {
           self.materials = materials
           self.userDisplayName = userDisplayName
           self._navigationPath = navigationPath
           // _snapPhotoVM cannot be initialized here; use a custom initClosure in real code
           _snapPhotoVM = StateObject(wrappedValue: SnapPhotoViewModel(subscriptionManager: SubscriptionManager()))
       }
    
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    heroSection
                    materialLibraryPreview
                }
                .padding()
            }
            .navigationTitle("🎨 LittlePicto")
            .onChange(of: snapPhotoVM.navigateToCamera) { go in
                if go {
                    navigationPath.append(NavigationDestination.snapPhoto)
                    snapPhotoVM.consumeCameraNavigation()
                }
            }
            .onChange(of: snapPhotoVM.showPaywall) { show in
                if show {
                    quotaAlertMessage = snapPhotoVM.quotaAlertMessage
                    isShowingPaywall = true
                }
            }
            .alert("Notice", isPresented: $isShowingQuotaAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(quotaAlertMessage ?? "")
            })
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
        }
    
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
            
            Button(action: { snapPhotoVM.snapPhoto() }) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text("Snap a Photo!")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(BounceButtonStyle())
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
                NavigationLink("See All →") {
                    MaterialLibraryView(materials: materials)
                }
                .font(.headline)
                .foregroundStyle(.purple)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(materials) { material in
                        NavigationLink(value: material) {
                            MaterialPreviewCard(material: material)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 8)
            }
            .scrollTargetBehavior(.viewAligned)
            .navigationDestination(for: Material.self) { material in
                MaterialDetailView(material: material)
            }
        }
    }
}

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

private struct PhotoPickerPlaceholder: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundStyle(.purple)
            
            Text("Camera is coming soon! 📸")
                .font(.title)
                .fontWeight(.bold)
            
            Text("We're working on something awesome for you!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Custom button styles for kid-friendly interactions
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

#Preview {
    ContentView()
}
