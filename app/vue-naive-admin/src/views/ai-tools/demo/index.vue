<template>
  <CommonPage show-footer>
    <n-space vertical :size="16">
      <!-- 阶段说明卡片 -->
      <n-card title="阶段一：健壮的流式控制">
        <n-grid :cols="2" :x-gap="12" :y-gap="12" responsive="screen">
          <n-gi>
            <n-statistic label="练习 1" value="停止生成">
              <template #suffix>
                AbortController
              </template>
            </n-statistic>
            <div class="mt-8 text-13 text-#666 dark:text-#aaa">
              用户点击「停止回答」→ controller.abort() → 捕获 AbortError → reader.cancel() 关闭流
            </div>
          </n-gi>
          <n-gi>
            <n-statistic label="练习 2" value="重试与断线重连">
              <template #suffix>
                Error Recovery
              </template>
            </n-statistic>
            <div class="mt-8 text-13 text-#666 dark:text-#aaa">
              reader.read() 异常时记录已接收文本，点击重试后携带上下文继续生成
            </div>
          </n-gi>
        </n-grid>
      </n-card>

      <!-- 聊天主面板 -->
      <n-card title="AI 对话" :segmented="{ content: true }">
        <!-- 消息列表 -->
        <div
          ref="chatPanelRef"
          class="chat-panel"
        >
          <!-- 空状态 -->
          <div v-if="messages.length === 0" class="empty-state">
            <n-empty description="输入你的问题，与通义千问对话">
              <template #extra>
                <n-space>
                  <n-tag v-for="suggestion in quickSuggestions" :key="suggestion" round :bordered="false" type="primary" class="cursor-pointer" @click="useSuggestion(suggestion)">
                    {{ suggestion }}
                  </n-tag>
                </n-space>
              </template>
            </n-empty>
          </div>

          <!-- 消息气泡列表 -->
          <template v-for="msg in messages" :key="msg.id">
            <div :class="['message-row', msg.role]">
              <div class="avatar">
                <n-avatar
                  :size="32"
                  round
                  :style="{ backgroundColor: msg.role === 'user' ? '#2080f0' : '#18a058' }"
                >
                  {{ msg.role === 'user' ? '你' : 'AI' }}
                </n-avatar>
              </div>
              <div class="bubble-wrapper">
                <div :class="['bubble', msg.role]">
                  <span class="bubble-text">{{ msg.content }}</span>
                  <span v-if="msg.isStreaming" class="cursor-blink">▊</span>
                </div>
                <!-- 消息状态标签 -->
                <div v-if="msg.status && msg.status !== 'done'" class="msg-status">
                  <n-tag v-if="msg.status === 'stopped'" size="small" type="warning" :bordered="false" round>
                    ⏹ 已停止生成
                  </n-tag>
                  <n-space v-if="msg.status === 'error'" align="center" :size="8">
                    <n-tag size="small" type="error" :bordered="false" round>
                      ⚠ 生成中断
                    </n-tag>
                    <n-button text type="primary" size="small" @click="retryMessage(msg)">
                      <i class="i-fe:refresh-cw mr-4" />
                      重试
                    </n-button>
                  </n-space>
                </div>
              </div>
            </div>
          </template>
        </div>

        <!-- 底部操作区 -->
        <template #action>
          <div class="input-area">
            <n-input
              v-model:value="inputText"
              type="textarea"
              :autosize="{ minRows: 1, maxRows: 4 }"
              placeholder="输入你的问题... (Shift+Enter 换行，Enter 发送)"
              :disabled="isStreaming"
              @keydown="handleKeyDown"
            />
            <n-space justify="end" class="mt-8" :size="8">
              <n-button secondary size="small" :disabled="messages.length === 0 || isStreaming" @click="clearMessages">
                <i class="i-fe:trash-2 mr-4" />
                清空对话
              </n-button>
              <n-button
                v-if="isStreaming"
                type="warning"
                size="small"
                @click="stopGeneration"
              >
                <i class="i-fe:stop-circle mr-4" />
                停止回答
              </n-button>
              <n-button
                v-else
                type="primary"
                size="small"
                :disabled="!inputText.trim()"
                @click="sendMessage"
              >
                <i class="i-fe:send mr-4" />
                发送
              </n-button>
            </n-space>
          </div>
        </template>
      </n-card>

      <!-- 技术要点面试复盘 -->
      <n-card title="技术要点复盘">
        <n-timeline>
          <n-timeline-item type="success" title="AbortController 停止生成">
            创建 AbortController 并将 signal 传给 fetch；点击停止时 abort()，在 catch 中判断 error.name === 'AbortError' 来区分用户主动停止和网络错误。
          </n-timeline-item>
          <n-timeline-item type="info" title="reader.cancel() 关闭底层流">
            abort() 只中断了 fetch，还需 reader.cancel() 确保 ReadableStream 底层资源释放，防止内存泄漏。
          </n-timeline-item>
          <n-timeline-item type="warning" title="断线重连策略">
            reader.read() 抛出非 AbortError 时，记录已接收 content，将其作为 assistant 部分回答放入上下文，追加"请继续"指令重新请求。
          </n-timeline-item>
          <n-timeline-item type="error" title="OpenAI 兼容协议解析">
            DashScope 返回 `data: {JSON}\n\n` 格式，需按 \n\n 切分 frame，提取 data: 后的 JSON，读取 choices[0].delta.content。流结束标志为 `data: [DONE]`。
          </n-timeline-item>
        </n-timeline>
      </n-card>
    </n-space>
  </CommonPage>
