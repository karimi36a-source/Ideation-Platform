import {readFileSync} from "node:fs";
import {expect,it} from "vitest";
import sessions from "../fixtures/professional-sessions.json";
import activities from "../fixtures/professional-activities.json";
import deferred from "../fixtures/deferred-professional-dependencies.json";
const workflow=readFileSync(new URL("../../docs/06_COURSE_ACTIVITY_WORKFLOWS.md",import.meta.url),"utf8");
const prompts=readFileSync(new URL("../../docs/17_CODEX_M3_PROMPTS.md",import.meta.url),"utf8");
it("session fixture matches approved titles/order and workflow goals without drift",()=>{
 expect(sessions).toHaveLength(10);
 sessions.forEach((s,i)=>{expect(s.session_number).toBe(i+1);expect(s.sequence).toBe(i+1);expect(prompts).toContain(s.title);expect(workflow).toContain(s.title);expect(workflow).toContain(s.learning_goal);expect(s.status).toBe("active");});
});
it("minimum activity content is documented rather than invented",()=>{
 expect(activities).toHaveLength(1);const a=activities[0];expect(a.name).toBe("SCAMPER Example Set");expect(a.session_definition_id).toBe(sessions[1].id);
 expect(workflow).toContain(a.name);expect(workflow).toContain(a.description);expect(workflow).toContain(a.instructions);expect(a.method_type).toBe("scamper");
});
it("all four approved workflow dependencies remain explicit deferred expectations",()=>{
 expect(deferred.map(d=>[d.from_session,d.to_session])).toEqual([[4,5],[6,7],[8,9],[9,10]]);
 deferred.forEach(d=>{expect(d.reason).toBe("Corresponding activity definitions are absent");expect(activities.some(a=>a.session_definition_id===sessions[d.from_session-1].id)).toBe(false);expect(activities.some(a=>a.session_definition_id===sessions[d.to_session-1].id)).toBe(false);});
});
