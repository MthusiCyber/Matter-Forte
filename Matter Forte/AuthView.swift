import SwiftUI

private enum AuthStyle {
    static let orange = Color(red: 0.90, green: 0.40, blue: 0.21)
    // Darker orange keeps small text readable on the pale background.
    static let textOrange = Color(red: 0.66, green: 0.23, blue: 0.09)
}

struct AuthView: View {
    @ObservedObject var model: AuthViewModel
    @FocusState private var focused: Field?
    private enum Field: Hashable { case fullName, email, password, confirmation }

    var body: some View {
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
                        (Text(model.isRegistering ? "Already have an Account? " : "Don’t have an account? ")
                         + Text(model.isRegistering ? "Log In" : "Sign Up.").bold())
                            .font(.callout).foregroundStyle(AuthStyle.textOrange)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(model.isLoading)
                    .padding(.top, 14)
                    if model.isRegistering {
                        Text("By creating an Account you agree to our Terms of Service and Privacy Policy.")
                            .font(.footnote).foregroundStyle(AuthStyle.textOrange)
                            .multilineTextAlignment(.center).padding(.top, 8)
                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 28).padding(.bottom, 28)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LinearGradient(colors: [.white, Color(red: 1, green: 0.96, blue: 0.99), .white],
                                       startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        }
        .preferredColorScheme(.light)
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
                    .onSubmit { Task { await model.submit() } }
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
                    else { Task { await model.submit() } }
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
                .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(error == nil ? AuthStyle.orange : .red, lineWidth: 2))
                .accessibilityLabel(label)
                .accessibilityHint(error ?? "")
            if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

/// Vector approximation from the supplied screenshot. Use an official logo asset when available.
private struct BrandLogo: View {
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width, h = proxy.size.height
                    path.move(to: CGPoint(x: w * 0.54, y: h * 0.06))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.25))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.78))
                    path.move(to: CGPoint(x: w * 0.88, y: h * 0.25))
                    path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.46))
                    path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.29))
                    path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.80))
                    path.addLine(to: CGPoint(x: w * 0.49, y: h * 0.96))
                }
                .stroke(LinearGradient(colors: [AuthStyle.orange, Color(red: 0.65, green: 0.17, blue: 0.13)],
                                       startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .square, lineJoin: .miter))
            }.frame(width: 76, height: 76)
            Text("MATTER").font(.system(size: 27, weight: .semibold)).tracking(7)
                .foregroundStyle(Color(red: 0.40, green: 0.30, blue: 0.34))
            Text("FORTE").font(.system(size: 11)).tracking(8).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Matter Forte")
    }
}
