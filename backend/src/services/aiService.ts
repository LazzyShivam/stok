import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export interface AgentConfig {
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
