//
//  ContentView.swift
//  LittlePicto
//
//  Created by diruo on 2025/11/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if authViewModel.isLoading {
                    ProgressView("Opening your studio…")
                        .progressViewStyle(.circular)
                } else if authViewModel.currentUser != nil {
                    HomeView(
                        materials: Material.sampleLibrary,
                        userDisplayName: authViewModel.userDisplayName
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
                                Label("Account", systemImage: "person.crop.circle")
                            }
                        }
                    }
                } else {
                    AuthenticationView(viewModel: authViewModel)
                        .navigationTitle("Sign In")
                }
            }
            .animation(.easeInOut, value: authViewModel.currentUser != nil)
        }
    }
}

private struct HomeView: View {
    let materials: [Material]
    let userDisplayName: String
    @State private var isShowingPhotoPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroSection
                materialLibraryPreview
            }
            .padding()
        }
        .navigationTitle("LittlePicto")
        .sheet(isPresented: $isShowingPhotoPicker) {
            Text("Photo picker placeholder")
                .font(.headline)
                .padding()
        }
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hi, \(userDisplayName)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Create Something Magical")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Snap a photo to start tracing or inspire a brand-new doodle.")
                .foregroundStyle(.secondary)
            
            Button(action: { isShowingPhotoPicker = true }) {
                Label("Take Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private var materialLibraryPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Free Material Library")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink("See All") {
                    MaterialLibraryView(materials: materials)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(materials) { material in
                        NavigationLink(value: material) {
                            MaterialPreviewCard(material: material)
                        }
                    }
                }
                .scrollTargetLayout()
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
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: material.thumbnailSystemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .padding()
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(material.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(material.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 200, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
}
