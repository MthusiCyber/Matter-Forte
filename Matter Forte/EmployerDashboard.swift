//
//  EmployerDashboard.swift
//  Matter Forte
//
//  Created by NYAMAYARO TAKUDZWA on 30/10/2026.
//

import SwiftUI

enum EmployerRoute: Hashable {
    case postInternship
    case applicants
    case internships
    case settings

    var title: String {
        switch self {
        case .postInternship: "Post Internship"
        case .applicants: "Applicants"
        case .internships: "Internships"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .postInternship: "plus.circle"
        case .applicants: "person.2"
        case .internships: "briefcase"
        case .settings: "gearshape"
        }
    }

    var detail: String {
        switch self {
        case .postInternship:
            "Create and publish a new internship listing for students."
        case .applicants:
            "Review the students who applied to your internships."
        case .internships:
            "Manage the internship listings you currently have open."
        case .settings:
            "Manage your account, appearance and preferences."
        }
    }

    var menuTitle: String? {
        switch self {
        case .postInternship: nil
        case .applicants: "Applicants"
        case .internships: "Internships"
        case .settings: "Settings"
        }
    }

    static func menuRoute(for title: String) -> EmployerRoute? {
        switch title {
        case "Applicants": .applicants
        case "Internships": .internships
        case "Settings": .settings
        default: nil
        }
    }
}

struct EmployerDashboardView<SettingsContent: View>: View {
    private let orange = Color(red: 1.0, green: 0.39, blue: 0.15)
    private let cardGray = Color(uiColor: .secondarySystemBackground)
    private let circleGray = Color(uiColor: .tertiarySystemFill)

    private let applicants = 61
    @State private var internships: Int?
    @State private var internshipCountFailed = false

    private let settings: () -> SettingsContent

    init(@ViewBuilder settings: @escaping () -> SettingsContent) {
        self.settings = settings
    }

    @State private var selectedTab = "Home"
    @State private var path: [EmployerRoute] = []
    @State private var showMessage = false
    @State private var message = ""

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        notificationButton

                        heading
                            .padding(.top, 27)

                        overviewCard
                            .padding(.leading, 10)
                            .padding(.top, 30)

                        summaryCards
                            .padding(.leading, 10)
                            .padding(.top, 32)

                        quickActions
                            .padding(.top, 26)

