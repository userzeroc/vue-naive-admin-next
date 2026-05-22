/**********************************
 * @Author: Ronnie Zhang
 * @LastEditor: Ronnie Zhang
 * @LastEditTime: 2023/12/04 22:50:38
 * @Email: zclzone@outlook.com
 * Copyright © 2023 Ronnie Zhang(大脸怪) | https://isme.top
 **********************************/

import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/store'

export default {
  // 获取用户信息（Supabase RPC）
  async getUser() {
    const { data, error } = await supabase.rpc('app_get_my_user_detail')
    if (error)
      throw error
    return { data }
  },
  // 刷新 token（读取当前 Supabase 会话）
  async refreshToken() {
    const { data, error } = await supabase.auth.getSession()
    if (error)
      throw error
    const accessToken = data?.session?.access_token
    if (!accessToken)
      throw new Error('No active Supabase session')
    return { data: { accessToken } }
  },
  // 登出（Supabase）
  async logout() {
    const { error } = await supabase.auth.signOut()
    if (error)
      throw error
    return true
  },
  // 切换当前角色（Supabase RPC）
  async switchCurrentRole(roleId) {
    const p_role_id = Number(roleId)
    if (Number.isNaN(p_role_id))
      throw new Error(`Invalid role id: ${roleId}`)

    const { error } = await supabase.rpc('app_switch_current_role', { p_role_id })
    if (error)
      throw error

    // 保持兼容现有 authStore.switchCurrentRole(data) 的入参结构
    const { accessToken } = useAuthStore()
    return { data: { accessToken } }
  },
  // 获取角色权限（Supabase RPC，扁平结构）
  async getRolePermissions() {
    const { data, error } = await supabase.rpc('app_get_my_permissions_flat')
    if (error)
      throw error
    return { data: data || [] }
  },
}
