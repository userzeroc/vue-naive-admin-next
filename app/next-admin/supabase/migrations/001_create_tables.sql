-- ============================================================================
-- 001_create_tables.sql
-- 创建业务表：profiles, roles, permissions, user_roles, role_permissions
-- 原始来源：isme-nest-serve/init.sql (MySQL) → Supabase PostgreSQL
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 自定义枚举类型
-- ---------------------------------------------------------------------------

CREATE TYPE permission_type AS ENUM ('MENU', 'BUTTON');
CREATE TYPE http_method AS ENUM ('GET', 'POST', 'PATCH', 'PUT', 'DELETE');

-- ---------------------------------------------------------------------------
-- 1. profiles — 用户资料表
--    原 MySQL: user + profile 两张表
--    Supabase: 认证由 auth.users 管理，业务资料存此表
--    id 直接关联 auth.users.id (UUID)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      text UNIQUE,
  nick_name     text,
  gender        smallint,
  avatar        text DEFAULT 'https://wpimg.wallstcn.com/f778738c-e4f8-4870-b634-56703b4acafe.gif?imageView2/1/w/80/h/80',
  address       text,
  email         text,
  enable        boolean NOT NULL DEFAULT true,
  current_role_id integer,                -- 当前激活的角色 ID
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  profiles IS '用户资料表，1:1 关联 auth.users';
COMMENT ON COLUMN profiles.current_role_id IS '当前激活角色，用于多角色切换场景';
COMMENT ON COLUMN profiles.enable IS '账号是否启用';

-- ---------------------------------------------------------------------------
-- 2. roles — 角色表
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS roles (
  id            serial PRIMARY KEY,
  code          text NOT NULL UNIQUE,
  name          text NOT NULL UNIQUE,
  enable        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE roles IS 'RBAC 角色表';

-- ---------------------------------------------------------------------------
-- 3. permissions — 权限/菜单表（树形结构）
--    type=MENU 为菜单资源，type=BUTTON 为按钮权限
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS permissions (
  id            serial PRIMARY KEY,
  parent_id     integer REFERENCES permissions(id) ON DELETE SET NULL,
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  type          permission_type NOT NULL DEFAULT 'MENU',
  path          text,                     -- 路由路径
  redirect      text,                     -- 重定向路径
  icon          text,                     -- 菜单图标
  component     text,                     -- 前端组件路径
  layout        text,                     -- 布局类型 (normal/full/simple/empty)
  keep_alive    boolean NOT NULL DEFAULT false,
  method        http_method,              -- API 方法（BUTTON 类型使用）
  description   text,
  "order"       integer NOT NULL DEFAULT 0,  -- 排序权重
  show          boolean NOT NULL DEFAULT true, -- 是否在菜单中显示
  enable        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  permissions IS '权限/菜单资源表（树形结构）';
COMMENT ON COLUMN permissions.type IS 'MENU=菜单资源, BUTTON=按钮权限';
COMMENT ON COLUMN permissions.show IS '是否展示在侧边栏菜单';
COMMENT ON COLUMN permissions."order" IS '同级排序权重，越小越靠前';

-- ---------------------------------------------------------------------------
-- 4. user_roles — 用户-角色关联表（多对多）
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_roles (
  user_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role_id       integer NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

COMMENT ON TABLE user_roles IS '用户-角色多对多关联表';

-- ---------------------------------------------------------------------------
-- 5. role_permissions — 角色-权限关联表（多对多）
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id       integer NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id integer NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

COMMENT ON TABLE role_permissions IS '角色-权限多对多关联表';

-- ---------------------------------------------------------------------------
-- 索引
-- ---------------------------------------------------------------------------

CREATE INDEX idx_permissions_parent_id ON permissions(parent_id);
CREATE INDEX idx_permissions_type      ON permissions(type);
CREATE INDEX idx_user_roles_user_id    ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id    ON user_roles(role_id);
CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_perm ON role_permissions(permission_id);

-- ---------------------------------------------------------------------------
-- 自动更新 updated_at 触发器
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_permissions_updated_at
  BEFORE UPDATE ON permissions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------------
-- 新用户注册时自动创建 profile 行
-- Supabase Auth 创建用户后触发此函数
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'username', NEW.email),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ---------------------------------------------------------------------------
-- profiles.current_role_id 外键（延迟创建，因为 roles 表需先存在）
-- ---------------------------------------------------------------------------

ALTER TABLE profiles
  ADD CONSTRAINT fk_profiles_current_role
  FOREIGN KEY (current_role_id) REFERENCES roles(id) ON DELETE SET NULL;