</template>

<script setup>
defineOptions({ name: 'AiDemo' })

// ========================
// 响应式状态
// ========================
const inputText = ref('')
const messages = ref([])
const isStreaming = ref(false)
let abortController = null
let currentReader = null
let messageIdCounter = 0

const chatPanelRef = ref(null)

const quickSuggestions = [
  '用一句话介绍 Vue 3',
  '写一个 JavaScript 快排',
  '解释什么是 SSE',
]

// ========================
// 发送消息
// ========================
function sendMessage() {
  const text = inputText.value.trim()
  if (!text || isStreaming.value)
    return

  // 1. 添加用户消息
  messages.value.push({
    id: ++messageIdCounter,
    role: 'user',
    content: text,
  })
  inputText.value = ''

  // 2. 构建发送给 API 的 messages（多轮上下文）
  const apiMessages = messages.value
    .filter(m => !m.isStreaming)
    .map(m => ({ role: m.role, content: m.content }))

  // 3. 发起流式请求
  startStream(apiMessages)
}

// ========================
// 核心：流式请求
// ========================
async function startStream(apiMessages) {
  // 1. 创建 AbortController（练习 1 核心）
  abortController = new AbortController()
  isStreaming.value = true

  // 2. 创建 assistant 消息占位
  const assistantMsg = reactive({
    id: ++messageIdCounter,
    role: 'assistant',
    content: '',
    isStreaming: true,
    status: 'streaming', // streaming | done | stopped | error
  })
  messages.value.push(assistantMsg)

  try {
    // 3. 发起 fetch（通过 Vite proxy 绕过 CORS）
    const response = await fetch('/dashscope-api/compatible-mode/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${import.meta.env.VITE_DASHSCOPE_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'qwen-turbo',
        messages: apiMessages,
        stream: true,
      }),
      signal: abortController.signal,
    })

    if (!response.ok) {
      const errorBody = await response.text()
      throw new Error(`HTTP ${response.status}: ${errorBody}`)
    }

    // 4. 获取 ReadableStream reader
    const reader = response.body.getReader()
    currentReader = reader
    const decoder = new TextDecoder('utf-8')
    let buffer = ''

    // 5. 循环读取流（SSE 协议解析）
    while (true) {
      const { done, value } = await reader.read()
      if (done)
        break

      const chunk = decoder.decode(value, { stream: true })
      buffer += chunk

      // 按 \n\n 切分 SSE frame（处理半包和粘包）
      const frames = buffer.split('\n\n')
      // 最后一个可能是不完整的 frame，保留在 buffer 中
      buffer = frames.pop() || ''

      for (const frame of frames) {
        if (!frame.trim())
          continue
        processFrame(frame, assistantMsg)
      }
    }

    // 处理 buffer 中可能残留的最后一个 frame
    if (buffer.trim()) {
      processFrame(buffer, assistantMsg)
    }

    // 6. 流正常结束
    if (assistantMsg.status === 'streaming') {
      assistantMsg.status = 'done'
    }
  }
  catch (error) {
    if (error.name === 'AbortError') {
      // 练习 1：用户主动停止
      assistantMsg.status = 'stopped'
    }
    else {
      // 练习 2：网络错误 / 其他异常
      assistantMsg.status = 'error'
      assistantMsg._retryContext = apiMessages // 保存上下文用于重试
      console.error('Stream error:', error)
      $message.error(`请求异常: ${error.message}`)
    }
  }
  finally {
    assistantMsg.isStreaming = false
    isStreaming.value = false
    abortController = null
    currentReader = null
    scrollToBottom()
  }
}

