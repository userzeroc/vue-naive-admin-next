import { Body, Controller, Get, Post, Req, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtGuard } from '@/common/guards';
import { SsePromptDto } from './dto';
import { SseService } from './sse.service';

@Controller('sse')
export class SseController {
  constructor(private readonly sseService: SseService) {}

  @Get('event-source-demo')
  async eventSourceDemo(@Res() res: Response) {
    this.prepareStream(res);
    res.write(this.sseService.formatFrame({ retry: 1500 }));

    const tokens = this.sseService.getDemoTokens('EventSource 只能 GET，不能自定义 Authorization Header');
    await this.writeDemoFrames(res, tokens, false);
  }

  @Post('fetch-demo')
  @UseGuards(JwtGuard)
  async fetchDemo(@Body() body: SsePromptDto, @Req() req: any, @Res() res: Response) {
    this.prepareStream(res);
    const tokens = this.sseService.getDemoTokens(body.prompt);

    res.write(
      this.sseService.formatFrame({
        id: 0,
        event: 'meta',
        retry: 1200,
        data: JSON.stringify({
          model: body.model || 'sse-practice-model',
          username: req.user?.username,
        }),
      }),
    );

    await this.writeDemoFrames(res, tokens, true);
  }

  private prepareStream(res: Response) {
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();
  }

  private async writeDemoFrames(res: Response, tokens: string[], splitFrame: boolean) {
    for (const [index, token] of tokens.entries()) {
      if (res.writableEnded) return;

      const frame = this.sseService.formatFrame({
        id: index + 1,
        event: 'token',
        data: JSON.stringify({ index, content: token }),
      });

      if (splitFrame && index === 2) {
        const middle = Math.max(8, Math.floor(frame.length / 2));
        res.write(frame.slice(0, middle));
        await this.sseService.sleep(280);
        res.write(frame.slice(middle));
      } else {
        res.write(frame);
      }

      await this.sseService.sleep(420);
    }

    if (!res.writableEnded) {
      res.write(
        this.sseService.formatFrame({
          id: tokens.length + 1,
          event: 'done',
          data: JSON.stringify({ reason: 'stop' }),
        }),
      );
      res.end();
    }
  }
}
