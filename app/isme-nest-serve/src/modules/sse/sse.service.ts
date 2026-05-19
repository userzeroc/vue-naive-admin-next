import { Injectable } from '@nestjs/common';

type SseFrame = {
  data?: string;
  event?: string;
  id?: string | number;
  retry?: number;
};

@Injectable()
export class SseService {
  formatFrame(frame: SseFrame) {
    const lines: string[] = [];
    if (frame.id !== undefined) lines.push(`id: ${frame.id}`);
    if (frame.event) lines.push(`event: ${frame.event}`);
    if (frame.retry !== undefined) lines.push(`retry: ${frame.retry}`);
    if (frame.data !== undefined) {
      const dataLines = frame.data.split('\n');
      dataLines.forEach((line) => lines.push(`data: ${line}`));
    }
    return `${lines.join('\n')}\n\n`;
  }

  getDemoTokens(prompt = '') {
    const normalizedPrompt = prompt.trim() || '请用一句话解释 SSE';
    return [
      '收到你的 Prompt：',
      normalizedPrompt,
      '。SSE 的响应头是 text/event-stream，',
      '每条消息用 data/id/event/retry 组织，',
      '并且必须用两个换行符作为消息结束符。',
      '前端用 fetch 读流时，要维护 buffer 处理半包和粘包。',
    ];
  }

  sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
