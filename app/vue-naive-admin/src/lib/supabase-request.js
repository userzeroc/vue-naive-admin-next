import { supabase } from './supabase'

export function throwSupabaseError(error, message = 'Supabase request failed') {
  if (error)
    throw new Error(error.message || message)
}

export async function callRpc(name, args, message) {
  const { data, error } = await supabase.rpc(name, args)
  throwSupabaseError(error, message || `RPC ${name} failed`)
  return data
}
