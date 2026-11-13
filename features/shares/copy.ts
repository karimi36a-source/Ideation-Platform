import "server-only";

/** Stable MVP policy denial; deliberately independent of caller, IDs and Share state. */
export class SharedSnapshotCopyDeferredError extends Error {
 readonly code="SHARED_SNAPSHOT_COPY_DEFERRED";
 constructor(){super("Shared Snapshot copying is deferred for M13 MVP.");this.name="SharedSnapshotCopyDeferredError";}
}

/** Central boundary for future copy/import/clone adapters. Never reads content or writes.
 * VIEW/COMMENT authorize representation access only, never derivative creation.
 * No derivative lifetime, multiplicity or editing semantics are defined here.
 */
export async function copySharedSnapshotToWorkspace(_input:unknown):Promise<never>{
 void _input;
 throw new SharedSnapshotCopyDeferredError();
}
