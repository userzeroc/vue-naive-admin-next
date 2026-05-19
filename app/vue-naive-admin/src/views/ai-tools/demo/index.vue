<template>
  <AppPage title="AI 聊天模拟" show-footer>
    <n-card title="简易 ChatGPT 对话框" class="w-full">
      <div class="flex flex-col h-full" style="min-height: 520px;">
        <div class="chat-panel flex-1 mb-4 rounded-12 border border-[var(--n-border-color)] bg-white p-4 overflow-hidden">
          <div v-if="!question">
            <n-empty description="请输入问题，点击发送即可查看模拟回答" />
          </div>
          <div v-else class="space-y-4">
            <div class="flex items-start">
              <div class="text-14 font-medium text-primary mr-3">用户</div>
              <div class="flex-1 rounded-10 bg-[#f5f7ff] p-3 text-14 whitespace-pre-line">{{ question }}</div>
            </div>
            <div class="flex items-start">
              <div class="text-14 font-medium text-success mr-3">助手</div>
              <div class="flex-1 rounded-10 bg-[#f7f7f8] p-3 text-14 whitespace-pre-line min-h-[140px]">{{ answer }}</div>
            </div>
          </div>
        </div>

        <n-form :model="form" label-placement="top">
          <n-form-item label="你的问题">
            <n-input
              type="textarea"
              v-model:value="form.prompt"
              placeholder="例如：请用一句话介绍 Vue 3"
              autosize
              rows="4"
            />
          </n-form-item>
          <n-space justify="end">
            <n-button secondary @click="handleClear">清空</n-button>
            <n-button type="primary" :disabled="!form.prompt.trim()" @click="handleSend">发送</n-button>
          </n-space>
        </n-form>
      </div>
    </n-card>
  </AppPage>
</template>

<script setup>
import { ref } from 'vue'

const form = ref({ prompt: '' })
const question = ref('')
const answer = ref('')

function handleSend() {
  const prompt = form.value.prompt.trim()
  if (!prompt)
    return
  question.value = prompt
  answer.value = `这是一个简单的模拟回复：\n\n${prompt}`
  form.value.prompt = ''
}

function handleClear() {
  form.value.prompt = ''
  question.value = ''
  answer.value = ''
}
</script>