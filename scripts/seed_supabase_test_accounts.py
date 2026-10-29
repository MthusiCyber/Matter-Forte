#!/usr/bin/env python3
"""Create 20 new MCRI test accounts through Supabase Auth's Admin API.

No package installation required. A project secret/service-role key is prompted
securely or read from SUPABASE_SECRET_KEY / SUPABASE_SERVICE_ROLE_KEY.
The privileged key is never saved. Reruns reuse this batch without duplicates.
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
    existing = {user["email"].lower(): user for user in api.users() if user.get("email")}
    saved = json.loads(credential_path.read_text()) if credential_path.exists() else {
        "project_url": PROJECT_URL, "seed_batch": BATCH, "accounts": []}
    if saved.get("project_url") != PROJECT_URL or saved.get("seed_batch") != BATCH:
        raise RuntimeError("The credentials file belongs to a different project or seed batch.")
    passwords = {row["email"]: row for row in saved["accounts"]}
    # Preflight every address before making changes. Never overwrite an unrelated user.
    for account in plan:
        user = existing.get(account["email"])
        if user and user.get("app_metadata", {}).get("seed_batch") != BATCH:
            raise RuntimeError(f"Address collision: {account['email']} is not owned by this seed batch.")
        if user and account["email"] not in passwords:
            raise RuntimeError("An existing test account has no saved login. Reuse the original credentials file; no password was reset.")
    for account in plan:
        email = account["email"]
        if email not in passwords:
            passwords[email] = dict(account, password=secrets.token_urlsafe(20) + "aA1!")
        saved["accounts"] = list(passwords.values())
        # Save before the API request so a retry can recover after an interruption.
        save_credentials(credential_path, saved)
        user = existing.get(email)
        user_metadata = {key: value for key, value in account.items() if key not in ("role", "email")}
        user_metadata.update(requested_role=account["role"], seed_batch=BATCH)
        app_metadata = {"role": account["role"], "seed_batch": BATCH}
        if account["role"] == "admin":
            app_metadata["admin_request_status"] = "approved"
        if user is None:
            result = api.request("POST", "/auth/v1/admin/users", {
                "email": email, "password": passwords[email]["password"],
                "email_confirm": True, "user_metadata": user_metadata, "app_metadata": app_metadata,
            })
            user = result.get("user", result)
        # Signup triggers may initially mark the second admin pending. The Admin
        # API explicitly grants the two test admins the requested server role.
        result = api.request("PUT", f"/auth/v1/admin/users/{user['id']}", {
            "app_metadata": app_metadata, "user_metadata": user_metadata, "email_confirm": True,
        })
        user = result.get("user", result)
        if user.get("app_metadata", {}).get("role") != account["role"]:
            raise RuntimeError(f"Role verification failed for {email}.")
        if account["role"] == "admin":
            api.request("PATCH", f"/rest/v1/matter_forte_admin_requests?user_id=eq.{user['id']}",
                {"status": "approved"}, allow_missing=True)
        passwords[email]["user_id"] = user["id"]
        save_credentials(credential_path, saved)
        print(f"Ready: {email} ({account['role']})", flush=True)
    # Verify all twenty through an independent listing, rather than request status alone.
    verified = {user["email"].lower(): user for user in api.users() if user.get("email")}
    for account in plan:
        user = verified.get(account["email"], {})
        if user.get("app_metadata", {}).get("role") != account["role"] or not user.get("email_confirmed_at"):
            raise RuntimeError(f"Final verification failed for {account['email']}.")
    print(f"Verified 20 test accounts: 2 admins and 18 students. Logins saved to {credential_path.resolve()}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Show the 20 planned accounts without credentials or network access")
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
