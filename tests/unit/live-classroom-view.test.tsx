// @vitest-environment jsdom
import {afterEach,beforeEach,expect,it,vi} from 'vitest';
import {act,cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import {LiveClassroom} from '@/features/live-classroom/classroom-view';
const fetchMock=vi.fn();
const state={liveSessionRoomId:'00000000-0000-4000-8000-000000160501',cohortName:'Pilot Cohort',sessionTitle:'Session 7',activity:{activityInstanceId:'00000000-0000-4000-8000-000000160342',activityType:'mind_map',name:'Mind Map',status:'active',href:'/activities/00000000-0000-4000-8000-000000160342/mind-map',projectName:'Authorized project',teamName:'Team A'}};
beforeEach(()=>{vi.stubGlobal('fetch',fetchMock);fetchMock.mockReset().mockImplementation(async()=>({ok:true,json:async()=>({url:'https://pilot.daily.co/canonical-room',token:'ephemeral.join.token',expiresAt:Math.floor(Date.now()/1000)+60})}));});
afterEach(()=>{cleanup();vi.useRealTimers();vi.unstubAllGlobals();});
it.each(['Student','Master'])('authorized %s renders and opens only secure Daily frame',async()=>{
 render(<LiveClassroom state={state}/>);expect(screen.getByRole('heading',{name:'Session 7'})).toBeTruthy();expect(screen.getByText('Cohort: Pilot Cohort')).toBeTruthy();fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));
 const frame=await screen.findByTitle('Daily live classroom');expect(new URL(frame.getAttribute('src')!).origin).toBe('https://pilot.daily.co');expect(fetchMock).toHaveBeenCalledWith('/api/live-classroom/join',expect.objectContaining({method:'POST',cache:'no-store',body:JSON.stringify({liveSessionRoomId:state.liveSessionRoomId})}));
 expect(frame.getAttribute('referrerpolicy')).toBe('no-referrer');expect(document.body.textContent).not.toContain('ephemeral.join.token');expect(window.location.href).not.toContain('ephemeral');expect(localStorage.length).toBe(0);expect(sessionStorage.length).toBe(0);
});
it('links to existing authorized Activity route with normal keyboard controls',()=>{render(<LiveClassroom state={state}/>);expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);expect(screen.getByRole('button',{name:'Join classroom'}).getAttribute('type')).toBe('button');expect(screen.getByRole('status')).toBeTruthy();});
it('loading, leave and rejoin use only token transport, never educational mutation',async()=>{
 render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));expect(screen.getByRole('status').textContent).toContain('Preparing');await screen.findByTitle('Daily live classroom');fireEvent.click(screen.getByRole('button',{name:'Leave classroom'}));expect(screen.queryByTitle('Daily live classroom')).toBeNull();fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));await screen.findByTitle('Daily live classroom');expect(fetchMock).toHaveBeenCalledTimes(2);expect(fetchMock.mock.calls.every(c=>c[0]==='/api/live-classroom/join')).toBe(true);
});
it.each(['denied','provider','unsafe-url','expired'])('safe %s error with no frame or diagnostic disclosure',async kind=>{
 fetchMock.mockImplementation(async()=>kind==='provider'?Promise.reject(Error('DAILY_API_KEY private diagnostic')):{ok:kind!=='denied',json:async()=>({url:kind==='unsafe-url'?'https://evil.example/room':'https://pilot.daily.co/room',token:'ephemeral.join.token',expiresAt:kind==='expired'?1:Math.floor(Date.now()/1000)+60})});render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));await screen.findByRole('button',{name:'Try joining again'});expect(screen.queryByTitle('Daily live classroom')).toBeNull();expect(document.body.textContent).not.toMatch(/DAILY_API_KEY|private diagnostic|ephemeral.join.token/);
});
it('leave during pending request cannot reopen a stale frame',async()=>{let done!:(v:unknown)=>void;fetchMock.mockImplementation(()=>new Promise(resolve=>{done=resolve;}));render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));fireEvent.click(screen.getByRole('button',{name:'Leave classroom'}));done({ok:true,json:async()=>({url:'https://pilot.daily.co/room',token:'test',expiresAt:Math.floor(Date.now()/1000)+60})});await waitFor(()=>expect(screen.queryByTitle('Daily live classroom')).toBeNull());expect(screen.getByRole('status').textContent).toBe('You are not connected.');});
it('no selected Activity uses existing current-work route without inventing state',()=>{render(<LiveClassroom state={{...state,activity:null}}/>);expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe('/current-work');});

