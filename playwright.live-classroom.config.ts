import {defineConfig} from '@playwright/test';
import base from './playwright.config';
// Reuse installed Chrome; no browser download or additional dependency required.
export default defineConfig({...base,testMatch:'live-classroom.spec.ts',reporter:[['list']],projects:[{name:'chrome',use:{...base.projects?.[0]?.use,channel:'chrome'}}]});
