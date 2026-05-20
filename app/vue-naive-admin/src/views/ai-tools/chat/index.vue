<template>
  <CommonPage show-footer>
    <n-space vertical :size="16">
      <n-card title="AI对话" :segmented="{ content: true }">
        <div ref="chatPanelRef"class="chat-panel">
          <div>没有消息的时候显示</div>

        </div>
        <template v-for="msg in messages" :key="msg.id">
          <div :class="['messgae-row',mesg.role]">
            <div class="avatar">
              <n-avatar :size="32" round :style="{ backgroundColor: msg.role === 'user' ? '#2080f0' : '#18a058' }">
                {{ mesg.role === 'user' ? '你' : 'AI' }}
              </n-avatar>
            </div>
            <div class="bubble-wrapper">
              <div :class="['bubble',msg.role]">
                <span class="bubble-text">{{ msg.content }}</span>
                <span v-if="msg.isStreaming" class="cursor-blink">|</span>
              </div>
              <!-- 消息状态 -->
              <div v-if="msg.status && msg.status!=='done'" class="msg.status">
                <n-tag v-if="msg.status ==='stopped'" size="small" type="warning" :bordered="false" round>
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

        <template #action>
          <div class="input-area">
            <n-input-group>
              <n-input />
              <n-button>清空对话</n-button>
              <n-button>停止回答</n-button>
              <n-button>发送</n-button>
            </n-input-group>
            
          </div>
        </template>
      </n-card>

      
    </n-space>
  </CommonPage>
</template>




<script setup>
import {ref} from 'vue'

const inputText = ref('')
const messages = ref([])
const isStreaming = ref(false)


function sendMessage() {
  const text = inputText.value.trim()
  if (!text) return

}

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