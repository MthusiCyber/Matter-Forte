TalentBridge

An internship matching and placement management app designed for MCRI students, built with SwiftUI and Supabase.

Overview
TalentBridge connects students with internships based on their skills, projects, experience, and career interests. It helps employers find suitable candidates and gives program managers visibility into applications and placements.
Planned Features
- Students: Build profiles, showcase skills and projects, discover recommended internships, and track applications.
- Employers: Publish opportunities, define requirements, review applicants, and manage recruitment.
- Program managers: Monitor student readiness, applications, and placement outcomes.

Matching Approach
A transparent scoring system ranks opportunities using:
Criterion    Weight
Skills    50%
Project evidence    20%
Career interests    15%
Location and work preferences    10%
Availability    5%


Recommendations explain relevant strengths and skill gaps. Mandatory requirements are checked before ranking eligible opportunities. Scores support human decisions.

Tech Stack
- Frontend: SwiftUI and Swift
- Backend: Supabase Auth and PostgreSQL
- Security: Row Level Security and role-based access
- Architecture: MVVM

Getting Started
1. Open the app project in Xcode.
2. Add the Supabase Swift SDK.
3. Configure your Supabase project URL and public client key.
4. Apply database migrations and access policies.
5. Run on an iOS Simulator or device.
Never include a Supabase service-role or secret key in the app.

Project Status

Planned MVP for a 24-hour development challenge. Features and setup steps describe the intended implementation; application code and migrations have not been verified.