                        nextInterview
                            .padding(.top, 23)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                }

                bottomMenu
                    .padding(.horizontal, 22)
                    .padding(.bottom, 13)
            }
            .background(Color(uiColor: .systemBackground))
            .foregroundColor(.primary)
            .buttonStyle(.plain)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EmployerRoute.self) { route in
                EmployerSectionView(route: route, settings: settings)
                    .navigationTitle(route.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.visible, for: .navigationBar)
            }
        }
        .tint(orange)
        .task { await loadInternshipCount() }
        .onChange(of: path) { _, newPath in
            selectedTab = newPath.last?.menuTitle ?? "Home"
            if newPath.isEmpty { Task { await loadInternshipCount() } }
        }
        .alert("Employer Dashboard", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
    }

    private var notificationButton: some View {
        HStack {
            Spacer()

            Button {
                displayMessage("You have no new notifications.")
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .frame(width: 34, height: 34)
                    .background(circleGray)
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Notifications")
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Find your next talent")
                .font(.system(size: 25, weight: .bold))

            Text("Your hiring overview")
                .font(.system(size: 21, weight: .light))
        }
        .padding(.leading, 11)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("EMPLOYER DASHBOARD")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(orange)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {

                    Text("\(applicants)")
                        .font(.system(size: 34, weight: .bold))

                    Text("Applicants")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1, height: 69)

                VStack(alignment: .leading, spacing: 0) {
                    Text(internships.map(String.init) ?? (internshipCountFailed ? "—" : "…"))
                        .font(.system(size: 34, weight: .bold))

                    Text("Active internships")
                        .font(.system(size: 16, weight: .bold))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 29)
        .padding(.top, 21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 129, alignment: .top)
        .background(Color(white: 0.22))
        .cornerRadius(11)
    }

    private var summaryCards: some View {
        HStack(spacing: 15) {
            summaryCard(
                symbol: "person.2",
                number: "12",
                title: "shortlisted"
            )

            summaryCard(
                symbol: "calendar",
                number: "6",
                title: "Interviews"
            )
        }
    }

    private func summaryCard(
        symbol: String,
        number: String,
        title: String
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "calendar" ? 35 : 26))
                .frame(width: 56, height: 56)
                .background(circleGray)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(number)
                    .font(.system(size: 17, weight: .bold))

                Text(title)
                    .font(.system(size: 20, weight: .light))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 70)
        .background(cardGray)
        .cornerRadius(12)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 25, weight: .bold))

            NavigationLink(value: EmployerRoute.postInternship) {
                HStack(spacing: 22) {
                    Image(systemName: "plus.circle")

                    Text("Post Internship")
                }
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 51)
                .background(orange)
                .cornerRadius(10)
            }

            NavigationLink(value: EmployerRoute.applicants) {
                HStack(spacing: 15) {
                    Text("Review Applicants")
                        .font(.system(size: 20, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 25, weight: .light))
                }
                .foregroundColor(orange)
                .padding(.leading, 11)
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 11)
    }

    private var nextInterview: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Next Interview")
                .font(.system(size: 25, weight: .bold))

            HStack(spacing: 9) {
                Image(systemName: "person")
                    .font(.system(size: 34, weight: .medium))
                    .frame(width: 57, height: 57)
                    .background(circleGray)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Bae Coast")
                        .font(.system(size: 20, weight: .semibold))

                    Text("Tomorrow, 10:00 AM")
                        .font(.system(size: 16, weight: .light))

                    Text("Confirmed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(
                            Color(red: 1, green: 0.60, blue: 0.44)
                        )
                        .cornerRadius(10)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Button {
                    displayMessage(
                        "Interview with Bae Coast: tomorrow at 10:00 AM. Add your video meeting link here."
                    )
                } label: {
                    Image(systemName: "video")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .frame(width: 46, height: 40)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Interview video details")
            }
            .padding(.horizontal, 8)
            .frame(height: 98)
            .background(cardGray)
            .cornerRadius(12)
        }
        .padding(.horizontal, 11)
    }

    private var bottomMenu: some View {
        HStack(spacing: 6) {
            menuButton(title: "Home", symbol: "house")

            menuButton(title: "Applicants", symbol: "person.2")

            menuButton(title: "Internships", symbol: "briefcase")

            menuButton(title: "Settings", symbol: "gearshape")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(cardGray)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func menuButton(
        title: String,
        symbol: String
    ) -> some View {
        if let route = EmployerRoute.menuRoute(for: title) {
            NavigationLink(value: route) {
                menuLabel(title: title, symbol: symbol)
            }
            .accessibilityAddTraits(
                selectedTab == title ? .isSelected : []
            )
        } else {
            Button {
                path.removeAll()
            } label: {
                menuLabel(title: title, symbol: symbol)
            }
            .accessibilityAddTraits(
                selectedTab == title ? .isSelected : []
            )
        }
    }

    private func menuLabel(
        title: String,
        symbol: String
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .medium))

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .foregroundColor(
            selectedTab == title ? orange : .primary
        )
        .background(
            selectedTab == title
                ? orange.opacity(0.35)
                : Color.clear
        )
        .cornerRadius(10)
    }

    private func loadInternshipCount() async {
        do {
            let roles = try await InternshipService.load()
            try Task.checkCancellation()
            internships = roles.filter(\.isOpen).count
            internshipCountFailed = false
        } catch is CancellationError { return }
        catch { internshipCountFailed = true; internships = nil }
    }

    private func displayMessage(_ text: String) {
        message = text
        showMessage = true
    }
}

/// Destination for an employer dashboard route.
private struct EmployerSectionView<SettingsContent: View>: View {

    let route: EmployerRoute
    let settings: () -> SettingsContent

    private let orange = Color(red: 1.0, green: 0.39, blue: 0.15)

    var body: some View {
        switch route {
        case .postInternship:
            InternshipView(presentsAddOnAppear: true)
        case .internships:
            InternshipView()
        case .settings:
            settings()
        case .applicants:
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: route.symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(orange)

            Text(route.title)
                .font(.system(size: 25, weight: .bold))

            Text(route.detail)
                .font(.system(size: 16, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)


        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview(
    "EmployerDashboardView",
    traits: .fixedLayout(width: 402, height: 864)
) {
    EmployerDashboardView { SettingsView() }
}
