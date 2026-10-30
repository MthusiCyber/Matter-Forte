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
    case profile

    var title: String {
        switch self {
        case .postInternship: "Post Internship"
        case .applicants: "Applicants"
        case .internships: "Internships"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .postInternship: "plus.circle"
        case .applicants: "person.2"
        case .internships: "briefcase"
        case .profile: "person"
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
        case .profile:
            "Update your company profile and contact details."
        }
    }

    var menuTitle: String? {
        switch self {
        case .postInternship: nil
        case .applicants: "Applicants"
        case .internships: "Internships"
        case .profile: "Profile"
        }
    }

    static func menuRoute(for title: String) -> EmployerRoute? {
        switch title {
        case "Applicants": .applicants
        case "Internships": .internships
        case "Profile": .profile
        default: nil
        }
    }
}

struct EmployerDashboardView: View {
    
    private let orange = Color(red: 1.0, green: 0.39, blue: 0.15)
    private let cardGray = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let circleGray = Color(red: 0.85, green: 0.85, blue: 0.85)

    private let applicants = 61
    private let internships = 12

    private let onSignOut: (() -> Void)?

    init(onSignOut: (() -> Void)? = nil) {
        self.onSignOut = onSignOut
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
            .background(Color.white)
            .foregroundColor(.black)
            .buttonStyle(.plain)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EmployerRoute.self) { route in
                EmployerSectionView(route: route, onSignOut: onSignOut)
            }
        }
        .tint(orange)
        .preferredColorScheme(.light)
        .onChange(of: path) { _, newPath in
            selectedTab = newPath.last?.menuTitle ?? "Home"
        }
        .alert("Employer Dashboard", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
    }

    // Notification button

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

    //Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Find your next talent")
                .font(.system(size: 25, weight: .bold))

            Text("Your hiring overview")
                .font(.system(size: 21, weight: .light))
        }
        .padding(.leading, 11)
    }

    // Dashboard totals

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
                    Text("\(internships)")
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

    //  Summary cards

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

    // Parameters allow this function to create different cards.
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

    // Quick actions

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

    // Next interview

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
                        .foregroundColor(Color(white: 0.42))
                        .frame(width: 46, height: 40)
                        .background(Color(white: 0.92))
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

    // Bottom menu

    private var bottomMenu: some View {
        HStack(spacing: 6) {
            menuButton(title: "Home", symbol: "house")

            menuButton(title: "Applicants", symbol: "person.2")

            menuButton(title: "Internships", symbol: "briefcase")

            menuButton(title: "Profile", symbol: "person")
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
            selectedTab == title ? orange : .black
        )
        .background(
            selectedTab == title
                ? orange.opacity(0.35)
                : Color.clear
        )
        .cornerRadius(10)
    }
    // Button message

    private func displayMessage(_ text: String) {
        message = text
        showMessage = true
    }
}

/// Placeholder page reached from the employer dashboard navigation links.
private struct EmployerSectionView: View {

    let route: EmployerRoute
    var onSignOut: (() -> Void)? = nil

    private let orange = Color(red: 1.0, green: 0.39, blue: 0.15)

    var body: some View {
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

            if route == .profile, let onSignOut {
                Button(action: onSignOut) {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(orange)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }
}


#Preview(
    "EmployerDashboardView",
    traits: .fixedLayout(width: 402, height: 864)
) {
    EmployerDashboardView()
}
