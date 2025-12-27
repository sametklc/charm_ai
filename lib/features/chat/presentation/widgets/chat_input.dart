import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Chat input widget with text field, camera button, and send button
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onRequestSelfie;
  final bool isLoading;
  final bool isSelfieLoading;
  final bool enabled;
  final String? hintText;
  final FocusNode? focusNode;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onRequestSelfie,
    this.isLoading = false,
    this.isSelfieLoading = false,
    this.enabled = true,
    this.hintText,
    this.focusNode,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _hasText = false;
  bool _isOwnFocusNode = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    
    // Use provided focusNode or create our own
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _isOwnFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _isOwnFocusNode = true;
    }
  }

  /// Public method to prefill text and focus
  void prefillPhotoRequest() {
    const prefix = '📸 Describe photo: ';
    _controller.text = prefix;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: prefix.length),
    );
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    // Only dispose if we created our own focusNode
    if (_isOwnFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading || !widget.enabled) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleSelfieRequest() {
    if (widget.isLoading || widget.isSelfieLoading || !widget.enabled) return;
    // Prefill text input with photo request prefix instead of immediately generating
    prefillPhotoRequest();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anyLoading = widget.isLoading || widget.isSelfieLoading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Camera/Photo Request Button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: !anyLoading && widget.enabled ? _handleSelfieRequest : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: widget.enabled && !anyLoading
                          ? AppColors.secondary
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiary),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
              
            // Text Field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && !anyLoading,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Type a message...',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Material(
                color: _hasText && widget.enabled && !anyLoading
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _hasText && widget.enabled && !anyLoading
                      ? _handleSend
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _hasText && widget.enabled && !anyLoading
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiary),
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
