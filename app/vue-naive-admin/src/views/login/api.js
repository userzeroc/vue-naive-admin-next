/**********************************
 * @Author: Ronnie Zhang
 * @LastEditor: Ronnie Zhang
 * @LastEditTime: 2023/12/05 21:28:30
 * @Email: zclzone@outlook.com
 * Copyright © 2023 Ronnie Zhang(大脸怪) | https://isme.top
 **********************************/

import { supabase } from '@/lib/supabase'

export default {
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
}
