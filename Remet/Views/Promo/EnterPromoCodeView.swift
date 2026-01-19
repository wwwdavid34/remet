import SwiftUI

struct EnterPromoCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var promoManager = PromoCodeManager.shared
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @FocusState private var isCodeFieldFocused: Bool

    var onSuccess: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.coral)

                    Text(String(localized: "Have a Promo Code?"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(String(localized: "Enter your code to unlock free Premium"))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Code input
                VStack(spacing: 12) {
                    HStack {
                        TextField(String(localized: "Enter promo code"), text: $code)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .fontDesign(.monospaced)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCodeFieldFocused)
                            .onChange(of: code) { _, newValue in
                                code = newValue.uppercased()
                                errorMessage = nil
                            }

                        if !code.isEmpty {
                            Button {
                                code = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.textMuted)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.warning)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Success message
                if let success = successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(success)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.success)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                Spacer()

                // Submit button
                Button {
                    submitCode()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(String(localized: "Redeem Code"))
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(code.isEmpty ? Color.gray : AppColors.coral)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(code.isEmpty || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(String(localized: "Promo Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCodeFieldFocused = true
                }
            }
        }
    }

    private func submitCode() {
        guard !code.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        Task {
            let result = await promoManager.applyCode(code)

            await MainActor.run {
                isSubmitting = false

                switch result {
                case .success(let promoResult):
                    successMessage = promoResult.message
                    // Dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onSuccess?()
                        dismiss()
                    }

                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }
}

#Preview {
    EnterPromoCodeView()
}
