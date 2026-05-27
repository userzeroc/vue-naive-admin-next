/**********************************
 * @Author: Ronnie Zhang
 * @LastEditor: Ronnie Zhang
 * @LastEditTime: 2023/12/04 22:50:38
 * @Email: zclzone@outlook.com
 * Copyright © 2023 Ronnie Zhang(大脸怪) | https://isme.top
 **********************************/

import { supabase } from '@/lib/supabase'
import { callRpc, throwSupabaseError } from '@/lib/supabase-request'
import { useAuthStore } from '@/store'

export default {
  // 获取用户信息（Supabase RPC）
  async getUser() {
    const data = await callRpc('app_get_my_user_detail')
    return { data: data || {} }
  },
  // 刷新 token（读取当前 Supabase 会话）
  async refreshToken() {
    const { data, error } = await supabase.auth.getSession()
    throwSupabaseError(error, 'Get session failed')
    const accessToken = data?.session?.access_token
    if (!accessToken)
      throw new Error('No active Supabase session')
    return { data: { accessToken } }
  },
  // 登出（Supabase）
  async logout() {
    const { error } = await supabase.auth.signOut()
    throwSupabaseError(error, 'Sign out failed')
    return true
  },
  // 切换当前角色（Supabase RPC）
  async switchCurrentRole(roleId) {
    const p_role_id = Number(roleId)
    if (Number.isNaN(p_role_id))
      throw new Error(`Invalid role id: ${roleId}`)

    await callRpc('app_switch_current_role', { p_role_id }, 'Switch current role failed')

    // 保持兼容现有 authStore.switchCurrentRole(data) 的入参结构
    const { accessToken } = useAuthStore()
    return { data: { accessToken } }
  },
  // 获取角色权限（Supabase RPC，扁平结构）
  async getRolePermissions() {
    const data = await callRpc('app_get_my_permissions_flat')
    return { data: data || [] }
  },
}
