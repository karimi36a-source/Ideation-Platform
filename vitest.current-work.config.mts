import {fileURLToPath} from 'node:url';
import {defineConfig} from 'vitest/config';
export default defineConfig({resolve:{alias:{'@':fileURLToPath(new URL('./',import.meta.url))}},test:{environment:'node',include:['tests/database/student-current-work.test.ts'],testTimeout:45000,clearMocks:true,restoreMocks:true}});
