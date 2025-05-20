import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

void main() {
  runApp(const MessagingApp());
}

// 1. Add a dark mode toggle
enum AppTheme { light, dark }

class MessagingApp extends StatefulWidget {
  const MessagingApp({super.key});
  @override
  State<MessagingApp> createState() => _MessagingAppState();
}

class _MessagingAppState extends State<MessagingApp> {
  AppTheme _theme = AppTheme.light;
  void _toggleTheme() => setState(
    () => _theme = _theme == AppTheme.light ? AppTheme.dark : AppTheme.light,
  );
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messaging App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _theme == AppTheme.light ? ThemeMode.light : ThemeMode.dark,
      home: ChatScreen(
        onToggleTheme: _toggleTheme,
        isDark: _theme == AppTheme.dark,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;
  const ChatScreen({super.key, this.onToggleTheme, this.isDark = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _showEmojiPicker = false;
  late IO.Socket socket;
  String? _userName;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _showTypingIndicator = false;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _promptForName();
  }

  void _promptForName() async {
    await Future.delayed(Duration.zero);
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter your name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Your name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _avatarPath != null
                      ? CircleAvatar(backgroundImage: AssetImage(_avatarPath!))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  TextButton(
                    onPressed: _pickAvatar,
                    child: const Text('Pick Avatar'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    setState(() {
      _userName = name ?? 'User';
    });
    _initSocket();
  }

  void _onTextChanged(String value) {
    if (!_isTyping) {
      _isTyping = true;
      socket.emit('typing', {'sender': _userName});
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      socket.emit('stop_typing', {'sender': _userName});
    });
  }

  void _initSocket() {
    socket = IO.io('http://192.168.29.63:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      debugPrint('Connected to socket server');
    });
    socket.on('message', (data) {
      if (data['sender'] != _userName) {
        setState(() {
          _messages.insert(
            0,
            _Message(
              text: data['text'],
              isMe: false,
              sender: data['sender'] ?? 'Anonymous',
              time: data['time'],
              reaction: null,
            ),
          );
        });
      }
    });
    socket.on('typing', (data) {
      setState(() {
        _showTypingIndicator = true;
      });
    });
    socket.on('stop_typing', (data) {
      setState(() {
        _showTypingIndicator = false;
      });
    });
    socket.on('reaction', (data) {
      setState(() {
        final idx = _messages.indexWhere(
          (m) => m.time == data['time'] && m.sender == data['sender'],
        );
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(reaction: data['reaction']);
        }
      });
    });
    socket.onDisconnect((_) => debugPrint('Disconnected from socket server'));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    socket.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && _userName != null) {
      final now = TimeOfDay.now();
      final time = now.format(context);
      final message = _Message(
        text: text,
        isMe: true,
        sender: _userName!,
        time: time,
      );
      setState(() {
        _messages.insert(0, message);
      });
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 400),
      );
      socket.emit('message', {
        'text': text,
        'sender': _userName!,
        'time': time,
      });
      _controller.clear();
      _animateSendButton();
    }
  }

  // Animation for send button
  double _sendScale = 1.0;
  void _animateSendButton() async {
    setState(() => _sendScale = 1.2);
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() => _sendScale = 1.0);
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null &&
        result.files.single.path != null &&
        _userName != null) {
      final now = TimeOfDay.now();
      final time = now.format(context);
      setState(() {
        _messages.insert(
          0,
          _Message(
            text: '📎 File: ${result.files.single.name}',
            isMe: true,
            sender: _userName!,
            time: time,
          ),
        );
      });
      socket.emit('message', {
        'text': '📎 File: ${result.files.single.name}',
        'sender': _userName!,
        'time': time,
      });
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null && _userName != null) {
      final now = TimeOfDay.now();
      final time = now.format(context);
      setState(() {
        _messages.insert(
          0,
          _Message(
            text: '📷 Photo taken!',
            isMe: true,
            sender: _userName!,
            time: time,
          ),
        );
      });
      socket.emit('message', {
        'text': '📷 Photo taken!',
        'sender': _userName!,
        'time': time,
      });
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    _controller.text += emoji.emoji;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  void _sendReaction(_Message message, String reaction) {
    socket.emit('reaction', {
      'sender': message.sender,
      'time': message.time,
      'reaction': reaction,
    });
    setState(() {
      final idx = _messages.indexWhere(
        (m) => m.time == message.time && m.sender == message.sender,
      );
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(reaction: reaction);
      }
    });
  }

  void _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarPath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: Row(
          children: [
            _avatarPath != null
                ? CircleAvatar(backgroundImage: AssetImage(_avatarPath!))
                : const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.green),
                ),
            const SizedBox(width: 8),
            Text(_userName ?? '', style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.video_call, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                widget.isDark
                    ? [const Color(0xFF232526), const Color(0xFF414345)]
                    : [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: AnimatedList(
                key: _listKey,
                reverse: true,
                initialItemCount: _messages.length,
                itemBuilder: (context, index, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: 0.0,
                    child: _messages[index],
                  );
                },
              ),
            ),
            if (_showTypingIndicator)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Someone is typing...',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            _buildInputArea(),
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                  config: const Config(columns: 7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.green,
              ),
              onPressed: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                });
              },
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                ),
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.green),
              onPressed: _pickFile,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.green),
              onPressed: _pickImage,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedScale(
                scale: _sendScale,
                duration: const Duration(milliseconds: 120),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;
  final String? time;
  final String? reaction;
  const _Message({
    required this.text,
    required this.isMe,
    required this.sender,
    this.time,
    this.reaction,
  });

  _Message copyWith({String? reaction}) => _Message(
    text: text,
    isMe: isMe,
    sender: sender,
    time: time,
    reaction: reaction ?? this.reaction,
  );

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? Colors.green[400] : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final mainAlign = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final radius =
        isMe
            ? const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            )
            : const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
            );
    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: mainAlign,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: align,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 2),
                        child: Text(
                          sender,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    Material(
                      color: bubbleColor,
                      borderRadius: radius,
                      elevation: 2,
                      shadowColor: Colors.black12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              text,
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                            if (reaction != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  reaction!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            if (time != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  time!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
