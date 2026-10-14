import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_keys.dart';

/// 全局悬浮球：可拖动，点击展开“问豆包”聊天面板。
/// 通过 MaterialApp.builder 挂在每一个页面之上。
class FloatingBall extends StatefulWidget {
  const FloatingBall({super.key});

  @override
  State<FloatingBall> createState() => _FloatingBallState();
}

// 跨页面保持悬浮球位置（builder 重建时位置不丢失）
class _BallPos {
  static Offset? pos;
}

class _FloatingBallState extends State<FloatingBall> {
  static const double _size = 52;
  Offset _pos = _BallPos.pos ?? const Offset(16, 420);
  bool _firstLayout = true;

  void _clamp(Size screen) {
    _pos = Offset(
      _pos.dx.clamp(0.0, screen.width - _size),
      _pos.dy.clamp(0.0, screen.height - _size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    if (_firstLayout) {
      _clamp(screen);
      _firstLayout = false;
    }
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _pos += d.delta;
            _clamp(screen);
            _BallPos.pos = _pos;
          });
        },
        onTap: () => _openChat(context),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4C6EF5), Color(0xFF3B5BDB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    // 悬浮球位于 Navigator 之上，必须用全局 navigatorKey 的上下文才能找到 Navigator
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChatPanel(),
    );
  }
}

/// 悬浮球展开的问答面板
class _ChatPanel extends StatefulWidget {
  const _ChatPanel();

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _msgs = [];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty || _sending) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': q});
      _sending = true;
      _input.clear();
    });
    _scrollToBottom();

    // 历史不含刚加入的这条
    final history = _msgs.length > 1
        ? _msgs.sublist(0, _msgs.length - 1)
        : <Map<String, String>>[];
    try {
      final answer = await ApiService.instance.askTutor(q, history);
      if (!mounted) return;
      setState(() => _msgs.add({'role': 'assistant', 'content': answer}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msgs.add({
            'role': 'assistant',
            'content': '连接后端失败，请确认后端已启动、设置页地址正确。（$e）',
          }));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 顶部标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3B5BDB), size: 20),
                const SizedBox(width: 8),
                const Text('问豆包 · 英语随身私教',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // 消息区
            Expanded(
              child: _msgs.isEmpty
                  ? _ChatHints(
                      onPick: (text) {
                        _input.text = text;
                        _send();
                      },
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _Bubble(msg: _msgs[i]),
                    ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            // 输入区
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '输入英语问题，如：that 引导什么从句？',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空对话时的快捷提问
class _ChatHints extends StatelessWidget {
  final void Function(String)? onPick;
  const _ChatHints({this.onPick});

  @override
  Widget build(BuildContext context) {
    const hints = [
      '这个单词怎么用？',
      '帮我分析一个长难句',
      '定语从句和同位语从句怎么区分？',
      '这句话怎么翻译更地道？',
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_rounded, size: 56, color: Color(0xFFB4C0F5)),
          const SizedBox(height: 12),
          const Text('随时问我单词、语法、翻译、长难句',
              style: TextStyle(color: Colors.black45, fontSize: 13.5)),
          const SizedBox(height: 14),
          for (final h in hints)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton(
                onPressed: onPick == null ? null : () => onPick!(h),
                child: Text(h),
              ),
            ),
        ],
      ),
    );
  }
}

/// 对话气泡
class _Bubble extends StatelessWidget {
  final Map<String, String> msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['role'] == 'user';
    final color = isUser ? const Color(0xFF3B5BDB) : const Color(0xFFF1F3F5);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 3),
            bottomRight: Radius.circular(isUser ? 3 : 14),
          ),
        ),
        child: SelectableText(
          msg['content'] ?? '',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