it('multiple current Activities remain explicit candidates with no arbitrary selection',()=>{const second={...state.activity,activityInstanceId:'00000000-0000-4000-8000-000000160343',name:'Second Activity',href:'/current-work'};render(<LiveClassroom state={{...state,activity:null,activityCandidates:[state.activity,second]}}/>);expect(screen.getByText(/Multiple current Activities/)).toBeTruthy();expect(screen.getAllByRole('link',{name:'Open Current Activity'})).toHaveLength(2);});
it('Daily provider outage leaves direct Activity link available with unchanged source context',async()=>{const before=JSON.stringify(state);fetchMock.mockRejectedValue(Error('Provider offline'));render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));await screen.findByRole('button',{name:'Try joining again'});expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);expect(JSON.stringify(state)).toBe(before);});

it('embedded frame load error preserves Activity access and allows a fresh authorized retry',async()=>{
 const before=JSON.stringify(state);render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));const frame=await screen.findByTitle('Daily live classroom');fireEvent.error(frame);expect(screen.queryByTitle('Daily live classroom')).toBeNull();expect(screen.getByRole('status').textContent).toContain('unavailable');expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);fireEvent.click(screen.getByRole('button',{name:'Try joining again'}));await screen.findByTitle('Daily live classroom');expect(fetchMock).toHaveBeenCalledTimes(2);expect(JSON.stringify(state)).toBe(before);
});
it('unresponsive embedded load times out safely without changing educational state',async()=>{
 vi.useFakeTimers();render(<LiveClassroom state={state}/>);await act(async()=>{fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));});expect(screen.getByTitle('Daily live classroom')).toBeTruthy();await act(async()=>{await vi.advanceTimersByTimeAsync(20000);});expect(screen.queryByTitle('Daily live classroom')).toBeNull();expect(screen.getByRole('button',{name:'Try joining again'})).toBeTruthy();expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);expect(fetchMock.mock.calls.every(c=>c[0]==='/api/live-classroom/join')).toBe(true);
});
it('successful embedded document load cancels the load-failure timer',async()=>{
 vi.useFakeTimers();render(<LiveClassroom state={state}/>);await act(async()=>{fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));});fireEvent.load(screen.getByTitle('Daily live classroom'));await act(async()=>{await vi.advanceTimersByTimeAsync(20000);});expect(screen.getByTitle('Daily live classroom')).toBeTruthy();expect(screen.getByRole('status').textContent).toContain('Daily classroom is open');
});
it('hung join transport shows safe failure and ignores a late capability',async()=>{
 vi.useFakeTimers();let done!:(value:unknown)=>void;fetchMock.mockImplementation(()=>new Promise(resolve=>{done=resolve;}));render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));await act(async()=>{await vi.advanceTimersByTimeAsync(15000);});expect(screen.getByRole('button',{name:'Try joining again'})).toBeTruthy();await act(async()=>{done({ok:true,json:async()=>({url:'https://pilot.daily.co/room',token:'late.token',expiresAt:Math.floor(Date.now()/1000)+60})});});expect(screen.queryByTitle('Daily live classroom')).toBeNull();expect(document.body.textContent).not.toContain('late.token');
});

it('refresh discards the old capability and rejoins the same context with a fresh token only',async()=>{
 const before=JSON.stringify(state);let issued=0;
 fetchMock.mockImplementation(async()=>({ok:true,json:async()=>({url:'https://pilot.daily.co/canonical-room',token:`fresh.token.${++issued}`,expiresAt:Math.floor(Date.now()/1000)+60})}));
 const first=render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));
 expect(new URL((await screen.findByTitle('Daily live classroom')).getAttribute('src')!).searchParams.get('t')).toBe('fresh.token.1');
 first.unmount();render(<LiveClassroom state={state}/>);
 expect(screen.queryByTitle('Daily live classroom')).toBeNull();
 expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);
 fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));
 expect(new URL((await screen.findByTitle('Daily live classroom')).getAttribute('src')!).searchParams.get('t')).toBe('fresh.token.2');
 expect(fetchMock.mock.calls.map(c=>[c[0],c[1].body])).toEqual(Array(2).fill(['/api/live-classroom/join',JSON.stringify({liveSessionRoomId:state.liveSessionRoomId})]));
 expect(JSON.stringify(state)).toBe(before);expect(localStorage.length).toBe(0);expect(sessionStorage.length).toBe(0);
});

it('media disconnect followed by revoked join authorization cannot restore a stale frame',async()=>{
 render(<LiveClassroom state={state}/>);fireEvent.click(screen.getByRole('button',{name:'Join classroom'}));
 fireEvent.error(await screen.findByTitle('Daily live classroom'));
 fetchMock.mockResolvedValue({ok:false});fireEvent.click(screen.getByRole('button',{name:'Try joining again'}));
 await screen.findByRole('button',{name:'Try joining again'});
 expect(screen.queryByTitle('Daily live classroom')).toBeNull();
 expect(screen.getByRole('link',{name:'Open Current Activity'}).getAttribute('href')).toBe(state.activity.href);
 expect(fetchMock).toHaveBeenCalledTimes(2);
});
