import { IsOptional, IsString, MaxLength } from 'class-validator';

export class SsePromptDto {
  @IsString()
  @MaxLength(4000)
  prompt: string;

  @IsString()
  @IsOptional()
  model?: string;
}
