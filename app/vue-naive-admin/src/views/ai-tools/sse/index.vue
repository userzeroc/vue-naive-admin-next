<template>
  <CommonPage show-footer>
    <n-space vertical :size="16">
      <n-card title="SSE 流式输出练习">
        <n-grid :cols="3" :x-gap="12" :y-gap="12" responsive="screen">
          <n-gi>
            <n-statistic label="第一阶段" value="30 分钟">
              <template #suffix>
                Why & What
              </template>
            </n-statistic>
            <div class="mt-8 text-13 text-#666 dark:text-#aaa">
              对比 WebSocket，记住 Header、4 个字段和两个换行结束符。
            </div>
          </n-gi>
          <n-gi>
            <n-statistic label="第二阶段" value="40 分钟">
              <template #suffix>
                How
              </template>
            </n-statistic>
            <div class="mt-8 text-13 text-#666 dark:text-#aaa">
              用 fetch + ReadableStream 处理 POST、鉴权、半包和粘包。
            </div>
          </n-gi>
          <n-gi>
            <n-statistic label="第三阶段" value="20 分钟">
              <template #suffix>
                Defense
              </template>
            </n-statistic>
            <div class="mt-8 text-13 text-#666 dark:text-#aaa">
              提炼面试话术：EventSource 短板、Buffer 切包、HTTP/1.1 连接限制。
            </div>
          </n-gi>
        </n-grid>
      </n-card>

      <n-grid :cols="24" :x-gap="16" :y-gap="16" responsive="screen">
        <n-gi :span="10">
          <n-card title="请求控制">
            <n-form label-placement="top">
              <n-form-item label="Prompt">
                <n-input
                  v-model:value="prompt"
                  type="textarea"
                  :autosize="{ minRows: 6, maxRows: 10 }"
                  placeholder="输入一段较长 Prompt，观察 fetch POST 如何携带 body 和 Authorization"
                />
              </n-form-item>

              <n-form-item label="模型">
                <n-select v-model:value="model" :options="modelOptions" />
              </n-form-item>
            </n-form>

            <n-space>
              <n-button type="primary" :loading="fetchLoading" @click="startFetchStream">
                <i class="i-fe:play mr-4 text-18" />
                Fetch POST
              </n-button>
              <n-button :loading="eventSourceLoading" @click="startEventSource">
                <i class="i-fe:radio mr-4 text-18" />
                EventSource GET
              </n-button>
              <n-button type="warning" secondary @click="stopStream">
                <i class="i-fe:stop-circle mr-4 text-18" />
                停止
              </n-button>
              <n-button secondary @click="resetOutput">
                <i class="i-fe:trash-2 mr-4 text-18" />
                清空
              </n-button>
            </n-space>

            <n-alert class="mt-16" type="info" :bordered="false">
              EventSource 只能 GET，不能自定义 Authorization Header；真实 AI 对话通常用 fetch
              读流来支持 POST body 和 Bearer Token。
            </n-alert>
          </n-card>
        </n-gi>

        <n-gi :span="14">
          <n-card title="模型输出">
            <n-empty v-if="!answer" description="点击 Fetch POST 或 EventSource GET 开始练习" />
            <div v-else class="min-h-180 whitespace-pre-wrap rounded-6 bg-#f7f8fa p-14 lh-28 dark:bg-#18181c">
              {{ answer }}
            </div>
          </n-card>
        </n-gi>
      </n-grid>

      <n-grid :cols="24" :x-gap="16" :y-gap="16" responsive="screen">
        <n-gi :span="12">
          <n-card title="Raw Chunk">
            <n-scrollbar class="h-260">
              <n-code
                :code="rawChunks.length ? rawChunks.join('\n--- chunk ---\n') : '暂无字节块'"
                language="text"
                word-wrap
              />
            </n-scrollbar>
          </n-card>
        </n-gi>

        <n-gi :span="12">
          <n-card title="Buffer 与完整 Frame">
            <n-space vertical>
              <n-alert type="warning" :bordered="false">
                当前残留 Buffer：{{ pendingBuffer || '空' }}
              </n-alert>
              <n-scrollbar class="h-214">
                <n-code :code="parsedFramesText" language="json" word-wrap />
              </n-scrollbar>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>

      <n-card title="面试复盘">
        <n-timeline>
          <n-timeline-item type="success" title="为什么不用 WebSocket">
            只是服务端单向推送时，SSE 基于 HTTP，更轻量，天然支持浏览器自动重连。
          </n-timeline-item>
          <n-timeline-item type="info" title="为什么不用原生 EventSource">
            它只支持 GET，且不能设置 Authorization Header，长 Prompt 和鉴权场景会受限。
          </n-timeline-item>
          <n-timeline-item type="warning" title="fetch 读流关键链路">
            fetch -> response.body.getReader() -> reader.read() -> TextDecoder -> buffer 按 \n\n 切包。
          </n-timeline-item>
          <n-timeline-item type="error" title="半包与粘包">
            每次 read() 读到的只是网络 chunk，不等于一条完整 SSE 消息，必须先拼 buffer 再解析。
          </n-timeline-item>
        </n-timeline>
      </n-card>
    </n-space>
  </CommonPage>
