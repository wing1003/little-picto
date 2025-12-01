import Foundation

/// Simple representation of a downloadable art material.
struct Material: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let thumbnailSystemImage: String
    
    static let sampleLibrary: [Material] = [
        Material(
            title: "Rainbow Brush",
            description: "Soft gradient brush for colorful skies and magical trails.",
            category: "Brushes",
            thumbnailSystemImage: "paintbrush.pointed"
        ),
        Material(
            title: "Galaxy Glitter",
            description: "Sparkly overlay to turn any doodle into a night sky.",
            category: "Textures",
            thumbnailSystemImage: "sparkles"
        ),
        Material(
            title: "Jungle Stamp Pack",
            description: "Monkeys, toucans, and leafy stamps for quick rainforest scenes.",
            category: "Stamps",
            thumbnailSystemImage: "leaf"
        )
    ]
}

