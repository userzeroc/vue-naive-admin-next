-- ============================================================================
-- 001_seed_rbac_data.sql
-- 说明：
-- 1) 初始化 vue-naive-admin 所需 RBAC 数据（roles / permissions / role_permissions）
-- 2) 回填 profiles，并为无角色用户分配默认角色 ROLE_QA
-- 3) 可选：按管理员邮箱授予 SUPER_ADMIN
--
-- 使用前请确认：
-- - 已存在表：profiles, roles, permissions, user_roles, role_permissions
-- - permissions.type 枚举类型为 public.permission_type
-- - permissions.method 枚举类型为 public.http_method
--
-- 注意：
-- - 如果执行中报错，请先执行 rollback; 再修正后重试
-- ============================================================================

begin;

-- --------------------------------------------------------------------------
-- 0) 回填 profiles（给已经存在于 auth.users 的账号建档）
-- --------------------------------------------------------------------------
insert into public.profiles (id, username, email, enable)
select
  u.id,
  nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
  u.email,
  true
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

-- --------------------------------------------------------------------------
-- 1) 角色初始化
-- --------------------------------------------------------------------------
insert into public.roles (code, name, enable)
values
  ('SUPER_ADMIN', '超级管理员', true),
  ('ROLE_QA', '质检员', true)
on conflict (code) do update
set
  name = excluded.name,
  enable = excluded.enable,
  updated_at = now();

-- --------------------------------------------------------------------------
-- 2) 权限初始化
-- --------------------------------------------------------------------------
with seed(
  code, name, type, parent_code, path, redirect, icon, component, layout,
  keep_alive, method, description, "order", show, enable
) as (
  values
    ('SysMgt',         '系统管理',   'MENU'::public.permission_type, null, null, null, 'i-fe:grid', null, null, false, null::public.http_method, null, 2,  true,  true),
    ('ResourceMgt',    '资源管理',   'MENU'::public.permission_type, 'SysMgt', '/pms/resource', null, 'i-fe:list', '/src/views/pms/resource/index.vue', null, false, null::public.http_method, null, 1,  true,  true),
    ('RoleMgt',        '角色管理',   'MENU'::public.permission_type, 'SysMgt', '/pms/role', null, 'i-fe:user-check', '/src/views/pms/role/index.vue', null, false, null::public.http_method, null, 2,  true,  true),
    ('UserMgt',        '用户管理',   'MENU'::public.permission_type, 'SysMgt', '/pms/user', null, 'i-fe:user', '/src/views/pms/user/index.vue', null, true,  null::public.http_method, null, 3,  true,  true),
    ('RoleUser',       '分配用户',   'MENU'::public.permission_type, 'RoleMgt', '/pms/role/user/:roleId', null, 'i-fe:user-plus', '/src/views/pms/role/role-user.vue', 'full', false, null::public.http_method, null, 1,  false, true),

    ('Demo',           '业务示例',   'MENU'::public.permission_type, null, null, null, 'i-fe:grid', null, null, false, null::public.http_method, null, 1,  true,  true),
    ('ImgUpload',      '图片上传',   'MENU'::public.permission_type, 'Demo', '/demo/upload', null, 'i-fe:image', '/src/views/demo/upload/index.vue', '', true, null::public.http_method, null, 2,  true,  true),

    ('UserProfile',    '个人资料',   'MENU'::public.permission_type, null, '/profile', null, 'i-fe:user', '/src/views/profile/index.vue', null, false, null::public.http_method, null, 99, false, true),

    ('Base',           '基础功能',   'MENU'::public.permission_type, null, '', null, 'i-fe:grid', null, '', false, null::public.http_method, null, 0,  true,  true),
    ('BaseComponents', '基础组件',   'MENU'::public.permission_type, 'Base', '/base/components', null, 'i-me:awesome', '/src/views/base/index.vue', null, false, null::public.http_method, null, 1,  true,  true),
    ('Unocss',         'Unocss',     'MENU'::public.permission_type, 'Base', '/base/unocss', null, 'i-me:awesome', '/src/views/base/unocss.vue', null, false, null::public.http_method, null, 2,  true,  true),
    ('KeepAlive',      'KeepAlive',  'MENU'::public.permission_type, 'Base', '/base/keep-alive', null, 'i-me:awesome', '/src/views/base/keep-alive.vue', null, true, null::public.http_method, null, 3,  true,  true),
    ('Icon',           '图标 Icon',  'MENU'::public.permission_type, 'Base', '/base/icon', null, 'i-fe:feather', '/src/views/base/unocss-icon.vue', '', false, null::public.http_method, null, 4,  true,  true),
    ('TestModal',      'MeModal',    'MENU'::public.permission_type, 'Base', '/testModal', null, 'i-me:dialog', '/src/views/base/test-modal.vue', null, false, null::public.http_method, null, 5,  true,  true),

    ('AddUser',        '创建新用户', 'BUTTON'::public.permission_type, 'UserMgt', null, null, null, null, null, false, null::public.http_method, null, 1, true, true),
    ('SuperAdmin',     '超管专属',   'BUTTON'::public.permission_type, 'UserMgt', null, null, null, null, null, false, null::public.http_method, null, 2, true, true)
)
insert into public.permissions (
  code, name, type, parent_id, path, redirect, icon, component, layout,
  keep_alive, method, description, "order", show, enable
)
select
  s.code,
  s.name,
  s.type,
  p_parent.id,
  s.path,
  s.redirect,
  s.icon,
  s.component,
  s.layout,
  s.keep_alive,
  s.method::public.http_method,
  s.description,
  s."order",
  s.show,
  s.enable
