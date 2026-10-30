#!/usr/bin/env python3
"""Create 2 MCRI test admin accounts and 18 administrator-managed student portfolios.

No package installation required. A project secret/service-role key is prompted
securely or read from SUPABASE_SECRET_KEY / SUPABASE_SERVICE_ROLE_KEY.
The privileged key is never saved. Reruns reuse this batch without duplicates.
Students are database records only and do not receive authentication accounts.
"""
import argparse
import getpass
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile
import urllib.error
import urllib.request

PROJECT_URL = "https://qatipvdlgcwhmcabegjl.supabase.co"
BATCH = "matter-forte-mcri-test-20-v1"
NAMES = [
    "Tendai Dube", "Chipo Ndlovu", "Amanda Cio", "Taku Moyo",
    "Rudo Ncube", "Nyasha Banda", "Farai Chirwa", "Tatenda Sibanda",
    "Rutendo Zulu", "Kudzai Mlambo", "Tariro Moyo", "Simba Ncube",
    "Ruvimbo Dube", "Tanaka Ndlovu", "Anesu Banda", "Tinashe Chirwa",
    "Vimbai Sibanda", "Kundai Zulu", "Sharon Mlambo", "Brian Moyo",
]
PROGRAMMES = ["Software Engineering", "Information Systems", "Business Administration", "Data Science", "Accounting", "Marketing"]


def account_plan(institute="MCRI"):
    return [dict(
        full_name=name, role="admin" if index < 2 else "student",
        email=f"matterforte.test.{'admin' if index < 2 else 'student'}{index + 1 if index < 2 else index - 1:02d}@example.com",
        institute=institute,
        programme="Administration" if index < 2 else PROGRAMMES[(index - 2) % len(PROGRAMMES)],
        student_number="" if index < 2 else f"MCRI-TEST-{index - 1:03d}",
    ) for index, name in enumerate(NAMES)]


class AdminAPI:
    def __init__(self, key):
        self.key = key

    def request(self, method, route, payload=None, allow_missing=False):
        headers = {"apikey": self.key, "Content-Type": "application/json"}
        # Legacy service_role keys are JWTs; new sb_secret keys go in apikey only.
        if not self.key.startswith("sb_secret_"):
            headers["Authorization"] = f"Bearer {self.key}"
        request = urllib.request.Request(PROJECT_URL + route, method=method,
            headers=headers, data=None if payload is None else json.dumps(payload).encode())
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            body = error.read().decode()
            if allow_missing and error.code == 404 and 'PGRST205' in body:
                return None
            # Never print the credential if an upstream error unexpectedly includes it.
            detail = body.replace(self.key, "[REDACTED]")[:700]
            raise RuntimeError(f"Supabase returned HTTP {error.code}: {detail}") from None
        except urllib.error.URLError as error:
            raise RuntimeError(f"Unable to connect to Supabase: {error.reason}") from None

    def users(self):
        users, page = [], 1
        while True:
            result = self.request("GET", f"/auth/v1/admin/users?page={page}&per_page=100")
            batch = result.get("users", [])
            users.extend(batch)
            if len(batch) < 100:
                return users
            page += 1


