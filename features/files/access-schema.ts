import {z} from "zod";
export const getFileAccessSchema=z.strictObject({fileId:z.uuid()});
/** Approved download/view policy; separate from signed-upload lifetime. */
export function fileAccessLifetime(value:string|undefined):number{
 if(value===undefined)return 60;
 if(!/^[1-9][0-9]*$/.test(value)||Number(value)>300)throw new Error("Invalid file access lifetime configuration");
 return Number(value);
}
