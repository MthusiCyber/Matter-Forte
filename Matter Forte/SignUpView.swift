import SwiftUI

struct SignUpView: View {
    @ObservedObject var model: AuthViewModel
    @State private var legalPage: LegalPage?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case fullName, email, password, confirmPassword
    }

    private var isFormValid: Bool {
        SignUpValidation.fullName(model.fullName)
            && SignUpValidation.email(model.email)
            && SignUpValidation.password(model.password)
            && SignUpValidation.confirmation(model.confirmation, password: model.password)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image("matter_forte_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityLabel("Matter Forte")

            Text("Create Your Account")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.appOrange)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                Text("I am signing up as")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appOrange)
                HStack(spacing: 4) {
                    ForEach(AccountRole.allCases) { option in
                        Button {
                            model.role = option
                        } label: {
                            Text(option.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(model.role == option ? Color.white : Color.appOrange)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background {
                                    if model.role == option {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.appOrange)
                                    }
                                }
                        }
                        .accessibilityAddTraits(model.role == option ? [.isSelected] : [])
                    }
                }
                .padding(4)
                .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Account type")
            }

            VStack(spacing: 6) {
                fieldGroup("Full name", field: .fullName) {
                    TextField("Enter full name", text: $model.fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .fullName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }

                fieldGroup("Email address", field: .email) {
                    TextField("Enter email address", text: $model.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldGroup("Password", field: .password) {
                    SecureField("Enter password", text: $model.password)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                }

                fieldGroup("Confirm password", field: .confirmPassword) {
                    SecureField("Confirm password", text: $model.confirmation)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit(createAccount)
                }
            }

            Button(action: createAccount) {
                Text(model.isLoading ? "Creating Account…" : "Create Account")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        canSubmit ? Color.appOrange : Color.gray,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(!canSubmit)
            .accessibilityHint(canSubmit ? "Create your account" : "Complete all fields with valid information")

            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            footer
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 340)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .tint(.appOrange)
        .buttonStyle(.plain)
        .sheet(item: $legalPage) { page in
            LegalFlowView(startingPage: page, onAgree: model.acceptTerms, onFinish: { legalPage = nil })
        }
        .disabled(model.isLoading)
    }

    private var canSubmit: Bool {
        isFormValid && model.hasAcceptedCurrentTerms && !model.isLoading
    }

    private func fieldGroup<Content: View>(
        _ title: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let feedback = feedback(for: field)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appOrange)
            content()
                .accessibilityLabel(title)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color.appOrange, lineWidth: focusedField == field ? 2.5 : 1.5)
                }
            // Reserve the same space even when this field is not focused.
            Label(feedback.message, systemImage: feedback.valid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(feedback.valid ? Color.green : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28, alignment: .topLeading)
                .opacity(focusedField == field ? 1 : 0)
                .accessibilityHidden(focusedField != field)
                .accessibilityIdentifier("signup.feedback")
        }
    }

    private func feedback(for field: Field) -> (valid: Bool, message: String) {
        switch field {
        case .fullName:
            let valid = SignUpValidation.fullName(model.fullName)
            return (valid, valid ? "Full name looks good." : "Please enter your full name.")
        case .email:
            let valid = SignUpValidation.email(model.email)
            return (valid, valid ? "Email format is valid." : "Enter a valid email, such as name@example.com.")
        case .password:
            let valid = SignUpValidation.password(model.password)
            return (valid, valid ? "Password meets all requirements." : "Use 8+ characters with a lowercase letter, uppercase letter, number and special character.")
        case .confirmPassword:
            let valid = SignUpValidation.confirmation(model.confirmation, password: model.password)
            if !SignUpValidation.password(model.password) {
                return (false, "First enter a password that meets all requirements.")
            }
            return (valid, valid ? "Passwords match." : "Enter the same password again.")
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button("Already have an account? Log In") { model.switchMode() }
                .frame(minHeight: 34)
            HStack(spacing: 12) {
                Button("Terms of Service") { focusedField = nil; legalPage = .terms }
                Button("Privacy Policy") { focusedField = nil; legalPage = .privacy }
            }
            .frame(minHeight: 34)
            if model.hasAcceptedCurrentTerms {
                Label("Terms accepted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text("Read and accept the Terms of Service to create your account.")
            }
            if let error = model.errors["terms"] { Text(error).foregroundStyle(.red) }
        }
        .font(.caption)
        .foregroundStyle(Color.appOrange)
        .multilineTextAlignment(.center)
    }

    private func createAccount() {
        guard canSubmit else { return }
        focusedField = nil
        Task { await model.submit() }
    }
}
