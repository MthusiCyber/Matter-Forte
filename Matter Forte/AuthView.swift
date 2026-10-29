<<<<<<< HEAD
=======
////
//import SwiftUI
//
//private enum AuthStyle {
//    static let orange = Color(
//        red: 0.90,
//        green: 0.40,
//        blue: 0.21
//    )
//
//    // Darker orange keeps small text readable on the pale background.
//    static let textOrange = Color(
//        red: 0.66,
//        green: 0.23,
//        blue: 0.09
//    )
//}
//
//struct AuthView: View {
//    @ObservedObject var model: AuthViewModel
//
//    @FocusState private var focused: Field?
//
//    private enum Field: Hashable {
//        case fullName
//        case email
//        case password
//        case confirmation
//    }
//
//    var body: some View {
//        GeometryReader { geometry in
//            ScrollView {
//                VStack(spacing: 0) {
//                    if model.isRegistering {
//                        BrandLogo()
//                            .padding(.top, 24)
//                            .padding(.bottom, 30)
//
//                        Text("Create Your Account")
//                            .font(
//                                .system(
//                                    .largeTitle,
//                                    design: .default,
//                                    weight: .bold
//                                )
//                            )
//                            .foregroundStyle(AuthStyle.orange)
//                            .multilineTextAlignment(.center)
//
//                        registrationFields
//                            .padding(.top, 32)
//                    } else {
//                        BrandLogo()
//                            .padding(.top, 24)
//                            .padding(.bottom, 40)
//
//                        loginFields
//                    }
//
//                    if let notice = model.notice {
//                        Text(notice)
//                            .foregroundStyle(.primary)
//                            .multilineTextAlignment(.center)
//                            .frame(maxWidth: .infinity)
//                            .padding(.top, 16)
//                            .accessibilityLabel(notice)
//                    }
//
//                    if let message = model.message {
//                        Text(message)
//                            .foregroundStyle(Color.red)
//                            .font(.callout)
//                            .multilineTextAlignment(.center)
//                            .padding(.top, 16)
//                            .accessibilityLabel("Error. " + message)
//                    }
//
//                    Button {
//                        focused = nil
//
//                        Task {
//                            await model.submit()
//                        }
//                    } label: {
//                        HStack(spacing: 10) {
//                            if model.isLoading {
//                                ProgressView()
//                                    .tint(.white)
//                            }
//
//                            Text(
//                                model.isLoading
//                                    ? (
//                                        model.isRegistering
//                                            ? "Creating Account…"
//                                            : "Signing In…"
//                                    )
//                                    : (
//                                        model.isRegistering
//                                            ? "Create Account"
//                                            : "Login"
//                                    )
//                            )
//                            .font(
//                                .system(
//                                    .title3,
//                                    design: .default,
//                                    weight: .semibold
//                                )
//                            )
//                        }
//                        .frame(maxWidth: .infinity)
//                        .frame(minHeight: 50)
//                        .foregroundStyle(.white)
//                        .background(
//                            AuthStyle.orange,
//                            in: RoundedRectangle(cornerRadius: 16)
//                        )
//                    }
//                    .disabled(model.isLoading)
//                    .opacity(model.isLoading ? 0.8 : 1)
//                    .padding(.top, 32)
//
//                    Button {
//                        focused = nil
//                        model.switchMode()
//                    } label: {
//                        let prompt = model.isRegistering
//                            ? "Already have an Account? "
//                            : "Don’t have an account? "
//
//                        let action = model.isRegistering
//                            ? "Log In"
//                            : "Sign Up."
//
//                        Text("\(prompt)\(Text(action).bold().underline())")
//                            .font(.callout)
//                            .foregroundStyle(AuthStyle.textOrange)
//                            .multilineTextAlignment(.center)
//                            .frame(
//                                maxWidth: .infinity,
//                                minHeight: 44
//                            )
//                    }
//                    .disabled(model.isLoading)
//                    .padding(.top, 16)
//
//                    if model.isRegistering {
//                        Text(
//                            "By creating an Account you agree to our Terms of Service and Privacy Policy."
//                        )
//                        .font(.footnote)
//                        .foregroundStyle(AuthStyle.textOrange)
//                        .multilineTextAlignment(.center)
//                        .padding(.top, 8)
//                    }
//                }
//                .frame(maxWidth: 430)
//                .padding(.horizontal, 28)
//                .padding(.bottom, 28)
//                .frame(
//                    maxWidth: .infinity,
//                    minHeight: geometry.size.height,
//                    alignment: .top
//                )
//            }
//            .scrollDismissesKeyboard(.interactively)
//            .background(
//                LinearGradient(
//                    colors: [
//                        .white,
//                        Color(red: 1, green: 0.96, blue: 0.99),
//                        .white
//                    ],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//                .ignoresSafeArea()
//            )
//        }
//        .buttonStyle(.plain)
//        .preferredColorScheme(.light)
//    }
//
//    private var loginFields: some View {
//        VStack(alignment: .leading, spacing: 24) {
//            emailField
//            passwordField
//        }
//        .disabled(model.isLoading)
//    }
//
//    private var registrationFields: some View {
//        VStack(alignment: .leading, spacing: 24) {
//            Text("I am signing up as")
//                .font(.title3.weight(.semibold))
//                .foregroundStyle(AuthStyle.textOrange)
//
//            HStack(spacing: 0) {
//                ForEach(AccountRole.allCases) { role in
//                    Button {
//                        model.role = role
//                    } label: {
//                        Text(role.title)
//                            .font(.headline)
//                            .frame(
//                                maxWidth: .infinity,
//                                minHeight: 48
//                            )
//                            .foregroundStyle(
//                                model.role == role
//                                    ? .white
//                                    : AuthStyle.textOrange
//                            )
//                            .background(
//                                model.role == role
//                                    ? AuthStyle.orange
//                                    : Color.clear,
//                                in: RoundedRectangle(cornerRadius: 16)
//                            )
//                    }
//                    .accessibilityAddTraits(
//                        model.role == role ? .isSelected : []
//                    )
//                }
//            }
//            .background(
//                AuthStyle.orange.opacity(0.23),
//                in: RoundedRectangle(cornerRadius: 16)
//            )
//
//            field("Full name", error: model.errors["fullName"]) {
//                TextField("Enter Fullname", text: $model.fullName)
//                    .textContentType(.name)
//                    .textInputAutocapitalization(.words)
//                    .focused($focused, equals: .fullName)
//                    .submitLabel(.next)
//                    .onSubmit {
//                        focused = .email
//                    }
//            }
//
//            emailField
//
//            passwordField
//
//            field(
//                "Confirm password",
//                error: model.errors["confirmation"]
//            ) {
//                SecureField(
//                    "Confirm Password",
//                    text: $model.confirmation
//                )
//                .textContentType(.newPassword)
//                .focused($focused, equals: .confirmation)
//                .submitLabel(.go)
//                .onSubmit {
//                    Task {
//                        await model.submit()
//                    }
//                }
//            }
//        }
//        .disabled(model.isLoading)
//    }
//
//    private var emailField: some View {
//        field("Email address", error: model.errors["email"]) {
//            TextField("Enter Email Address", text: $model.email)
//                .keyboardType(.emailAddress)
//                .textContentType(.emailAddress)
//                .textInputAutocapitalization(.never)
//                .autocorrectionDisabled()
//                .focused($focused, equals: .email)
//                .submitLabel(.next)
//                .onSubmit {
//                    focused = .password
//                }
//        }
//    }
//
//    private var passwordField: some View {
//        field("Password", error: model.errors["password"]) {
//            SecureField("Enter Password", text: $model.password)
//                .textContentType(
//                    model.isRegistering ? .newPassword : .password
//                )
//                .focused($focused, equals: .password)
//                .submitLabel(model.isRegistering ? .next : .go)
//                .onSubmit {
//                    if model.isRegistering {
//                        focused = .confirmation
//                    } else {
//                        Task {
//                            await model.submit()
//                        }
//                    }
//                }
//        }
//    }
//
//    private func field<Content: View>(
//        _ label: String,
//        error: String?,
//        @ViewBuilder content: () -> Content
//    ) -> some View {
//        VStack(alignment: .leading, spacing: 6) {
//            // Persistent labels remain visible after users start typing.
//            Text(label)
//                .font(.caption.weight(.semibold))
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 16)
//
//            content()
//                .font(
//                    .system(
//                        .body,
//                        design: .default,
//                        weight: .semibold
//                    )
//                )
//                .multilineTextAlignment(.leading)
//                .padding(.horizontal, 16)
//                .padding(.vertical, 14)
//                .frame(maxWidth: .infinity, minHeight: 50)
//                .background(
//                    .white.opacity(0.45),
//                    in: RoundedRectangle(cornerRadius: 15)
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 15)
//                        .stroke(
//                            error == nil ? AuthStyle.orange : .red,
//                            lineWidth: 2
//                        )
//                )
//                .accessibilityLabel(label)
//                .accessibilityHint(error ?? "")
//
//            if let error {
//                Text(error)
//                    .font(.caption)
//                    .foregroundStyle(.red)
//                    .fixedSize(horizontal: false, vertical: true)
//                    .padding(.horizontal, 16)
//            }
//        }
//    }
//}
//
///// Vector approximation from the supplied screenshot.
///// Use an official logo asset when available.
//private struct BrandLogo: View {
//    var body: some View {
//        VStack(spacing: 10) {
//            GeometryReader { proxy in
//                Path { path in
//                    let w = proxy.size.width
//                    let h = proxy.size.height
//
//                    path.move(
//                        to: CGPoint(x: w * 0.54, y: h * 0.06)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.88, y: h * 0.25)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.88, y: h * 0.78)
//                    )
//
//                    path.move(
//                        to: CGPoint(x: w * 0.88, y: h * 0.25)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.50, y: h * 0.46)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.15, y: h * 0.29)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.15, y: h * 0.80)
//                    )
//                    path.addLine(
//                        to: CGPoint(x: w * 0.49, y: h * 0.96)
//                    )
//                }
//                .stroke(
//                    LinearGradient(
//                        colors: [
//                            AuthStyle.orange,
//                            Color(
//                                red: 0.65,
//                                green: 0.17,
//                                blue: 0.13
//                            )
//                        ],
//                        startPoint: .bottomLeading,
//                        endPoint: .topTrailing
//                    ),
//                    style: StrokeStyle(
//                        lineWidth: 8,
//                        lineCap: .square,
//                        lineJoin: .miter
//                    )
//                )
//            }
//            .frame(width: 76, height: 76)
//
//            Text("MATTER")
//                .font(.system(size: 27, weight: .semibold))
//                .tracking(7)
//                .padding(.leading, 7)
//                .foregroundStyle(
//                    Color(red: 0.40, green: 0.30, blue: 0.34)
//                )
//
//            Text("FORTE")
//                .font(.system(size: 11))
//                .tracking(8)
//                .padding(.leading, 8)
//                .foregroundStyle(.secondary)
//        }
//        .accessibilityElement(children: .ignore)
//        .accessibilityLabel("Matter Forte")
//    }
//}

