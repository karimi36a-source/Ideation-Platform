import {defineConfig,devices} from '@playwright/test';
if(process.env.FICI_M1619_ISOLATED!=='1')throw Error('Run scripts/run-live-classroom-browser.mjs');
// Five authenticated users and cold routes share a bounded four-minute budget, including cleanup.
export default defineConfig({testDir:'./tests/e2e',testMatch:'live-classroom-authenticated.spec.ts',workers:1,retries:0,timeout:240000,expect:{timeout:15000},reporter:[['list']],use:{baseURL:process.env.FICI_M1619_BASE_URL,trace:'off',screenshot:'off',video:'off'},projects:[{name:'chrome',use:{...devices['Desktop Chrome'],channel:'chrome'}}]});
