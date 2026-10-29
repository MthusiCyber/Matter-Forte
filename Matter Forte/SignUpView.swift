import SwiftUI

struct SignUpView: View {
    enum AccountRole: String, CaseIterable, Identifiable {
        case facilitator = "Facilitator"
        case employer = "Employer"

        var id: String { rawValue }
    }

    @State private var role: AccountRole = .facilitator
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var notice: String?
    @FocusState private var focusedField: Field?

    // Connect these actions when authentication and legal screens are available.
    var onCreateAccount: ((String, String, String, AccountRole) -> Void)?
    var onLogIn: (() -> Void)?
    var onTermsOfService: (() -> Void)?
    var onPrivacyPolicy: (() -> Void)?

    private enum Field: Hashable {
        case fullName, email, password, confirmPassword
    }

    private var isFormValid: Bool {
        SignUpValidation.fullName(fullName)
            && SignUpValidation.email(email)
            && SignUpValidation.password(password)
            && SignUpValidation.confirmation(confirmPassword, password: password)
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
                            role = option
                        } label: {
                            Text(option.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(role == option ? Color.white : Color.appOrange)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background {
                                    if role == option {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.appOrange)
                                    }
                                }
                        }
                        .accessibilityAddTraits(role == option ? [.isSelected] : [])
                    }
                }
                .padding(4)
                .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Account type")
            }

            VStack(spacing: 6) {
                fieldGroup("Full name", field: .fullName) {
                    TextField("Enter full name", text: $fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .fullName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }

                fieldGroup("Email address", field: .email) {
                    TextField("Enter email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldGroup("Password", field: .password) {
                    SecureField("Enter password", text: $password)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                }

                fieldGroup("Confirm password", field: .confirmPassword) {
                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit(createAccount)
                }
            }

            Button(action: createAccount) {
                Text("Create Account")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        isFormValid ? Color.appOrange : Color.gray,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(!isFormValid)
            .accessibilityHint(isFormValid ? "Create your account" : "Complete all fields with valid information")

            footer
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 340)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .tint(.appOrange)
        .buttonStyle(.plain)
        .alert("Matter Forte", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
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
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 11))
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
            let valid = SignUpValidation.fullName(fullName)
            return (valid, valid ? "Full name looks good." : "Please enter your full name.")
        case .email:
            let valid = SignUpValidation.email(email)
            return (valid, valid ? "Email format is valid." : "Enter a valid email, such as name@example.com.")
        case .password:
            let valid = SignUpValidation.password(password)
            return (valid, valid ? "Password meets all requirements." : "Use 8+ characters with a lowercase letter, uppercase letter, number and special character.")
        case .confirmPassword:
            let valid = SignUpValidation.confirmation(confirmPassword, password: password)
            if !SignUpValidation.password(password) {
                return (false, "First enter a password that meets all requirements.")
            }
            return (valid, valid ? "Passwords match." : "Enter the same password again.")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By creating an Account you agree to our")
            HStack(spacing: 3) {
                Button {
                    if let onTermsOfService { onTermsOfService() }
                    else { notice = "Terms of Service have not been added yet." }
                } label: {
                    Text("Terms of Service").underline()
                }
                Text("and")
                Button {
                    if let onPrivacyPolicy { onPrivacyPolicy() }
                    else { notice = "The Privacy Policy has not been added yet." }
                } label: {
                    Text("Privacy Policy.").underline()
                }
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.appOrange)
    }

    private func createAccount() {
        guard isFormValid else { return }
        focusedField = nil
        if let onCreateAccount {
            onCreateAccount(
                fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                email,
                password,
                role
            )
        } else {
            notice = "Your details are valid. Account creation is not connected yet."
        }
    }
}

#Preview {
    ContentView()
}
