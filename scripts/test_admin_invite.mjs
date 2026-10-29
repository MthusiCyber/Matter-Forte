import test from 'node:test';
import assert from 'node:assert/strict';

let handler;
let configured = true;
globalThis.Deno = {
  env: { get: name => configured ? (name === 'SUPABASE_URL' ? 'https://project.example' : 'test-server-key') : undefined },
  serve: callback => { handler = callback; },
};
await import('../supabase/functions/admin-invite-student/index.ts');

function request(body = {full_name:'Test Student',email:'student@example.com'}, auth = true, method = 'POST') {
  return new Request('https://project.example/functions/v1/admin-invite-student', {
    method, headers: auth ? {authorization:'Bearer user-session-token','content-type':'application/json'} : {},
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  });
}
function fakeFetch(replies) {
  const calls=[];
  globalThis.fetch=async (url, options) => {
    calls.push({url,options});
    const next=replies.shift();
    assert.ok(next,'Unexpected network call');
    return new Response(JSON.stringify(next.body),{status:next.status ?? 200});
  };
  return calls;
}

test('requires authentication before accessing Auth Admin endpoints',async () => {
  const calls=fakeFetch([]);
  assert.equal((await handler(request({},false))).status,401);
  assert.equal(calls.length,0);
});
test('rejects a student even if they submit an admin role in the payload',async () => {
  const calls=fakeFetch([{body:{app_metadata:{role:'student'}}}]);
  assert.equal((await handler(request({full_name:'A',email:'a@example.com',role:'admin'}))).status,403);
  assert.equal(calls.length,1);
});
test('requires a valid email before sending an invitation',async () => {
  const calls=fakeFetch([{body:{app_metadata:{role:'admin'}}}]);
  assert.equal((await handler(request({full_name:'A',email:'invalid'}))).status,400);
  assert.equal(calls.length,1);
});
test('administrator invitations always assign student access and return no secret',async () => {
  const calls=fakeFetch([
    {body:{app_metadata:{role:'admin'}}},
    {body:{id:'new-student-id',app_metadata:{provider:'email'}}},
    {body:{id:'new-student-id',app_metadata:{role:'student'}}},
  ]);
  const response=await handler(request({full_name:'New Student',email:'new@example.com',role:'admin'}));
  assert.equal(response.status,200);
  const invitation=JSON.parse(calls[1].options.body);
  const update=JSON.parse(calls[2].options.body);
  assert.equal(invitation.data.requested_role,'student');
  assert.equal(update.app_metadata.role,'student');
  const result=await response.json();
  assert.deepEqual(result,{id:'new-student-id',email:'new@example.com',invited:true});
  assert.ok(!JSON.stringify(result).includes('test-server-key'));
});
test('failed role assignment does not report successful completion',async () => {
  fakeFetch([{body:{app_metadata:{role:'admin'}}},{body:{id:'new-id'}},{status:500,body:{}}]);
  assert.equal((await handler(request())).status,502);
});
test('missing deployment configuration returns a service error',async () => {
  configured=false;
  try { assert.equal((await handler(request())).status,503); }
  finally { configured=true; }
});
