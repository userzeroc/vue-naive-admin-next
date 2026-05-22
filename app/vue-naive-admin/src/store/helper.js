import { cloneDeep } from 'lodash-es'
import api from '@/api'
import { basePermissions } from '@/settings'

function normalizePermission(item = {}) {
  return {
    ...item,
    parentId: item.parentId ?? item.parent_id ?? null,
    keepAlive: item.keepAlive ?? item.keep_alive ?? false,
    order: item.order ?? 0,
    children: [],
  }
}

function buildPermissionTree(list = []) {
  const nodes = list.map(normalizePermission)
  const nodeMap = new Map()
  nodes.forEach((node) => {
    nodeMap.set(node.id, node)
  })

  const roots = []
  nodes.forEach((node) => {
    const parentId = node.parentId
    if (parentId == null || !nodeMap.has(parentId)) {
      roots.push(node)
      return
    }
    nodeMap.get(parentId).children.push(node)
  })

  const sortTree = (arr = []) => {
    arr.sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
    arr.forEach(item => sortTree(item.children))
  }
  sortTree(roots)
  return roots
}

function normalizeTreeNodes(list = []) {
  const walk = (item) => {
    const node = normalizePermission(item)
    const children = Array.isArray(item.children) ? item.children : []
    node.children = children.map(walk)
    return node
  }
  return list.map(walk)
}

export async function getUserInfo() {
  const res = await api.getUser()
  const { id, username, profile, roles, currentRole } = res.data || {}
  return {
    id,
    username,
    avatar: profile?.avatar,
    nickName: profile?.nickName ?? profile?.nick_name,
    gender: profile?.gender,
    address: profile?.address,
    email: profile?.email,
    roles: roles || [],
    currentRole,
  }
}

export async function getPermissions() {
  let asyncPermissions = []
  try {
    const res = await api.getRolePermissions()
    const permissions = res?.data
    const rawPermissions = Array.isArray(permissions) ? permissions : (permissions?.permissions || [])

    // 兼容两种返回：
    // 1) 树结构：每个节点有 children
    // 2) 扁平结构：仅有 parentId / parent_id
    const hasTreeShape = rawPermissions.some(item => Array.isArray(item?.children))
    asyncPermissions = hasTreeShape
      ? normalizeTreeNodes(rawPermissions)
      : buildPermissionTree(rawPermissions)
  }
  catch (error) {
    console.error(error)
  }
  return cloneDeep(basePermissions).concat(asyncPermissions)
}
