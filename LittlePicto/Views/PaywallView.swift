import SwiftUI
import StoreKit

/// Simple, production‑ready paywall that shows premium benefits and allows
/// the user to subscribe monthly or yearly, or restore purchases.
///
/// This view relies on `SubscriptionManager` from the environment:
/// `@EnvironmentObject var subscriptionManager: SubscriptionManager`.
struct PaywallView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    private var monthlyProduct: Product? {
        subscriptionManager.products.first { $0.id == "com.varink.littlepicto.premium_monthly" }
    }

    private var yearlyProduct: Product? {
        subscriptionManager.products.first { $0.id == "com.varink.littlepicto.premium_yearly" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefitsSection
                    pricingSection

                    if let error = subscriptionManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Unlock LittlePicto Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Access the full material library and enjoy unlimited AI recognition for your doodles.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Full material library", systemImage: "paintpalette.fill")
            Label("Unlimited AI recognition", systemImage: "sparkles")
            Label("New content added regularly", systemImage: "clock.arrow.circlepath")
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var pricingSection: some View {
        VStack(spacing: 16) {
            if let monthlyProduct {
                Button {
                    Task { await subscriptionManager.purchase(monthlyProduct) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly")
                                .font(.headline)
                            // Use StoreKit price when available, otherwise fall back to the
                            // marketing price you provided ($9.99 / month).
                            Text("\(monthlyProduct.displayPrice) / month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let yearlyProduct {
                Button {
                    Task { await subscriptionManager.purchase(yearlyProduct) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yearly")
                                .font(.headline)
                            // Use StoreKit price when available, otherwise fall back to
                            // "2.49 / month" messaging for the yearly option.
                            Text("\(yearlyProduct.displayPrice) / year")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Only show "Restore Purchases" when there is no active premium entitlement.
            // This covers the case where a subscription has expired or is on another device.
            if !subscriptionManager.isPremium {
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }

            Text("Payment will be charged to your Apple ID account. Subscriptions auto‑renew unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
}