from seed s
left join public.permissions p_parent on p_parent.code = s.parent_code
on conflict (code) do update
set
  name = excluded.name,
  type = excluded.type,
  parent_id = excluded.parent_id,
  path = excluded.path,
  redirect = excluded.redirect,
  icon = excluded.icon,
  component = excluded.component,
  layout = excluded.layout,
  keep_alive = excluded.keep_alive,
  method = excluded.method,
  description = excluded.description,
  "order" = excluded."order",
  show = excluded.show,
  enable = excluded.enable,
  updated_at = now();

-- --------------------------------------------------------------------------
-- 3) 角色-权限绑定
-- --------------------------------------------------------------------------
-- SUPER_ADMIN -> 全部启用权限
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.enable = true
where r.code = 'SUPER_ADMIN'
on conflict do nothing;

-- ROLE_QA -> 常用权限集
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'SysMgt', 'ResourceMgt', 'RoleMgt', 'UserMgt', 'RoleUser',
  'Demo', 'ImgUpload',
  'Base', 'BaseComponents', 'Unocss', 'KeepAlive', 'Icon', 'TestModal',
  'UserProfile'
)
where r.code = 'ROLE_QA'
on conflict do nothing;

-- --------------------------------------------------------------------------
-- 4) 给无角色用户分配默认角色 ROLE_QA，并回填 current_role_id
-- --------------------------------------------------------------------------
with qa as (
  select id from public.roles where code = 'ROLE_QA' and enable = true limit 1
)
insert into public.user_roles (user_id, role_id)
select p.id, qa.id
from public.profiles p
cross join qa
left join public.user_roles ur on ur.user_id = p.id
where ur.user_id is null
on conflict do nothing;

update public.profiles p
set
  current_role_id = ur.role_id,
  updated_at = now()
from public.user_roles ur
join public.roles r on r.id = ur.role_id and r.enable = true
where p.id = ur.user_id
  and p.current_role_id is null;

-- --------------------------------------------------------------------------
-- 5) 可选：按邮箱授予管理员 SUPER_ADMIN
--    把 v_admin_email 改成你的管理员邮箱；留空则跳过
-- --------------------------------------------------------------------------
do $$
declare
  v_admin_email text := 'admin@example.com'; -- TODO: 修改为真实管理员邮箱
  v_uid uuid;
  v_super_role_id integer;
begin
  if v_admin_email is null or btrim(v_admin_email) = '' then
    return;
  end if;

  select id into v_uid
  from auth.users
  where lower(email) = lower(v_admin_email)
  limit 1;

  select id into v_super_role_id
  from public.roles
  where code = 'SUPER_ADMIN' and enable = true
  limit 1;

  if v_uid is not null and v_super_role_id is not null then
    insert into public.user_roles (user_id, role_id)
    values (v_uid, v_super_role_id)
    on conflict do nothing;

    update public.profiles
    set current_role_id = v_super_role_id,
        updated_at = now()
    where id = v_uid;
  end if;
end $$;

commit;

