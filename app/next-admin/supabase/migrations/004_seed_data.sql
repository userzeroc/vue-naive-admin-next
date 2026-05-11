-- ============================================================================
-- 004_seed_data.sql
-- 种子数据（从原 MySQL init.sql 迁移）
--
-- 注意：admin 用户需要先通过 Supabase Auth 创建，获取 UUID 后再关联。
-- 以下种子数据分两步执行：
--   Step 1: 插入 roles、permissions、role_permissions（可直接执行）
--   Step 2: 创建 admin 用户后，插入 profiles 和 user_roles
--            （需要在 Supabase Dashboard 或通过 admin client 创建用户后执行）
-- ============================================================================

-- =========================================================================
-- Step 1: 角色数据
-- =========================================================================

INSERT INTO roles (id, code, name, enable) VALUES
  (1, 'SUPER_ADMIN', '超级管理员', true),
  (2, 'ROLE_QA',     '质检员',     true)
ON CONFLICT (id) DO NOTHING;

-- 重置 serial 序列，避免后续插入冲突
SELECT setval('roles_id_seq', (SELECT COALESCE(MAX(id), 0) FROM roles));

-- =========================================================================
-- Step 2: 权限/菜单数据
-- 从原 MySQL permission 表迁移，字段名已 snake_case 化
-- =========================================================================

INSERT INTO permissions (id, name, code, type, parent_id, path, redirect, icon, component, layout, keep_alive, method, description, show, enable, "order") VALUES
  -- 系统管理（顶级菜单）
  (2,  '系统管理',   'SysMgt',          'MENU',   NULL, NULL,                  NULL, 'i-fe:grid',       NULL,                                  NULL,   false, NULL, NULL, true,  true,  2),
  (1,  '资源管理',   'Resource_Mgt',    'MENU',   2,    '/pms/resource',       NULL, 'i-fe:list',       '/src/views/pms/resource/index.vue',   NULL,   false, NULL, NULL, true,  true,  1),
  (3,  '角色管理',   'RoleMgt',         'MENU',   2,    '/pms/role',           NULL, 'i-fe:user-check', '/src/views/pms/role/index.vue',        NULL,   false, NULL, NULL, true,  true,  2),
  (4,  '用户管理',   'UserMgt',         'MENU',   2,    '/pms/user',           NULL, 'i-fe:user',       '/src/views/pms/user/index.vue',        NULL,   true,  NULL, NULL, true,  true,  3),
  (5,  '分配用户',   'RoleUser',        'MENU',   3,    '/pms/role/user/:roleId', NULL, 'i-fe:user-plus', '/src/views/pms/role/role-user.vue', 'full', false, NULL, NULL, false, true,  1),

  -- 业务示例（顶级菜单）
  (6,  '业务示例',   'Demo',            'MENU',   NULL, NULL,                  NULL, 'i-fe:grid',       NULL,                                  NULL,   false, NULL, NULL, true,  true,  1),
  (7,  '图片上传',   'ImgUpload',       'MENU',   6,    '/demo/upload',        NULL, 'i-fe:image',      '/src/views/demo/upload/index.vue',    '',     true,  NULL, NULL, true,  true,  2),

  -- 个人资料（隐藏菜单）
  (8,  '个人资料',   'UserProfile',     'MENU',   NULL, '/profile',            NULL, 'i-fe:user',       '/src/views/profile/index.vue',        NULL,   false, NULL, NULL, false, true,  99),

  -- 基础功能（顶级菜单）
  (9,  '基础功能',   'Base',            'MENU',   NULL, '',                    NULL, 'i-fe:grid',       NULL,                                  '',     false, NULL, NULL, true,  true,  0),
  (10, '基础组件',   'BaseComponents',  'MENU',   9,    '/base/components',    NULL, 'i-me:awesome',    '/src/views/base/index.vue',            NULL,   false, NULL, NULL, true,  true,  1),
  (11, 'Unocss',     'Unocss',          'MENU',   9,    '/base/unocss',        NULL, 'i-me:awesome',    '/src/views/base/unocss.vue',           NULL,   false, NULL, NULL, true,  true,  2),
  (12, 'KeepAlive',  'KeepAlive',       'MENU',   9,    '/base/keep-alive',    NULL, 'i-me:awesome',    '/src/views/base/keep-alive.vue',       NULL,   true,  NULL, NULL, true,  true,  3),
  (14, '图标 Icon',  'Icon',            'MENU',   9,    '/base/icon',          NULL, 'i-fe:feather',    '/src/views/base/unocss-icon.vue',      '',     false, NULL, NULL, true,  true,  0),
  (15, 'MeModal',    'TestModal',       'MENU',   9,    '/testModal',          NULL, 'i-me:dialog',     '/src/views/base/test-modal.vue',       NULL,   false, NULL, NULL, true,  true,  5),

  -- 按钮权限
  (13, '创建新用户', 'AddUser',         'BUTTON', 4,    NULL,                  NULL, NULL,              NULL,                                  NULL,   false, NULL, NULL, true,  true,  1),
  (16, '超管专属',   'SuperAdmin',      'BUTTON', 4,    NULL,                  NULL, NULL,              NULL,                                  NULL,   false, NULL, NULL, true,  true,  1)
