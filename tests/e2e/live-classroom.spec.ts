import {expect,test} from '@playwright/test';

// Capabilities/session cookies must never enter browser test artifacts.
test.use({trace:'off',screenshot:'off',video:'off'});
test.describe.configure({retries:0});
const room='00000000-0000-4000-8000-000000160501';

test('M16.19 anonymous refresh cannot expose classroom or revive a known room capability',async({page})=>{
 let dailyRequests=0;
 await page.route('https://**.daily.co/**',route=>{dailyRequests++;return route.abort();});
 await page.goto(`/live-classroom/${room}?role=MASTER&providerRoomRef=known-room&token=old.token`);
 await expect(page).toHaveURL(/\/login(?:\?|$)/);
 await page.reload();await expect(page).toHaveURL(/\/login(?:\?|$)/);
 await expect(page.getByRole('button',{name:'Join classroom'})).toHaveCount(0);
 await expect(page.locator('iframe')).toHaveCount(0);
 expect(dailyRequests).toBe(0);
});

test('M16.19 real join endpoint denies anonymous exact IDs and forged identity without returning capability',async({request})=>{
 for(const body of [{liveSessionRoomId:room},{liveSessionRoomId:room,userId:room,role:'MASTER',cohortId:room,providerRoomRef:'known-room'}]){
  const response=await request.post('http://localhost:3100/api/live-classroom/join',{headers:{origin:'http://localhost:3100'},data:body,maxRedirects:0});
  expect(response.status()).toBe(403);
  expect(await response.json()).toEqual({error:'Live classroom unavailable. Check your access or try again.'});
  expect(response.headers()['cache-control']).toContain('no-store');
  expect(response.headers()['location']).toBeUndefined();
 }
});
