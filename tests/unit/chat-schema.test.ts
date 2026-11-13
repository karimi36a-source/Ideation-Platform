import {expect,it} from "vitest";
import {chatChannelSchema,chatMembershipSchema,chatMessageSchema} from "@/features/chat/schema";
const id="00000000-0000-4000-8000-000000003401",time="2026-10-01T00:00:00Z";
const message={id,chat_channel_id:id,sender_user_id:id,parent_message_id:null,content:"Canonical text",message_type:"TEXT",created_at:time,edited_at:null,deleted_at:null};
it.each(["TEXT","FILE","LINK","SYSTEM"])("supports approved %s message metadata",message_type=>{expect(chatMessageSchema.safeParse({...message,message_type}).success).toBe(true);});
it("rejects invalid message types and blank TEXT",()=>{
 expect(chatMessageSchema.safeParse({...message,message_type:"HTML"}).success).toBe(false);
 expect(chatMessageSchema.safeParse({...message,content:"   "}).success).toBe(false);
});
it("requires TEAM channel scope fields",()=>{
 const channel={id,channel_type:"TEAM",workspace_id:id,team_id:id,cohort_id:id,name:"Team Chat",status:"active",created_at:time};
 expect(chatChannelSchema.safeParse(channel).success).toBe(true);
 expect(chatChannelSchema.safeParse({...channel,team_id:null}).success).toBe(false);
 expect(chatChannelSchema.safeParse({...channel,cohort_id:null}).success).toBe(false);
});
it("accepts only approved membership access metadata with valid timestamps",()=>{
 const membership={id,chat_channel_id:id,user_id:id,access_level:"read",joined_at:time,left_at:null};
 expect(chatMembershipSchema.safeParse(membership).success).toBe(true);
 expect(chatMembershipSchema.safeParse({...membership,access_level:"read_write"}).success).toBe(true);
 expect(chatMembershipSchema.safeParse({...membership,access_level:"ADMIN"}).success).toBe(false);
 expect(chatMembershipSchema.safeParse({...membership,left_at:"2026-09-01T00:00:00Z"}).success).toBe(false);
});
