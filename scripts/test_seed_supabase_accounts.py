import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import uuid
from contextlib import redirect_stdout
from io import StringIO

spec = importlib.util.spec_from_file_location('seed', Path(__file__).with_name('seed_supabase_test_accounts.py'))
seed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(seed)

class FakeAPI:
    def __init__(self, users=None, profiles=None):
        self.records = copy.deepcopy(users or [])
        self.profiles = copy.deepcopy(profiles or [])
        self.auth_creates = 0
        self.profile_creates = 0
        self.updates = 0
    def users(self): return copy.deepcopy(self.records)
    def request(self, method, route, payload=None, allow_missing=False):
        if route.startswith('/rest/v1/matter_forte_students'):
            if method == 'GET': return copy.deepcopy(self.profiles)
            if method == 'POST':
                self.profile_creates += 1
                self.profiles.append(dict(payload, id=str(uuid.uuid4())))
                return None
        if method == 'POST' and route == '/auth/v1/admin/users':
            self.auth_creates += 1
            if payload['app_metadata']['role'] != 'admin': raise AssertionError('Students must not get Auth accounts')
            user = dict(id=str(uuid.uuid4()), email=payload['email'], email_confirmed_at='2026-10-30T00:00:00Z',
                        app_metadata=copy.deepcopy(payload['app_metadata']), user_metadata=payload['user_metadata'])
            user['app_metadata']['role'] = 'pending_admin'
            self.records.append(user)
            return copy.deepcopy(user)
        if method == 'PUT':
            self.updates += 1
            user = next(user for user in self.records if user['id'] == route.rsplit('/',1)[1])
            user.update(copy.deepcopy(payload))
            return copy.deepcopy(user)
        if method == 'PATCH': return None
        raise AssertionError((method,route))

class SeedTests(unittest.TestCase):
    def test_two_admin_logins_eighteen_profiles_and_safe_rerun(self):
        existing = dict(id='real-admin', email='existing@example.com', app_metadata={'role':'admin'})
        api = FakeAPI([existing])
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(StringIO()):
            path = Path(directory)/'logins.json'
            seed.seed(api,seed.account_plan(),path)
            self.assertEqual(api.auth_creates,2)
            self.assertEqual(api.profile_creates,18)
            self.assertEqual(len(api.records),3)
            self.assertEqual(api.records[0],existing)
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            saved=json.loads(path.read_text())
            self.assertEqual(len(saved['accounts']),2)
            self.assertEqual(len(saved['student_profiles']),18)
            self.assertTrue(all('password' not in student for student in saved['student_profiles']))
            seed.seed(api,seed.account_plan(),path)
            self.assertEqual(api.auth_creates,2)
            self.assertEqual(api.profile_creates,18)
            self.assertEqual(json.loads(path.read_text()),saved)
    def test_student_address_collision_stops_before_creating_admins(self):
        api=FakeAPI(profiles=[dict(email=seed.account_plan()[5]['email'],seed_batch=None)])
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError,'Student address collision'):
                seed.seed(api,seed.account_plan(),Path(directory)/'logins.json')
            self.assertEqual(api.auth_creates+api.updates+api.profile_creates,0)
    def test_missing_admin_credentials_does_not_reset_password(self):
        api=FakeAPI([dict(id='old-admin',email=seed.account_plan()[0]['email'],app_metadata={'seed_batch':seed.BATCH})])
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError,'no saved login'):
                seed.seed(api,seed.account_plan(),Path(directory)/'logins.json')
            self.assertEqual(api.auth_creates+api.updates,0)

if __name__=='__main__': unittest.main()
