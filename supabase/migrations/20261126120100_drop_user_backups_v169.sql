-- 1.3.69: remove a tabela antiga de backups (vazia e sem uso no código desde
-- a troca para rpg_cloud_backups).
drop table if exists public.user_backups;