ON CONFLICT (id) DO NOTHING;

-- 重置 serial 序列
SELECT setval('permissions_id_seq', (SELECT COALESCE(MAX(id), 0) FROM permissions));

-- =========================================================================
-- Step 3: 角色-权限关联
-- 质检员 (ROLE_QA) 的权限分配
-- 注意：超管 (SUPER_ADMIN) 不需要关联记录，RPC 函数中硬编码返回全部权限
-- =========================================================================

INSERT INTO role_permissions (role_id, permission_id) VALUES
  (2, 1),   -- 资源管理
  (2, 2),   -- 系统管理
  (2, 3),   -- 角色管理
  (2, 4),   -- 用户管理
  (2, 5),   -- 分配用户
  (2, 9),   -- 基础功能
  (2, 10),  -- 基础组件
  (2, 11),  -- Unocss
  (2, 12),  -- KeepAlive
  (2, 14),  -- 图标 Icon
  (2, 15)   -- MeModal
ON CONFLICT DO NOTHING;

-- =========================================================================
-- Step 4: Admin 用户创建指南
--
-- Supabase 中用户必须通过 Auth API 创建，不能直接 INSERT 到 auth.users。
-- 有以下两种方式：
--
-- 方式 A: Supabase Dashboard
--   1. 进入 Supabase Dashboard → Authentication → Users
--   2. 点击 "Add User" → 输入 email + password
--   3. 用户创建后，handle_new_user() 触发器会自动创建 profiles 行
--   4. 记录用户的 UUID，然后手动执行下面的 SQL 关联角色
--
-- 方式 B: Admin Client (推荐用于脚本化)
--   在 Next.js 中使用 createAdminClient()：
--
--   const { data } = await supabase.auth.admin.createUser({
--     email: 'admin@example.com',
--     password: 'your-secure-password',
--     email_confirm: true,
--     user_metadata: { username: 'admin' }
--   });
--   const adminId = data.user.id;
--
-- 创建用户后，执行以下 SQL（替换 <ADMIN_UUID>）：
-- =========================================================================

-- 取消注释并替换 <ADMIN_UUID> 为实际的 admin 用户 UUID：
--
-- UPDATE profiles
-- SET username = 'admin',
--     nick_name = 'Admin',
--     current_role_id = 1
-- WHERE id = '<ADMIN_UUID>';
--
-- INSERT INTO user_roles (user_id, role_id) VALUES
--   ('<ADMIN_UUID>', 1),  -- SUPER_ADMIN
--   ('<ADMIN_UUID>', 2)   -- ROLE_QA
-- ON CONFLICT DO NOTHING;
