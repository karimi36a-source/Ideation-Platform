import {expect,test} from '@playwright/test';
test.use({trace:'off',screenshot:'off',video:'off'});
test('Patent Workspace exact Project IDs and role spoofing never expose research to anonymous callers',async({page})=>{
 for(const id of ['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000099999']){
  await page.goto('/projects/'+id+'/patents?role=ADMIN&workspaceId=00000000-0000-4000-8000-000000006004');
  await expect(page).toHaveURL(/\/(login|account-state)(\?|$)/);
  await expect(page.getByRole('heading',{name:'Patent Workspace',exact:true})).toHaveCount(0);
  await expect(page.getByText('Private research rationale',{exact:true})).toHaveCount(0);
 }
});
