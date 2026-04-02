import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AiPromptWidget extends StatelessWidget {
  final void Function(String prompt) onPromptSelected;

  const AiPromptWidget({super.key, required this.onPromptSelected});

  static const List<Map<String, dynamic>> _prompts = [
    {'icon': Icons.summarize_outlined, 'label': 'Summarize', 'prompt': 'Please provide a brief summary of our conversation so far.'},
    {'icon': Icons.translate_outlined, 'label': 'Translate', 'prompt': 'Please translate my last message to Spanish.'},
    {'icon': Icons.lightbulb_outline, 'label': 'Ideas', 'prompt': 'Give me 3 creative ideas related to what we\'ve been discussing.'},
    {'icon': Icons.help_outline, 'label': 'Explain', 'prompt': 'Can you explain this in simpler terms?'},
    {'icon': Icons.format_list_bulleted, 'label': 'Steps', 'prompt': 'Break this down into step-by-step instructions.'},
    {'icon': Icons.code_outlined, 'label': 'Code', 'prompt': 'Write code to implement this.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: _prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = _prompts[i];
          return GestureDetector(
            onTap: () => onPromptSelected(p['prompt'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(p['label'] as String, style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
