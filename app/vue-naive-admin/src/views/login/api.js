/**********************************
 * @Author: Ronnie Zhang
 * @LastEditor: Ronnie Zhang
 * @LastEditTime: 2023/12/05 21:28:30
 * @Email: zclzone@outlook.com
 * Copyright © 2023 Ronnie Zhang(大脸怪) | https://isme.top
 **********************************/

import { supabase } from '@/lib/supabase'
import { request } from '@/utils'

export default {
  toggleRole_: data => request.post('/auth/role/toggle', data),
  login_: data => request.post('/auth/login', data, { needToken: false }),
  getUser_: () => request.get('/user/detail'),

  async login({ email, password }) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error)
      throw error
    return { data: { accessToken: data.session?.access_token, session: data.session, user: data.user } }
  },

  async register({ email, password }) {
    const { data, error } = await supabase.auth.signUp({ email, password })
    if (error)
      throw error
    return { data }
  },

  async logout() {
    const { error } = await supabase.auth.signOut()
    if (error)
      throw error
    return { data: true }
  },
}
