const { WebSocketServer } = require('ws');

// 1. 创建 WebSocket 服务器，监听 8080 端口
const wss = new WebSocketServer({ port: 8080 });

console.log('🚀 WebSocket 服务器已启动，正在监听 ws://localhost:8080');

// 2. 监听客户端连接事件
wss.on('connection', function connection(ws) {
  console.log('✅ 有新客户端连接成功！');

  // 接收到客户端消息时的回调
  ws.on('message', function message(data) {
    // data 默认是 Buffer，需要 toString() 转成字符串
    const message = data.toString();
    console.log(`📩 收到消息: ${message}`);

    // 把收到的消息原样加上前缀再发回去（完整响应，包含原文与时间戳）
    const fullResponse = JSON.stringify({
      echo: `[服务器回显] 你发的是: ${message}`,
      receivedAt: new Date().toISOString(),
      original: message
    });
    ws.send(fullResponse);
  });

  // 监听连接断开
  ws.on('close', () => {
    console.log('❌ 客户端已断开连接');
  });

  // 监听错误
  ws.on('error', console.error);

  // 连接成功后，主动给客户端发一条欢迎消息
  ws.send('🎉 欢迎连接到本地 WebSocket 测试服务器！');
});