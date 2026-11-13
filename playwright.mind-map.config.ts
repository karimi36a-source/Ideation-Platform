import {defineConfig,devices} from "@playwright/test";

export default defineConfig({
 testDir:"./tests/e2e",
 testMatch:process.env.FICI_MIND_MAP_SPEC??"mind-map-*-authenticated.spec.ts",
 fullyParallel:false,
 workers:1,
 retries:0,
 timeout:600_000,
 expect:{timeout:60_000},
 reporter:[["list"]],
 use:{baseURL:process.env.FICI_MIND_MAP_BASE_URL??"http://127.0.0.1:3101",trace:"off",screenshot:"off",video:"off"},
 projects:[{name:"chromium",use:{...devices["Desktop Chrome"]}}],
});
