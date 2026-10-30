import SwiftUI

private enum AuthStyle {
    static let orange = Color(red: 0.90, green: 0.40, blue: 0.21)
    // Darker orange keeps small text readable on the pale background.
    static let textOrange = Color.appTextOrange
}

struct AuthView: View {
    @ObservedObject var model: AuthViewModel
    @FocusState private var focused: Field?
    @State private var showingFeedback = false
    @State private var legalPage: LegalPage?
    private enum Field: Hashable { case fullName, email, password, confirmation }

    var body: some View {
        Group {
            if model.isRegistering { SignUpView(model: model) }
            else { loginForm }
        }
    }

    private var loginForm: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if model.isRegistering {
                        BrandLogo().padding(.top, 24).padding(.bottom, 30)
                        Text("Create Your Account")
                            .font(.system(.largeTitle, design: .default, weight: .bold))
                            .foregroundStyle(AuthStyle.orange)
                            .multilineTextAlignment(.center)
                        registrationFields.padding(.top, 30)
                    } else {
                        Text("Welcome Back")
                            .font(.system(.largeTitle, design: .default, weight: .bold))
                            .foregroundStyle(AuthStyle.orange)
                            .padding(.top, max(32, geometry.size.height * 0.07))
                        Text("To")
                            .font(.system(.largeTitle, design: .default, weight: .bold))
                            .foregroundStyle(AuthStyle.orange)
                            .padding(.top, 22)
                        BrandLogo().padding(.vertical, 48)
                        loginFields
                    }
                    if let notice = model.notice {
                        Text(notice).foregroundStyle(.primary).padding(.top, 16)
                            .accessibilityLabel(notice)
                    }
                    if let message = model.message {
                        Text(message).foregroundStyle(Color.red).font(.callout)
                            .multilineTextAlignment(.center).padding(.top, 16)
                            .accessibilityLabel("Error. " + message)
                    }
                    Button {
                        focused = nil
                        Task { await model.submit() }
                    } label: {
                        HStack(spacing: 10) {
                            if model.isLoading { ProgressView().tint(.white) }
                            Text(model.isLoading
                                 ? (model.isRegistering ? "Creating Account…" : "Signing In…")
                                 : (model.isRegistering ? "Create Account" : "Login"))
                                .font(.system(.title3, design: .default, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .foregroundStyle(.white)
                        .background(AuthStyle.orange, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(model.isLoading)
                    .opacity(model.isLoading ? 0.8 : 1)
                    .padding(.horizontal, 28).padding(.top, 30)

                    Button {
                        focused = nil
                        model.switchMode()
                    } label: {
                        (model.isRegistering
                         ? Text("Already have an Account? \(Text("Log In").bold())")
                         : Text("Don’t have an account? \(Text("Sign Up.").bold())"))
                            .font(.callout).foregroundStyle(AuthStyle.textOrange)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(model.isLoading)
                    .padding(.top, 14)
                    if model.isRegistering {
                        RegistrationLegalLinks(
                            error: model.errors["terms"],
                            onOpen: { page in
                                focused = nil
                                legalPage = page
                            }
                        )
                        .disabled(model.isLoading)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 28).padding(.bottom, 28)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LinearGradient(colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground), Color(uiColor: .systemBackground)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        }
        .sheet(item: $legalPage) { page in
            LegalFlowView(startingPage: page,
                          onAgree: { try model.acceptTerms($0) },
                          onFinish: { legalPage = nil })
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
        }
        .onChange(of: model.message) { _, message in
            if message != nil {
                focused = nil
                showingFeedback = true
            }
        }
        .onChange(of: model.notice) { _, notice in
            if notice != nil {
                focused = nil
                showingFeedback = true
            }
        }
        .alert(model.message == nil ? "Check Your Email" : "Unable to Continue", isPresented: $showingFeedback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.message ?? model.notice ?? "")
        }
    }

    private var loginFields: some View {
        VStack(spacing: 24) {
            emailField
            passwordField
        }.disabled(model.isLoading)
    }

    private var registrationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("I am signing up as")
                .font(.title3.weight(.semibold)).foregroundStyle(AuthStyle.textOrange)
            HStack(spacing: 0) {
                ForEach(AccountRole.allCases) { role in
                    Button { model.role = role } label: {
                        Text(role.title).font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(model.role == role ? .white : AuthStyle.textOrange)
                            .background(model.role == role ? AuthStyle.orange : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityAddTraits(model.role == role ? .isSelected : [])
                }
            }
            .background(AuthStyle.orange.opacity(0.23), in: RoundedRectangle(cornerRadius: 16))
            field("Full name", error: model.errors["fullName"]) {
                TextField("Enter Fullname", text: $model.fullName)
                    .textContentType(.name).textInputAutocapitalization(.words)
                    .focused($focused, equals: .fullName).submitLabel(.next)
                    .onSubmit { focused = .email }
            }
            emailField
            passwordField
            field("Confirm password", error: model.errors["confirmation"]) {
                SecureField("Confirm Password", text: $model.confirmation)
                    .textContentType(.newPassword)
                    .focused($focused, equals: .confirmation).submitLabel(.go)
                    .onSubmit {
                        focused = nil
                        Task { await model.submit() }
                    }
            }
        }.disabled(model.isLoading)
    }

    private var emailField: some View {
        field("Email address", error: model.errors["email"]) {
            TextField("Enter Email Address", text: $model.email)
                .keyboardType(.emailAddress).textContentType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused, equals: .email).submitLabel(.next)
                .onSubmit { focused = .password }
        }
    }

    private var passwordField: some View {
        field("Password", error: model.errors["password"]) {
            SecureField("Enter Password", text: $model.password)
                .textContentType(model.isRegistering ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(model.isRegistering ? .next : .go)
                .onSubmit {
                    if model.isRegistering { focused = .confirmation }
                    else {
                        focused = nil
                        Task { await model.submit() }
                    }
                }
        }
    }

    private func field<Content: View>(_ label: String, error: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Persistent labels remain visible after users start typing.
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
                .font(.system(.body, design: .default, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(error == nil ? AuthStyle.orange : .red, lineWidth: 2))
                .accessibilityLabel(label)
                .accessibilityHint(error ?? "")
            if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

private struct RegistrationLegalLinks: View {
    let error: String?
    let onOpen: (LegalPage) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("Before creating an account, please review:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Terms of Service") { onOpen(.terms) }
                .frame(maxWidth: .infinity, minHeight: 44)
            Button("Privacy Policy") { onOpen(.privacy) }
                .frame(maxWidth: .infinity, minHeight: 44)
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(AuthStyle.textOrange)
        .multilineTextAlignment(.center)
    }
}
