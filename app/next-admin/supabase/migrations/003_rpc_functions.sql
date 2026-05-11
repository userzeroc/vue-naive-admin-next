-- ============================================================================
-- 003_rpc_functions.sql
-- 数据库 RPC 函数（替代 Nest 后端的 Service 层业务逻辑）
--
-- 这些函数通过 supabase.rpc('function_name', { args }) 调用
-- 已在 types.ts 中声明类型签名
-- ============================================================================

-- =========================================================================
-- 1. get_current_user_permissions()
--    获取当前登录用户的所有权限列表
--
--    替代原 Nest 端点：
--    - GET /role/permissions/tree  (RoleController.findRolePermissionsTree)
--    - RoleService.findRolePermissionsTree(currentRoleCode)
--
--    逻辑：
--    - 超管 (SUPER_ADMIN) 返回所有权限
--    - 普通用户返回其 current_role_id 对应角色的权限
--    - 如未设置 current_role_id，使用第一个启用的角色
-- =========================================================================

CREATE OR REPLACE FUNCTION get_current_user_permissions()
RETURNS SETOF permissions AS $$
DECLARE
  v_user_id uuid;
  v_role_id integer;
  v_role_code text;
BEGIN
  -- 获取当前用户 ID
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  -- 获取当前激活角色
  SELECT p.current_role_id INTO v_role_id
  FROM profiles p
  WHERE p.id = v_user_id;

  -- 如果没有设置当前角色，取第一个启用的角色
  IF v_role_id IS NULL THEN
    SELECT ur.role_id INTO v_role_id
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = v_user_id AND r.enable = true
    ORDER BY ur.role_id ASC
    LIMIT 1;
  END IF;

  -- 仍然为空则无权限
  IF v_role_id IS NULL THEN
    RETURN;
  END IF;

  -- 获取角色 code
  SELECT r.code INTO v_role_code
  FROM roles r
  WHERE r.id = v_role_id;

  -- 超管返回所有权限
  IF v_role_code = 'SUPER_ADMIN' THEN
    RETURN QUERY
      SELECT pm.*
      FROM permissions pm
      WHERE pm.enable = true
      ORDER BY pm."order" ASC;
    RETURN;
  END IF;

  -- 普通用户返回角色关联的权限
  RETURN QUERY
    SELECT pm.*
    FROM permissions pm
    JOIN role_permissions rp ON rp.permission_id = pm.id
    WHERE rp.role_id = v_role_id
      AND pm.enable = true
    ORDER BY pm."order" ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

COMMENT ON FUNCTION get_current_user_permissions IS
  '获取当前登录用户基于其激活角色的所有权限，超管返回全部权限';

-- =========================================================================
-- 2. get_menu_tree()
--    获取当前用户的菜单树（JSON 格式，带层级嵌套）
--
--    替代原 Nest 端点：
--    - GET /permission/menu/tree  (PermissionController.findMenuTree)
--    - PermissionService.findMenuTree → SharedService.handleTree
--
--    逻辑：
--    - 先调用 get_current_user_permissions() 获取扁平权限列表
--    - 过滤 type='MENU' 且 enable=true 的条目
--    - 用递归 CTE 构建树形 JSON
-- =========================================================================