// ========================
// 解析单个 SSE frame
// ========================
function processFrame(frame, assistantMsg) {
  // 一个 frame 可能有多行（id: / event: / data:），我们只关心 data:
  const lines = frame.split('\n')
  for (const line of lines) {
    if (!line.startsWith('data:'))
      continue

    const dataStr = line.slice(5).trim()

    // [DONE] 标识流结束
    if (dataStr === '[DONE]') {
      assistantMsg.status = 'done'
      return
    }

    // 解析 JSON
    try {
      const data = JSON.parse(dataStr)
      const delta = data.choices?.[0]?.delta
      if (delta?.content) {
        assistantMsg.content += delta.content
        scrollToBottom()
      }
    }
    catch {
      // JSON 解析失败，忽略（可能是注释行等）
    }
  }
}

// ========================
// 练习 1：停止生成
// ========================
function stopGeneration() {
  // 1. abort() 中断 fetch 请求
  abortController?.abort()
  // 2. cancel() 关闭底层 ReadableStream（释放资源）
  currentReader?.cancel()
}

// ========================
// 练习 2：重试（断线重连）
// ========================
function retryMessage(failedMsg) {
  // 构建重试上下文：原始对话 + 已接收的部分回答 + 继续指令
  const retryContext = failedMsg._retryContext || []

  const retryMessages = [
    ...retryContext,
  ]

  // 如果已经有部分内容，把它作为 assistant 部分回答，让模型从这里继续
  if (failedMsg.content.trim()) {
    retryMessages.push(
      { role: 'assistant', content: failedMsg.content },
      { role: 'user', content: '请继续上面未完成的回答，直接从断点处继续，不要重复已有内容。' },
    )
  }

  // 移除失败的消息，重新生成
  const index = messages.value.findIndex(m => m.id === failedMsg.id)
  if (index !== -1)
    messages.value.splice(index, 1)

  // 重新发起流式请求
  startStream(retryMessages)
}

// ========================
// 辅助功能
// ========================
function handleKeyDown(e) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    sendMessage()
  }
}

function clearMessages() {
  messages.value = []
  messageIdCounter = 0
}

function useSuggestion(text) {
  inputText.value = text
  sendMessage()
}

function scrollToBottom() {
  nextTick(() => {
    const el = chatPanelRef.value
    if (el) {
      el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' })
    }
  })
}

// 页面卸载时清理
onBeforeUnmount(() => {
  abortController?.abort()
  currentReader?.cancel()
})
</script>

<style scoped>
.chat-panel {
  height: 480px;
  overflow-y: auto;
  padding: 16px;
  border-radius: 8px;
  background: var(--n-color-modal);
  border: 1px solid var(--n-border-color);
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
}

/* 消息行 */
.message-row {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
  align-items: flex-start;
}

.message-row.user {
  flex-direction: row-reverse;
}

.bubble-wrapper {
  max-width: 75%;
  display: flex;
  flex-direction: column;
}

.message-row.user .bubble-wrapper {
  align-items: flex-end;
}

/* 消息气泡 */
.bubble {
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.bubble.user {
  background: #2080f0;
  color: #fff;
  border-top-right-radius: 4px;
}

.bubble.assistant {
  background: var(--n-color);
  border: 1px solid var(--n-border-color);
  border-top-left-radius: 4px;
}

/* 打字光标闪烁 */
.cursor-blink {
  display: inline-block;
  animation: blink 0.7s step-end infinite;
  color: var(--n-text-color-base);
  font-size: 14px;
  vertical-align: text-bottom;
  margin-left: 2px;
}

@keyframes blink {
  50% { opacity: 0; }
}

/* 消息状态 */
.msg-status {
  margin-top: 6px;
  padding-left: 2px;
}

/* 输入区域 */
.input-area {
  width: 100%;
}

/* 滚动条美化 */
.chat-panel::-webkit-scrollbar {
  width: 6px;
}

.chat-panel::-webkit-scrollbar-thumb {
  background: rgba(128, 128, 128, 0.3);
  border-radius: 3px;
}

.chat-panel::-webkit-scrollbar-thumb:hover {
  background: rgba(128, 128, 128, 0.5);
}
</style>