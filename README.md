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

MVP in development. Navigation and authentication screens have been compiled and exercised in the simulator. Database features require the included Supabase migrations; the current repository does not imply a production deployment.


Integrated navigation

The dashboard branch combines main's welcome, authentication and legal flow with
the student portfolio and settings feature branches. Signup retains main's Admin
and Employer choices. One authentication model controls session restoration,
confirmation links, role routing and sign-out. Approved administrators open the
dashboard. Student portfolios are maintained by administrators; students do not
have app access and are never offered signup, login or email invitations.

Student data and backend setup

The app uses the same Supabase project and public configuration as main. There
are no local sample students. Administrators add and edit portfolios through the
matter_forte_students table and protected RPCs. The navigation migration preserves
any earlier student data; it does not delete accounts or alter existing admins.

Apply SQL files in supabase/migrations in filename order. Existing projects should
apply 202610300003_navigation_integration.sql to enable portfolio CRUD and fix the
old student function's return-type error. No Edge Function or privileged key is
embedded in the app. Reported-issue management is not implemented by the available
feature branches.

The test-data seeder creates two test administrator Auth accounts and eighteen
student portfolio records, not student Auth accounts. Existing project data is
preserved. The privileged key is entered privately and is never stored in code.

Navigation checks

Role-routing checks are in scripts/check_navigation.swift. They verify that only
server-authorized admins open the dashboard and student accounts cannot enter it.


Internship persistence

Apply `supabase/migrations/202610300004_internships.sql` after the earlier migrations.
It extends the existing `public.internships` table without deleting records, adds
checked save/list RPCs, and connects dashboard internship counts to open listings.
Employers see their own listings; administrators see all listings. Ownership uses
`posted_by` referencing `auth.users`; the legacy `created_by` reference is preserved.
App saves use the signed-in session and public key. No privileged key is needed.
The form waits for a successful database response and retains inputs on failure.
Retrying a draft uses the same ID to avoid duplicate listings.

The phone's old `matter.internships.v1` cache is left intact but is no longer used
as the live listing source. Old sample listings are not automatically published.
