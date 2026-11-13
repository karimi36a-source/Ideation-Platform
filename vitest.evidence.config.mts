import {fileURLToPath} from "node:url";
import {defineConfig} from "vitest/config";
// Invoked only by the disposable PostgreSQL runner, never by ordinary unit runs.
export default defineConfig({resolve:{alias:{"@":fileURLToPath(new URL("./",import.meta.url))}},test:{environment:"node",include:["tests/database/evidence-create-service.test.ts"],clearMocks:true,restoreMocks:true}});