>>>>>>> origin/main
import SwiftUI

private enum AuthStyle {
    static let orange = Color(
        red: 0.90,
        green: 0.40,
        blue: 0.21
    )

    static let textOrange = Color(
        red: 0.66,
        green: 0.23,
        blue: 0.09
    )
}

struct AuthView: View {
    @ObservedObject var model: AuthViewModel

    @FocusState private var focused: Field?
    @State private var legalPage: LegalPage?

    private enum Field: Hashable {
        case fullName
        case email
        case password
        case confirmation
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if model.isRegistering {
                        BrandLogo()
                            .padding(.top, 24)
                            .padding(.bottom, 30)

                        Text("Create Your Account")
                            .font(
                                .system(
                                    .largeTitle,
                                    design: .default,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(AuthStyle.orange)
                            .multilineTextAlignment(.center)

                        registrationFields
                            .padding(.top, 32)
                    } else {
                        BrandLogo()
                            .padding(.top, 24)
                            .padding(.bottom, 40)

                        loginFields
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .accessibilityLabel(notice)
                    }

                    if let message = model.message {
                        Text(message)
                            .foregroundStyle(Color.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                            .accessibilityLabel("Error. " + message)
                    }

                    Button {
                        focused = nil

                        Task {
                            await model.submit()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if model.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(
                                model.isLoading
                                    ? (
                                        model.isRegistering
                                            ? "Creating Account…"
                                            : "Signing In…"
                                    )
                                    : (
                                        model.isRegistering
                                            ? "Create Account"
                                            : "Login"
                                    )
                            )
                            .font(
                                .system(
                                    .title3,
                                    design: .default,
                                    weight: .semibold
                                )
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .foregroundStyle(.white)
                        .background(
                            AuthStyle.orange,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(model.isLoading)
                    .opacity(model.isLoading ? 0.8 : 1)
                    .padding(.top, 32)

                    Button {
                        focused = nil
                        model.switchMode()
                    } label: {
                        let prompt = model.isRegistering
                            ? "Already have an Account? "
                            : "Don’t have an account? "

                        let action = model.isRegistering
                            ? "Log In"
                            : "Sign Up."

                        Text("\(prompt)\(Text(action).bold().underline())")
                            .font(.callout)
                            .foregroundStyle(AuthStyle.textOrange)
                            .multilineTextAlignment(.center)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 44
                            )
                    }
                    .disabled(model.isLoading)
                    .padding(.top, 16)

                    if model.isRegistering {
<<<<<<< HEAD
                        registrationLegalLinks.padding(.top, 8)
=======
                        Text(
                            "By creating an Account you agree to our Terms of Service and Privacy Policy."
                        )
                        .underline()
                        .font(.footnote)
                        .foregroundStyle(AuthStyle.textOrange)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
>>>>>>> origin/main
                    }
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height,
                    alignment: .top
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                LinearGradient(
                    colors: [
                        .white,
                        Color(red: 1, green: 0.96, blue: 0.99),
                        .white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
        .buttonStyle(.plain)
        .preferredColorScheme(.light)
        .sheet(item: $legalPage) { page in
            LegalFlowView(
                startingPage: page,
                onAgree: { document in try model.acceptTerms(document) },
                onFinish: { legalPage = nil }
            )
        }
    }

    private var registrationLegalLinks: some View {
        VStack(spacing: 4) {
            Text("Before creating an account, please review:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                focused = nil
                legalPage = .terms
            } label: {
                Text("Terms of Service")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            Button {
                focused = nil
                legalPage = .privacy
            } label: {
                Text("Privacy Policy")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            if model.hasAcceptedCurrentTerms {
                Label("Terms accepted", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .accessibilityLabel("You accepted the current Terms of Service.")
            }
            if let error = model.errors["terms"] {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(AuthStyle.textOrange)
        .multilineTextAlignment(.center)
        .disabled(model.isLoading)
    }

    private var loginFields: some View {
        VStack(alignment: .leading, spacing: 24) {
            emailField
            passwordField
        }
        .disabled(model.isLoading)
    }

    private var registrationFields: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("I am signing up as")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AuthStyle.textOrange)

            HStack(spacing: 0) {
                ForEach(AccountRole.allCases) { role in
                    Button {
                        model.role = role
                    } label: {
                        Text(role.title)
                            .font(.headline)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 48
                            )
                            .foregroundStyle(
                                model.role == role
                                    ? .white
                                    : AuthStyle.textOrange
                            )
                            .background(
                                model.role == role
                                    ? AuthStyle.orange
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                    }
                    .accessibilityAddTraits(
                        model.role == role ? .isSelected : []
                    )
                }
            }
            .background(
                AuthStyle.orange.opacity(0.23),
                in: RoundedRectangle(cornerRadius: 16)
            )

            field("Full name", error: model.errors["fullName"]) {
                TextField("Enter Fullname", text: $model.fullName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .focused($focused, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit {
                        focused = .email
                    }
            }

            emailField

            passwordField

            field(
                "Confirm password",
                error: model.errors["confirmation"]
            ) {
                SecureField(
                    "Confirm Password",
                    text: $model.confirmation
                )
                .textContentType(.newPassword)
                .focused($focused, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit {
                    Task {
                        await model.submit()
                    }
                }
            }
        }
        .disabled(model.isLoading)
    }

    private var emailField: some View {
        field("Email address", error: model.errors["email"]) {
            TextField("Enter Email Address", text: $model.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focused = .password
                }
        }
    }

    private var passwordField: some View {
        field("Password", error: model.errors["password"]) {
            SecureField("Enter Password", text: $model.password)
                .textContentType(
                    model.isRegistering ? .newPassword : .password
                )
                .focused($focused, equals: .password)
                .submitLabel(model.isRegistering ? .next : .go)
                .onSubmit {
                    if model.isRegistering {
                        focused = .confirmation
                    } else {
                        Task {
                            await model.submit()
                        }
                    }
                }
        }
    }

    private func field<Content: View>(
        _ label: String,
        error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            content()
                .font(
                    .system(
                        .body,
                        design: .default,
                        weight: .semibold
                    )
                )
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    .white.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 15)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            error == nil ? AuthStyle.orange : .red,
                            lineWidth: 2
                        )
                )
                .accessibilityLabel(label)
                .accessibilityHint(error ?? "")

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
        }
    }
}

<<<<<<< HEAD
=======
/// Vector approximation from the supplied screenshot.
/// Use an official logo asset when available.
private struct BrandLogo: View {
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height

                    path.move(
                        to: CGPoint(x: w * 0.54, y: h * 0.06)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.88, y: h * 0.25)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.88, y: h * 0.78)
                    )

                    path.move(
                        to: CGPoint(x: w * 0.88, y: h * 0.25)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.50, y: h * 0.46)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.15, y: h * 0.29)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.15, y: h * 0.80)
                    )
                    path.addLine(
                        to: CGPoint(x: w * 0.49, y: h * 0.96)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            AuthStyle.orange,
                            Color(
                                red: 0.65,
                                green: 0.17,
                                blue: 0.13
                            )
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .square,
                        lineJoin: .miter
                    )
                )
            }
            .frame(width: 76, height: 76)

            Text("MATTER")
                .font(.system(size: 27, weight: .semibold))
                .tracking(7)
                .padding(.leading, 7)
                .foregroundStyle(
                    Color(red: 0.40, green: 0.30, blue: 0.34)
                )

            Text("FORTE")
                .font(.system(size: 11))
                .tracking(8)
                .padding(.leading, 8)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Matter Forte")
    }
}
>>>>>>> origin/main
