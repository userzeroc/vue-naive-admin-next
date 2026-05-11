-- ============================================================================
-- 002_rls_policies.sql
-- Row Level Security 策略
-- 替代原 NestJS 中的 JwtGuard + RoleGuard + PreviewGuard
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 启用 RLS（必须先启用，否则所有行对 anon/authenticated 可见）
-- ---------------------------------------------------------------------------

ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 辅助函数：判断当前用户是否为超级管理员
-- =========================================================================

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND r.code = 'SUPER_ADMIN'
      AND r.enable = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

COMMENT ON FUNCTION is_super_admin IS '判断当前已认证用户是否拥有 SUPER_ADMIN 角色';

-- =========================================================================
-- profiles 表策略
-- =========================================================================

-- 用户可以查看自己的资料
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- 超管可以查看所有用户资料
CREATE POLICY "profiles_select_admin"
  ON profiles FOR SELECT
  TO authenticated
  USING (is_super_admin());

-- 用户只能修改自己的资料（非敏感字段）
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- 超管可以修改所有用户资料（启用/禁用等）
CREATE POLICY "profiles_update_admin"
  ON profiles FOR UPDATE
  TO authenticated
  USING (is_super_admin());

-- 插入由 handle_new_user() 触发器完成（SECURITY DEFINER，绕过 RLS）
-- 删除通过 admin client (service role) 操作

-- =========================================================================
-- roles 表策略
-- =========================================================================

-- 所有已认证用户可以读取角色列表（用于前端下拉选择等）
CREATE POLICY "roles_select_authenticated"
  ON roles FOR SELECT
  TO authenticated
  USING (true);

-- 仅超管可以增删改角色
CREATE POLICY "roles_insert_admin"
  ON roles FOR INSERT
  TO authenticated
  WITH CHECK (is_super_admin());

CREATE POLICY "roles_update_admin"
  ON roles FOR UPDATE
  TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "roles_delete_admin"
  ON roles FOR DELETE
  TO authenticated
  USING (is_super_admin());

-- =========================================================================
-- permissions 表策略
-- =========================================================================

-- 已认证用户只能读取自己角色关联的权限
-- 注意：超管（SUPER_ADMIN）拥有所有权限
CREATE POLICY "permissions_select_own_roles"
  ON permissions FOR SELECT
  TO authenticated
  USING (
    is_super_admin()
    OR EXISTS (
      SELECT 1
      FROM role_permissions rp
      JOIN user_roles ur ON ur.role_id = rp.role_id
      WHERE ur.user_id = auth.uid()
        AND rp.permission_id = permissions.id
    )
  );

-- 仅超管可以增删改权限
CREATE POLICY "permissions_insert_admin"
  ON permissions FOR INSERT
  TO authenticated
  WITH CHECK (is_super_admin());

CREATE POLICY "permissions_update_admin"
  ON permissions FOR UPDATE
  TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "permissions_delete_admin"
  ON permissions FOR DELETE
  TO authenticated
  USING (is_super_admin());

-- =========================================================================
-- user_roles 表策略
-- =========================================================================

-- 用户可以读取自己的角色关联
CREATE POLICY "user_roles_select_own"
  ON user_roles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- 超管可以读取所有用户角色关联
CREATE POLICY "user_roles_select_admin"
  ON user_roles FOR SELECT
  TO authenticated
  USING (is_super_admin());

-- 仅超管可以分配/取消用户角色
CREATE POLICY "user_roles_insert_admin"
  ON user_roles FOR INSERT
  TO authenticated
  WITH CHECK (is_super_admin());

CREATE POLICY "user_roles_delete_admin"
  ON user_roles FOR DELETE
  TO authenticated
  USING (is_super_admin());

-- =========================================================================
-- role_permissions 表策略
-- =========================================================================

-- 已认证用户可以读取角色权限关联（用于前端菜单构建）
CREATE POLICY "role_permissions_select_authenticated"
  ON role_permissions FOR SELECT
  TO authenticated
  USING (true);

-- 仅超管可以分配/取消角色权限
CREATE POLICY "role_permissions_insert_admin"
  ON role_permissions FOR INSERT
  TO authenticated
  WITH CHECK (is_super_admin());

CREATE POLICY "role_permissions_delete_admin"
  ON role_permissions FOR DELETE
  TO authenticated
  USING (is_super_admin());
