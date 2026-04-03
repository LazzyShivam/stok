import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export interface AgentConfig {
  provider?: 'anthropic' | 'openai';
  model: string;
  systemPrompt: string;
  name: string;
  temperature?: number;
  maxTokens?: number;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export const generateAgentResponse = async (
  config: AgentConfig,
  history: ChatMessage[],
  userMessage: string
): Promise<string> => {
  const provider = config.provider || 'anthropic';

  if (provider === 'openai') {
    const messages: OpenAI.ChatCompletionMessageParam[] = [
      { role: 'system', content: config.systemPrompt },
      ...history.map(m => ({ role: m.role as 'user' | 'assistant', content: m.content })),
      { role: 'user', content: userMessage },
    ];

    const response = await openai.chat.completions.create({
      model: config.model || 'gpt-4o-mini',
      max_tokens: config.maxTokens || 1024,
      temperature: config.temperature ?? 0.7,
      messages,
    });

    return response.choices[0]?.message?.content ?? '';
  }

  // Anthropic (default)
  const messages: Anthropic.MessageParam[] = [
    ...history.map(m => ({ role: m.role as 'user' | 'assistant', content: m.content })),
    { role: 'user', content: userMessage },
  ];

  const response = await anthropic.messages.create({
    model: config.model || 'claude-sonnet-4-6',
    max_tokens: config.maxTokens || 1024,
    system: config.systemPrompt,
    messages,
  });

  const content = response.content[0];
  return content.type === 'text' ? content.text : '';
};

export const streamAgentResponse = async (
  config: AgentConfig,
  history: ChatMessage[],
  userMessage: string,
  onChunk: (chunk: string) => void,
  onDone: (full: string) => void
): Promise<void> => {
  const provider = config.provider || 'anthropic';

  if (provider === 'openai') {
    const messages: OpenAI.ChatCompletionMessageParam[] = [
      { role: 'system', content: config.systemPrompt },
      ...history.map(m => ({ role: m.role as 'user' | 'assistant', content: m.content })),
      { role: 'user', content: userMessage },
    ];

    let fullText = '';
    const stream = await openai.chat.completions.create({
      model: config.model || 'gpt-4o-mini',
      max_tokens: config.maxTokens || 1024,
      temperature: config.temperature ?? 0.7,
      messages,
      stream: true,
    });

    for await (const chunk of stream) {
      const text = chunk.choices[0]?.delta?.content || '';
      if (text) {
        fullText += text;
        onChunk(text);
      }
    }
    onDone(fullText);
    return;
  }

  // Anthropic
  const messages: Anthropic.MessageParam[] = [
    ...history.map(m => ({ role: m.role as 'user' | 'assistant', content: m.content })),
    { role: 'user', content: userMessage },
  ];

  let fullText = '';
  const stream = anthropic.messages.stream({
    model: config.model || 'claude-sonnet-4-6',
    max_tokens: config.maxTokens || 1024,
    system: config.systemPrompt,
    messages,
  });

  stream.on('text', (text) => {
    fullText += text;
    onChunk(text);
  });

  stream.on('finalMessage', () => onDone(fullText));
  await stream.finalMessage();
};
