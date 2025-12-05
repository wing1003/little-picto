import SwiftUI
import StoreKit

/// Kid-friendly paywall that shows premium benefits in an engaging way
/// and allows subscription options or purchase restoration.
struct PaywallView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var sparkleAnimation = false
    @State private var selectedPlan: PlanType?
    @State private var isProcessingPurchase = false
    
    private var monthlyProduct: Product? {
        subscriptionManager.products.first { $0.id == SubscriptionProductID.monthlyPremium.rawValue }
    }

    private var yearlyProduct: Product? {
        subscriptionManager.products.first { $0.id == SubscriptionProductID.yearlyPremium.rawValue }
    }
    
    private var monthlyMockProduct: ProductModel? {
        subscriptionManager.mockProducts.first { $0.id == SubscriptionProductID.monthlyPremium.rawValue }
    }
    
    private var yearlyMockProduct: ProductModel? {
        subscriptionManager.mockProducts.first { $0.id == SubscriptionProductID.yearlyPremium.rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    benefitsSection
                    pricingSection

                    if let error = subscriptionManager.errorMessage {
                        errorMessageView(error)
                    }
                    
                    legalText
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.05),
                        Color.pink.opacity(0.05),
                        Color.orange.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("✨ Go Premium!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated background circles
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(-15))
                    .scaleEffect(sparkleAnimation ? 1.1 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: sparkleAnimation)
                
                // Sparkles around the crown
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .offset(
                            x: [-40, 45, 0][index],
                            y: [-30, -25, 50][index]
                        )
                        .opacity(sparkleAnimation ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: sparkleAnimation
                        )
                }
            }
            .frame(height: 140)
            .onAppear { sparkleAnimation = true }
            
            VStack(spacing: 12) {
                Text("Unlock All the Fun! 🎨")
                    .font(.system(size: 32, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Get everything LittlePicto has to offer and create unlimited masterpieces!")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var benefitsSection: some View {
        VStack(spacing: 16) {
            Text("🎁 What You'll Get:")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 14) {
                BenefitRow(
                    icon: "paintpalette.fill",
                    title: "All Drawing Templates",
                    description: "Hundreds of cool things to trace and draw!",
                    color: .blue
                )
                
                BenefitRow(
                    icon: "sparkles",
                    title: "Magic AI Recognition",
                    description: "Turn your photos into drawings forever!",
                    color: .purple
                )
                
                BenefitRow(
                    icon: "star.fill",
                    title: "New Stuff Every Month",
                    description: "Fresh templates added all the time!",
                    color: .orange
                )
                
//                BenefitRow(
//                    icon: "heart.fill",
//                    title: "No Ads, Just Fun",
//                    description: "Create without interruptions!",
//                    color: .pink
//                )
            }
        }
    }

    private var pricingSection: some View {
        VStack(spacing: 20) {
            Text("Choose Your Plan:")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                PlanCard(
                    planType: .yearly,
                    title: "Best Value! 🌟",
                    subtitle: "Save the most money",
                    price: priceText(for: .yearly),
                    period: periodText(for: .yearly),
                    savings: "Save 75%!",
                    isSelected: selectedPlan == .yearly,
                    isRecommended: true
                ) {
                    selectedPlan = .yearly
                }
                
                PlanCard(
                    planType: .monthly,
                    title: "Monthly Fun",
                    subtitle: "Pay as you go",
                    price: priceText(for: .monthly),
                    period: periodText(for: .monthly),
                    savings: nil,
                    isSelected: selectedPlan == .monthly,
                    isRecommended: false
                ) {
                    selectedPlan = .monthly
                }
            }
            
            Button {
                Task { await confirmSubscription() }
            } label: {
                HStack(spacing: 10) {
                    if isProcessingPurchase {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                    }
                    
                    Text(selectedPlan == nil ? "Choose a Plan" : "Confirm Subscription")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: selectedPlan == nil ? [.gray, .gray.opacity(0.7)] : [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .disabled(selectedPlan == nil || isProcessingPurchase)
            .padding(.top, 8)

            // Restore purchases button
            if !subscriptionManager.isPremium {
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Already Have Premium?")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                    .padding(.vertical, 12)
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
    }
    
    private func priceText(for plan: PlanType) -> String {
        switch plan {
        case .monthly:
            if let displayPrice = monthlyProduct?.displayPrice {
                return displayPrice
            }
            if let mockPrice = monthlyMockProduct?.price {
                return mockPrice
            }
            return SubscriptionProductID.monthlyPremium.mockPrice
        case .yearly:
            if let displayPrice = yearlyProduct?.displayPrice {
                return displayPrice
            }
            if let mockPrice = yearlyMockProduct?.price {
                return mockPrice
            }
            return SubscriptionProductID.yearlyPremium.mockPrice
        }
    }
    
    private func periodText(for plan: PlanType) -> String {
        if let product = planProduct(for: plan),
           let period = product.subscription?.subscriptionPeriod {
            switch period.unit {
            case .month:
                return "per month"
            case .year:
                return "per year"
            default:
                break
            }
        }
        
        switch plan {
        case .monthly:
            return monthlyMockProduct?.subscriptionPeriod ?? "per month"
        case .yearly:
            return yearlyMockProduct?.subscriptionPeriod ?? "per year"
        }
    }
    
    private func planProduct(for plan: PlanType) -> Product? {
        switch plan {
        case .monthly: return monthlyProduct
        case .yearly: return yearlyProduct
        }
    }
    
    private func handleSubscribe(for plan: PlanType) async {
        await MainActor.run { isProcessingPurchase = true }
        defer {
            Task { @MainActor in
                isProcessingPurchase = false
            }
        }
        
        if let product = planProduct(for: plan) {
            let success = await subscriptionManager.purchase(product)
            await handlePurchaseResult(success, for: plan)
            return
        }
        
        await subscriptionManager.loadProducts()
        
        if let refreshedProduct = planProduct(for: plan) {
            let success = await subscriptionManager.purchase(refreshedProduct)
            await handlePurchaseResult(success, for: plan)
        } else {
            await MainActor.run {
                subscriptionManager.errorMessage = "Subscriptions are unavailable right now. Please try again in a moment."
            }
        }
    }
    
    private func confirmSubscription() async {
        guard let plan = selectedPlan else {
            await MainActor.run {
                subscriptionManager.errorMessage = "Please pick a plan to continue."
            }
            return
        }
        
        await handleSubscribe(for: plan)
    }
    
    @MainActor
    private func handlePurchaseResult(_ success: Bool, for plan: PlanType) {
        if success {
            selectedPlan = nil
        }
    }
    
    private var legalText: some View {
        VStack(spacing: 8) {
            Text("👨‍👩‍👧 Parent Information")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Payment will be charged to your Apple ID account. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }
    
    private func errorMessageView(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    enum PlanType {
        case monthly, yearly
    }
}

// MARK: - Benefit Row Component
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Plan Card Component
struct PlanCard: View {
    let planType: PaywallView.PlanType
    let title: String
    let subtitle: String
    let price: String
    let period: String
    let savings: String?
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if isRecommended {
                    HStack {
                        Spacer()
                        Text("MOST POPULAR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.heavy)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(price)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text(period)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(isRecommended ? .orange : .purple)
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isRecommended
                            ? LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [.purple.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: isRecommended ? 3 : 2
                    )
            )
            .shadow(color: isRecommended ? .orange.opacity(0.2) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}


#Preview {
    PaywallView()
}
