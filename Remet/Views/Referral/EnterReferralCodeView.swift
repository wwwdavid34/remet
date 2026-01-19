import SwiftUI

struct EnterReferralCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var referralManager = ReferralManager.shared
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

                    Text(String(localized: "Have a Code?"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(String(localized: "Enter a referral or promo code to get Premium credit"))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Code input
                VStack(spacing: 12) {
                    HStack {
                        TextField(String(localized: "Enter code"), text: $code)
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

                    // Code type hint
                    if !code.isEmpty {
                        HStack {
                            Image(systemName: code.hasPrefix("REMET-") ? "person.2" : "tag")
                                .font(.caption)
                            Text(code.hasPrefix("REMET-") ? String(localized: "Referral code") : String(localized: "Promo code"))
                                .font(.caption)
                        }
                        .foregroundStyle(AppColors.textMuted)
                    }
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
                            Text(String(localized: "Apply Code"))
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

                // Info text
                Text(String(localized: "Referral codes start with REMET-\nOther codes are promo codes"))
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .navigationTitle(String(localized: "Enter Code"))
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
            let result = await referralManager.applyCode(code)

            await MainActor.run {
                isSubmitting = false

                switch result {
                case .success(let applyResult):
                    successMessage = applyResult.message
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

// MARK: - Compact Inline Version

struct EnterCodeInlineView: View {
    @State private var referralManager = ReferralManager.shared
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row - tappable to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "ticket")
                        .foregroundStyle(AppColors.teal)

                    Text(String(localized: "Have a referral or promo code?"))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
            }

            if isExpanded {
                // Input field
                HStack {
                    TextField(String(localized: "Enter code"), text: $code)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .fontDesign(.monospaced)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { _, newValue in
                            code = newValue.uppercased()
                            errorMessage = nil
                        }

                    Button {
                        submitCode()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(String(localized: "Apply"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(code.isEmpty || isSubmitting)
                    .foregroundStyle(code.isEmpty ? AppColors.textMuted : AppColors.coral)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Messages
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.warning)
                }

                if let success = successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
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
            let result = await referralManager.applyCode(code)

            await MainActor.run {
                isSubmitting = false

                switch result {
                case .success(let applyResult):
                    successMessage = applyResult.message
                    code = ""
                    // Collapse after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isExpanded = false
                            successMessage = nil
                        }
                    }

                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }
}

#Preview {
    EnterReferralCodeView()
}
