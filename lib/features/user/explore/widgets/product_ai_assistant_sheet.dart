import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';
import 'package:skin_mate/core/services/supabase_service.dart';

class ProductAiAssistantSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> ingredients;
  final String? userSkinType;
  final List<String> userConcerns;
  final List<Map<String, dynamic>> personalWarnings;

  const ProductAiAssistantSheet({
    super.key,
    required this.product,
    required this.ingredients,
    required this.userSkinType,
    required this.userConcerns,
    required this.personalWarnings,
  });

  @override
  State<ProductAiAssistantSheet> createState() => _ProductAiAssistantSheetState();
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  _ChatMessage(this.role, this.content);
}

class _ProductAiAssistantSheetState extends State<ProductAiAssistantSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  static const List<String> _suggestedQuestions = [
    'Is this product suitable for my skin type?',
    'Which ingredient should I be most careful about?',
    'How should I use this in my routine?',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildContext() {
    return {
      'product': widget.product,
      'ingredients': widget.ingredients
          .map((i) => {
                'common_name': i['common_name'],
                'scientific_name_inci': i['scientific_name_inci'],
                'risk_level': i['risk_level'],
                'purpose_text': i['purpose_text'],
              })
          .toList(),
      'userSkinType': widget.userSkinType,
      'userConcerns': widget.userConcerns,
      'personalWarnings': widget.personalWarnings,
    };
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage('user', text.trim()));
      _sending = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    try {
      final response = await SupabaseService.client.functions.invoke(
        'product-ai-assistant',
        body: {
          'context': _buildContext(),
          'messages': _messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? 'Sorry, something went wrong.';

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage('assistant', reply));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage('assistant', 'Sorry, I ran into an error. Please try again.'));
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ask SkinMate AI',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text(
                            widget.product['product_name'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _messages.length) {
                            return _buildTypingBubble();
                          }
                          return _buildBubble(_messages[i]);
                        },
                      ),
              ),
              _buildInputBar(),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: AppColors.primaryMuted.withOpacity(0.4), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Ask me anything about this product — its ingredients,\nhow it fits your skin, or how to use it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestedQuestions
                .map((q) => ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.cardBackground,
                      onPressed: () => _send(q),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_inputCtrl.text),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}