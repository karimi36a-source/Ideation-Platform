import {requireProtectedAccount} from '@/lib/auth/protected-account';
import {getMyCurrentWork} from '@/features/progress/current-work';
import {CurrentWorkOverview} from '@/features/progress/current-work-view';
export const dynamic='force-dynamic';
export default async function CurrentWorkPage(){
 await requireProtectedAccount();
 return <CurrentWorkOverview state={await getMyCurrentWork()}/>;
}
