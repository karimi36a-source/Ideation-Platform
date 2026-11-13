import {fileURLToPath} from 'node:url';
import {defineConfig} from 'vitest/config';
export default defineConfig({resolve:{alias:{'@':fileURLToPath(new URL('./',import.meta.url))}},test:{environment:'node',include:['tests/database/master-live-room.test.ts',...(process.env.FICI_LIVE_ROOM_STUDENT==='1'?['tests/database/student-live-room.test.ts']:[]),...(process.env.FICI_LIVE_ROOM_TOKEN==='1'?['tests/database/live-session-join-token.test.ts']:[]),...(process.env.FICI_LIVE_ROOM_UI==='1'?['tests/database/live-classroom-view.test.ts']:[])],testTimeout:45000,clearMocks:true,restoreMocks:true,maxWorkers:1}});


