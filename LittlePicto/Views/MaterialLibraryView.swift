import SwiftUI

struct MaterialLibraryView: View {
    let materials: [Material]
    
    var body: some View {
        List(materials) { material in
            NavigationLink(value: material) {
                MaterialRow(material: material)
            }
        }
        .navigationTitle("Material Library")
        .navigationDestination(for: Material.self) { material in
            MaterialDetailView(material: material)
        }
    }
}

private struct MaterialRow: View {
    let material: Material
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: material.thumbnailSystemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(material.title)
                    .font(.headline)
                Text(material.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct MaterialDetailView: View {
    let material: Material
    @State private var isDownloaded = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: material.thumbnailSystemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(material.title)
                        .font(.largeTitle)
                        .bold()
                    
                    Text(material.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: { isDownloaded.toggle() }) {
                    Label(isDownloaded ? "Downloaded" : "Download", systemImage: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isDownloaded ? Color.green.opacity(0.2) : Color.blue)
                        .foregroundStyle(isDownloaded ? Color.green : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle(material.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MaterialLibraryView(materials: Material.sampleLibrary)
    }
}

