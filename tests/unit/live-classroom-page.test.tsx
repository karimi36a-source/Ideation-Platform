// @vitest-environment jsdom
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,render,screen} from '@testing-library/react';
vi.mock('server-only',()=>({}));
vi.mock('@/features/live-classroom/classroom',()=>({getLiveClassroomView:vi.fn()}));
import {getLiveClassroomView} from '@/features/live-classroom/classroom';
import Page from '@/app/(platform)/live-classroom/[liveSessionRoomId]/page';
afterEach(()=>{cleanup();vi.clearAllMocks();});
it.each(['Student','Master'])('authorized %s renders only safe server view without token issuance',async()=>{vi.mocked(getLiveClassroomView).mockResolvedValue({liveSessionRoomId:'room',cohortName:'Authorized Cohort',sessionTitle:'Authorized Session',activity:null});render(await Page({params:Promise.resolve({liveSessionRoomId:'room'}),searchParams:Promise.resolve({})}));expect(screen.getByRole('heading',{name:'Authorized Session'})).toBeTruthy();expect(screen.queryByTitle('Daily live classroom')).toBeNull();});
it('unauthorized route returns safe denial with no provider details or join controls',async()=>{vi.mocked(getLiveClassroomView).mockRejectedValue(Error('private DAILY_API_KEY diagnostic'));render(await Page({params:Promise.resolve({liveSessionRoomId:'guessed'}),searchParams:Promise.resolve({})}));expect(screen.getByRole('alert').textContent).toContain('unavailable');expect(screen.queryByRole('button',{name:'Join classroom'})).toBeNull();expect(document.body.textContent).not.toMatch(/DAILY_API_KEY|diagnostic/);});

it('refresh resolves current authorization again and removes join controls after revocation',async()=>{
 const input={params:Promise.resolve({liveSessionRoomId:'room'}),searchParams:Promise.resolve({})};
 vi.mocked(getLiveClassroomView).mockResolvedValueOnce({liveSessionRoomId:'room',cohortName:'Authorized Cohort',sessionTitle:'Authorized Session',activity:null}).mockRejectedValueOnce(Error('Access revoked'));
 const first=render(await Page(input));expect(screen.getByRole('button',{name:'Join classroom'})).toBeTruthy();first.unmount();
 render(await Page(input));expect(getLiveClassroomView).toHaveBeenCalledTimes(2);expect(screen.getByRole('alert')).toBeTruthy();expect(screen.queryByRole('button',{name:'Join classroom'})).toBeNull();expect(screen.queryByTitle('Daily live classroom')).toBeNull();
});
