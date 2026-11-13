/** MVP runtime allowlist, deliberately narrower than persisted/future vocabulary.
 * COLLABORATE and LIVE_REFERENCE remain schema values, never capabilities.
 * The database independently enforces this same policy before any write.
 */
export function shareRuntimePolicyDenial(input:{permissionLevel:string;shareMode:string}):"MODE_NOT_ALLOWED"|"PERMISSION_NOT_ALLOWED"|null{
 if(input.shareMode!=="SNAPSHOT")return "MODE_NOT_ALLOWED";
 if(input.permissionLevel!=="VIEW"&&input.permissionLevel!=="COMMENT")return "PERMISSION_NOT_ALLOWED";
 return null;
}