def save_credentials(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp = tempfile.mkstemp(prefix=".mcri-seed-", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w") as output:
            json.dump(data, output, indent=2)
            output.write("\n")
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def seed(api, plan, credential_path):
    admins = [row for row in plan if row["role"] == "admin"]
    students = [row for row in plan if row["role"] == "student"]
    if len(admins) != 2 or len(students) != 18:
        raise RuntimeError("Expected exactly two admins and eighteen student records.")
    auth_users = {user["email"].lower(): user for user in api.users() if user.get("email")}
    table = "/rest/v1/matter_forte_students"
    profiles = {row["email"].lower(): row for row in api.request("GET", table + "?select=id,email,seed_batch")}
    saved = json.loads(credential_path.read_text()) if credential_path.exists() else {
        "project_url": PROJECT_URL, "seed_batch": BATCH, "accounts": []}
    if saved.get("project_url") != PROJECT_URL or saved.get("seed_batch") != BATCH:
        raise RuntimeError("The credentials file belongs to a different project or seed batch.")
    logins = {row["email"]: row for row in saved["accounts"] if row.get("role") == "admin"}
    # Check both datasets before creating any accounts or changing any records.
    for account in admins:
        user = auth_users.get(account["email"])
        if user and user.get("app_metadata", {}).get("seed_batch") != BATCH:
            raise RuntimeError(f"Address collision: {account['email']} is not owned by this seed batch.")
        if user and account["email"] not in logins:
            raise RuntimeError("An existing test admin has no saved login. Reuse the original credentials file; no password was reset.")
    for student in students:
        profile = profiles.get(student["email"])
        if profile and profile.get("seed_batch") != BATCH:
            raise RuntimeError(f"Student address collision: {student['email']} is not owned by this seed batch.")
    saved["student_profiles"] = []
    for account in admins:
        email = account["email"]
        if email not in logins:
            logins[email] = dict(account, password=secrets.token_urlsafe(20) + "aA1!")
        saved["accounts"] = list(logins.values())
        save_credentials(credential_path, saved)
        metadata = {key: value for key, value in account.items() if key not in ("role", "email")}
        metadata.update(requested_role="admin", seed_batch=BATCH)
        app_metadata = {"role": "admin", "seed_batch": BATCH, "admin_request_status": "approved"}
        user = auth_users.get(email)
        if user is None:
            result = api.request("POST", "/auth/v1/admin/users", {
                "email": email, "password": logins[email]["password"], "email_confirm": True,
                "user_metadata": metadata, "app_metadata": app_metadata,
            })
            user = result.get("user", result)
        result = api.request("PUT", f"/auth/v1/admin/users/{user['id']}", {
            "app_metadata": app_metadata, "user_metadata": metadata, "email_confirm": True,
        })
        user = result.get("user", result)
        if user.get("app_metadata", {}).get("role") != "admin":
            raise RuntimeError(f"Role verification failed for {email}.")
        api.request("PATCH", f"/rest/v1/matter_forte_admin_requests?user_id=eq.{user['id']}",
                    {"status": "approved"}, allow_missing=True)
        logins[email]["user_id"] = user["id"]
        save_credentials(credential_path, saved)
        print(f"Ready: {email} (administrator login)", flush=True)
    for index, student in enumerate(students):
        profile = profiles.get(student["email"])
        if profile is None:
            payload = {key: value for key, value in student.items() if key != "role"}
            payload.update(seed_batch=BATCH, cohort=f"Cohort {6 + index // 6}",
                biography="Institute student portfolio for testing.",
                skills=["Research", "Data analysis"], essential_skills=["Communication", "Teamwork"])
            api.request("POST", table, payload)
        saved["student_profiles"].append(dict(student))
        save_credentials(credential_path, saved)
        print(f"Ready: {student['full_name']} (student portfolio; no app login)", flush=True)
    verified_auth = {user["email"].lower(): user for user in api.users() if user.get("email")}
    verified_profiles = {row["email"].lower(): row for row in api.request("GET", table + "?select=id,email,seed_batch")}
    for account in admins:
        user = verified_auth.get(account["email"], {})
        if user.get("app_metadata", {}).get("role") != "admin" or not user.get("email_confirmed_at"):
            raise RuntimeError(f"Final verification failed for {account['email']}.")
    for student in students:
        if verified_profiles.get(student["email"], {}).get("seed_batch") != BATCH:
            raise RuntimeError(f"Final verification failed for {student['email']}.")
    print(f"Verified 2 administrator logins and 18 student portfolios. Students have no app logins. Admin credentials saved to {credential_path.resolve()}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Show two planned admin accounts and eighteen student portfolios without making changes")
    parser.add_argument("--institute", default="MCRI")
    parser.add_argument("--credentials", type=Path, default=Path("work/mcri-test-logins.json"))
    args = parser.parse_args()
    plan = account_plan(args.institute)
    if args.dry_run:
        print(json.dumps(plan, indent=2))
        return
    key = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if not key:
        key = getpass.getpass("Supabase secret/service-role key (hidden; not saved): ").strip()
    if not key or key.startswith("sb_publishable_"):
        raise RuntimeError("A privileged project secret/service-role key is required; the app's public key cannot create these accounts.")
    seed(AdminAPI(key), plan, args.credentials)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        print(f"Seed stopped: {error}", file=sys.stderr)
        sys.exit(1)
