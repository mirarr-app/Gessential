import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../domain/entities/chat_message.dart';

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: message.isUser
            ? Text(
                message.content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            : _buildAssistantMessageContent(context),
      ),
    );
  }

  Widget _buildAssistantMessageContent(BuildContext context) {
    // If the content is empty, show a placeholder
    if (message.content.isEmpty) {
      return Text(
        'No content',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Try to render as markdown with error handling
    try {
      return MarkdownBody(
        data: message.content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          code: TextStyle(
            backgroundColor: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.5),
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        selectable: true,
        onTapLink: (text, href, title) {
          // Handle link taps if needed
        },
      );
    } catch (e) {
      // If markdown rendering fails, fallback to plain text
      return Text(
        message.content,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      );
    }
  }
}
