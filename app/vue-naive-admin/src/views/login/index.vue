<!--------------------------------
 - @Author: Ronnie Zhang
 - @LastEditor: Ronnie Zhang
 - @LastEditTime: 2023/12/05 21:28:36
 - @Email: zclzone@outlook.com
 - Copyright © 2023 Ronnie Zhang(大脸怪) | https://isme.top
 --------------------------------->

<template>
  <div class="wh-full flex-col bg-[url(@/assets/images/login_bg.webp)] bg-cover">
    <div
      class="m-auto max-w-700 min-w-345 f-c-c rounded-8 auto-bg bg-opacity-20 bg-cover p-12 card-shadow"
    >
      <div class="hidden w-380 px-20 py-35 md:block">
        <img src="@/assets/images/login_banner.webp" class="w-full" alt="login_banner">
      </div>

      <div class="w-320 flex-col px-20 py-32">
        <h2 class="f-c-c text-24 text-#6a6a6a font-normal">
          <img src="@/assets/images/logo.png" class="mr-12 h-50">
          {{ title }}
        </h2>
        <n-input
          v-model:value="loginInfo.email"
          autofocus
          class="mt-32 h-40 items-center"
          placeholder="请输入邮箱"
          :maxlength="64"
        >
          <template #prefix>
            <i class="i-fe:mail mr-12 opacity-20" />
          </template>
        </n-input>
        <n-input
          v-model:value="loginInfo.password"
          class="mt-20 h-40 items-center"
          type="password"
          show-password-on="mousedown"
          placeholder="请输入密码"
          :maxlength="20"
          @keydown.enter="handleLogin()"
        >
          <template #prefix>
            <i class="i-fe:lock mr-12 opacity-20" />
          </template>
        </n-input>

        <n-checkbox
          class="mt-20"
          :checked="isRemember"
          label="记住我"
          :on-update:checked="(val) => (isRemember = val)"
        />

        <div class="mt-20 flex items-center">
          <n-button
            class="h-40 flex-1 rounded-5 text-16"
            type="primary"
            ghost
            :loading="loading"
            @click="handleRegister()"
          >
            注册
          </n-button>

          <n-button
            class="ml-20 h-40 flex-1 rounded-5 text-16"
            type="primary"
            :loading="loading"
            @click="handleLogin()"
          >
            登录
          </n-button>
        </div>
      </div>
    </div>

    <TheFooter class="py-12" />
  </div>
</template>

<script setup>
import { useStorage } from '@vueuse/core'
import { useAuthStore } from '@/store'
import { lStorage } from '@/utils'
import api from './api'

const authStore = useAuthStore()
const router = useRouter()
const route = useRoute()
const title = import.meta.env.VITE_TITLE

const loginInfo = ref({
  email: '',
  password: '',
})

const localLoginInfo = lStorage.get('loginInfo')
if (localLoginInfo) {
  loginInfo.value.email = localLoginInfo.email || localLoginInfo.username || ''
  loginInfo.value.password = localLoginInfo.password || ''
}

const isRemember = useStorage('isRemember', true)
const loading = ref(false)

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

async function handleLogin() {
  const { email, password } = loginInfo.value
  if (!email || !password)
    return $message.warning('请输入邮箱和密码')
  if (!isValidEmail(email))
    return $message.warning('请输入正确的邮箱格式')

  try {
    loading.value = true
    $message.loading('正在登录，请稍后...', { key: 'login' })

    const { data } = await api.login({ email, password: password.toString() })
    const accessToken = data?.accessToken
    if (!accessToken)
      throw new Error('登录成功但未获取 accessToken')

    if (isRemember.value)
      lStorage.set('loginInfo', { email, password })
    else lStorage.remove('loginInfo')

    onLoginSuccess({ accessToken })
  }
  catch (error) {
    $message.destroy('login')
    console.error(error)
  }
  finally {
    loading.value = false
  }
}

async function handleRegister() {
  const { email, password } = loginInfo.value
  if (!email || !password)
    return $message.warning('请输入邮箱和密码')
  if (!isValidEmail(email))
    return $message.warning('请输入正确的邮箱格式')
  if (password.length < 6)
    return $message.warning('密码至少 6 位')

  try {
    loading.value = true
    $message.loading('正在注册，请稍后...', { key: 'register' })

    const { data } = await api.register({ email, password: password.toString() })
    const accessToken = data?.session?.access_token

    if (accessToken) {
      $message.success('注册成功并已登录', { key: 'register' })
      return onLoginSuccess({ accessToken })
    }

    $message.success('注册成功，请前往邮箱确认后登录', { key: 'register' })
  }
  catch (error) {
    $message.destroy('register')
    console.error(error)
  }
  finally {
    loading.value = false
  }
}

function onLoginSuccess(data = {}) {
  authStore.setToken(data)
  $message.success('登录成功', { key: 'login' })
  if (route.query.redirect) {
    const path = route.query.redirect
    delete route.query.redirect
    router.push({ path, query: route.query })
  }
  else {
    router.push('/')
  }
}
</script>