CREATE OR REPLACE FUNCTION get_menu_tree()
RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH RECURSIVE user_perms AS (
    -- 获取当前用户的菜单权限（扁平列表）
    SELECT *
    FROM get_current_user_permissions()
    WHERE type = 'MENU'
  ),
  -- 递归构建树
  tree AS (
    -- 根节点：parent_id 为 NULL 的菜单
    SELECT
      p.id,
      p.parent_id,
      p.code,
      p.name,
      p.type,
      p.path,
      p.redirect,
      p.icon,
      p.component,
      p.layout,
      p.keep_alive,
      p.method,
      p.description,
      p."order",
      p.show,
      p.enable,
      0 AS depth
    FROM user_perms p
    WHERE p.parent_id IS NULL
       OR p.parent_id NOT IN (SELECT id FROM user_perms)

    UNION ALL

    -- 子节点
    SELECT
      c.id,
      c.parent_id,
      c.code,
      c.name,
      c.type,
      c.path,
      c.redirect,
      c.icon,
      c.component,
      c.layout,
      c.keep_alive,
      c.method,
      c.description,
      c."order",
      c.show,
      c.enable,
      t.depth + 1
    FROM user_perms c
    JOIN tree t ON c.parent_id = t.id
  ),
  -- 构建嵌套 JSON（从叶子节点往上合并）
  leaf_nodes AS (
    SELECT t.*
    FROM tree t
    WHERE NOT EXISTS (
      SELECT 1 FROM tree t2 WHERE t2.parent_id = t.id
    )
  ),
  build_json AS (
    -- 构建每个节点的 JSON 表示
    SELECT
      p.id,
      p.parent_id,
      p."order",
      jsonb_build_object(
        'id', p.id,
        'parentId', p.parent_id,
        'code', p.code,
        'name', p.name,
        'type', p.type::text,
        'path', p.path,
        'redirect', p.redirect,
        'icon', p.icon,
        'component', p.component,
        'layout', p.layout,
        'keepAlive', p.keep_alive,
        'method', p.method::text,
        'description', p.description,
        'order', p."order",
        'show', p.show,
        'enable', p.enable,
        'children', COALESCE(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', c.id,
                'parentId', c.parent_id,
                'code', c.code,
                'name', c.name,
                'type', c.type::text,
                'path', c.path,
                'redirect', c.redirect,
                'icon', c.icon,
                'component', c.component,
                'layout', c.layout,
                'keepAlive', c.keep_alive,
                'method', c.method::text,
                'description', c.description,
                'order', c."order",
                'show', c.show,
                'enable', c.enable,
                'children', (
                  SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                      'id', gc.id,
                      'parentId', gc.parent_id,
                      'code', gc.code,
                      'name', gc.name,
                      'type', gc.type::text,
                      'path', gc.path,
                      'icon', gc.icon,
                      'component', gc.component,
                      'order', gc."order",
                      'show', gc.show,
                      'enable', gc.enable
                    ) ORDER BY gc."order" ASC
                  ), '[]'::jsonb)
                  FROM user_perms gc
                  WHERE gc.parent_id = c.id
                )
              ) ORDER BY c."order" ASC
            )
            FROM user_perms c
            WHERE c.parent_id = p.id
          ),
          '[]'::jsonb
        )
      ) AS node
    FROM user_perms p
    WHERE p.parent_id IS NULL
       OR p.parent_id NOT IN (SELECT id FROM user_perms)
    ORDER BY p."order" ASC
  )
  SELECT COALESCE(jsonb_agg(node ORDER BY "order" ASC), '[]'::jsonb)
  INTO v_result
  FROM build_json;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

COMMENT ON FUNCTION get_menu_tree IS
  '获取当前用户的菜单树（嵌套 JSON），最多支持 3 级菜单深度';

-- =========================================================================
-- 3. validate_menu_path(path_to_check text)
--    校验给定路径是否匹配已注册的菜单资源
--
--    替代原 Nest 端点：
--    - GET /permission/menu/validate?path=xxx
--    - PermissionService.validateMenuPath(path)
--
--    原实现使用 path-to-regexp 做动态路径匹配，
--    PostgreSQL 中用正则近似模拟（:param → [^/]+）
-- =========================================================================

CREATE OR REPLACE FUNCTION validate_menu_path(path_to_check text)
RETURNS boolean AS $$
DECLARE
  v_menu RECORD;
  v_regex text;
BEGIN
  FOR v_menu IN
    SELECT path FROM permissions
    WHERE type = 'MENU' AND path IS NOT NULL AND path != ''
  LOOP
    -- 将 Express 风格 :param 转换为正则 [^/]+
    v_regex := '^' || regexp_replace(v_menu.path, ':[a-zA-Z_][a-zA-Z0-9_]*', '[^/]+', 'g') || '$';
    IF path_to_check ~ v_regex THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

COMMENT ON FUNCTION validate_menu_path IS
  '校验给定路径是否匹配已注册的 MENU 类型权限路径，支持 :param 动态段';

-- =========================================================================
-- 4. get_user_roles_detail()
--    获取当前用户的角色详情（包含角色信息），用于前端角色切换
--
--    替代原 Nest 端点：
--    - GET /user/detail 中返回的 roles 数组
-- =========================================================================

CREATE OR REPLACE FUNCTION get_user_roles_detail()
RETURNS jsonb AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'code', r.code,
      'name', r.name,
      'enable', r.enable
    ) ORDER BY r.id ASC
  ), '[]'::jsonb)
  INTO v_result
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  WHERE ur.user_id = auth.uid()
    AND r.enable = true;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

COMMENT ON FUNCTION get_user_roles_detail IS
  '获取当前用户的所有启用角色详情，用于角色切换下拉菜单';

-- =========================================================================
-- 5. switch_current_role(target_role_id integer)
--    切换当前用户的激活角色
--
--    替代原 Nest 端点：
--    - POST /auth/current-role/switch/:roleCode
--    - AuthService.switchCurrentRole
-- =========================================================================

CREATE OR REPLACE FUNCTION switch_current_role(target_role_id integer)
RETURNS boolean AS $$
DECLARE
  v_has_role boolean;
BEGIN
  -- 校验用户是否拥有该角色
  SELECT EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND ur.role_id = target_role_id
      AND r.enable = true
  ) INTO v_has_role;

  IF NOT v_has_role THEN
    RAISE EXCEPTION '您目前暂无此角色，请联系管理员申请权限'
      USING ERRCODE = 'P0001';
  END IF;

  -- 更新当前角色
  UPDATE profiles
  SET current_role_id = target_role_id
  WHERE id = auth.uid();

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

COMMENT ON FUNCTION switch_current_role IS
  '切换当前用户的激活角色，校验用户确实拥有目标角色';
