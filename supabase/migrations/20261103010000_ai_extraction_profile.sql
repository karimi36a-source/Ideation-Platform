-- Add only the missing platform capability profile. No RLS, grants, actor,
-- task authorization, metrics history, or provider configuration changes.
begin;
alter type public.ai_usage_model_profile add value 'AI_EXTRACTION';
commit;
