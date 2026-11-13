import {z} from "zod";
export const archiveTeamIdSchema=z.uuid();
export const archivedTeamSchema=z.strictObject({teamId:z.uuid(),status:z.literal("archived"),archivedAt:z.iso.datetime({offset:true})});