</template>

<script setup>
import { useAuthStore } from '@/store'

defineOptions({ name: 'SsePractice' })

const authStore = useAuthStore()
const prompt = ref('请模拟大模型解释：为什么 AI 对话更适合用 SSE 流式输出？')
const model = ref('sse-practice-model')
const modelOptions = [
  { label: 'sse-practice-model', value: 'sse-practice-model' },
  { label: 'openai-compatible-demo', value: 'openai-compatible-demo' },
]

const answer = ref('')
const rawChunks = ref([])
const frames = ref([])
const pendingBuffer = ref('')
const fetchLoading = ref(false)
const eventSourceLoading = ref(false)

let abortController = null
let eventSource = null

const parsedFramesText = computed(() => {
  if (!frames.value.length)
    return '[]'
  return JSON.stringify(frames.value, null, 2)
})

async function startFetchStream() {
  resetOutput()
  stopStream()
  fetchLoading.value = true
  abortController = new AbortController()

  try {
    const response = await fetch(`${import.meta.env.VITE_AXIOS_BASE_URL}/sse/fetch-demo`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authStore.accessToken}`,
      },
      body: JSON.stringify({
        prompt: prompt.value,
        model: model.value,
      }),
      signal: abortController.signal,
    })

    if (!response.ok)
      throw new Error(`HTTP ${response.status}`)

    const reader = response.body.getReader()
    const decoder = new TextDecoder('utf-8')
    let buffer = ''

    while (true) {
      const { done, value } = await reader.read()
      if (done)
        break

      const chunk = decoder.decode(value, { stream: true })
      rawChunks.value.push(chunk)
      buffer += chunk
      buffer = consumeBuffer(buffer)
    }

    const tail = decoder.decode()
    if (tail) {
      rawChunks.value.push(tail)
      buffer += tail
      buffer = consumeBuffer(buffer)
    }

    pendingBuffer.value = buffer
  } catch (error) {
    if (error.name !== 'AbortError') {
      $message.error(error.message || 'SSE 请求失败')
    }
  } finally {
    fetchLoading.value = false
    abortController = null
  }
}

function startEventSource() {
  resetOutput()
  stopStream()
  eventSourceLoading.value = true

  eventSource = new EventSource(`${import.meta.env.VITE_AXIOS_BASE_URL}/sse/event-source-demo`)
  eventSource.addEventListener('token', (event) => {
    handleFrame({
      id: event.lastEventId,
      event: 'token',
      data: event.data,
      from: 'EventSource',
    })
  })
  eventSource.addEventListener('done', (event) => {
    handleFrame({
      id: event.lastEventId,
      event: 'done',
      data: event.data,
      from: 'EventSource',
    })
    stopStream()
  })
  eventSource.onerror = () => {
    eventSourceLoading.value = false
    eventSource?.close()
    eventSource = null
  }
}

function consumeBuffer(buffer) {
  const normalized = buffer.replace(/\r\n/g, '\n')
  let rest = normalized
  let boundaryIndex = rest.indexOf('\n\n')

  while (boundaryIndex !== -1) {
    const frameText = rest.slice(0, boundaryIndex)
    rest = rest.slice(boundaryIndex + 2)

    if (frameText.trim()) {
      const frame = parseSseFrame(frameText)
      handleFrame(frame)
    }

    boundaryIndex = rest.indexOf('\n\n')
  }

  pendingBuffer.value = rest
  return rest
}

function parseSseFrame(frameText) {
  const frame = {
    id: '',
    event: 'message',
    retry: '',
    data: '',
  }

  frameText.split('\n').forEach((line) => {
    const separatorIndex = line.indexOf(':')
    if (separatorIndex === -1)
      return

    const field = line.slice(0, separatorIndex)
    const value = line.slice(separatorIndex + 1).replace(/^ /, '')

    if (field === 'data') {
      frame.data += frame.data ? `\n${value}` : value
    } else if (field === 'id') {
      frame.id = value
    } else if (field === 'event') {
      frame.event = value
    } else if (field === 'retry') {
      frame.retry = value
    }
  })

  return frame
}

function handleFrame(frame) {
  frames.value.push(frame)

  if (frame.event === 'token') {
    const payload = safeJsonParse(frame.data)
    answer.value += payload?.content ?? frame.data
  }

  if (frame.event === 'done') {
    fetchLoading.value = false
    eventSourceLoading.value = false
  }
}

function safeJsonParse(text) {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

function stopStream() {
  abortController?.abort()
  abortController = null

  eventSource?.close()
  eventSource = null

  fetchLoading.value = false
  eventSourceLoading.value = false
}

function resetOutput() {
  answer.value = ''
  rawChunks.value = []
  frames.value = []
  pendingBuffer.value = ''
}

onBeforeUnmount(() => {
  stopStream()
})
</script>
