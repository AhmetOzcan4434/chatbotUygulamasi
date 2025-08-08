import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import '../services/together_api.dart';

class ChatPage extends StatefulWidget {
  final String title;
  final Color themeColor;
  final IconData icon;
  final String welcomeMessage;

  const ChatPage({
    super.key, 
    required this.title, 
    required this.themeColor, 
    required this.icon,
    required this.welcomeMessage,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Her sayfada farklı bir hoşgeldin mesajı gösterelim
    _messages.add({"role": "assistant", "content": widget.welcomeMessage});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // TogetherApi'den yanıt al
      final response = await TogetherApi.sendMessage([..._messages]);
      
      if (mounted) {
        setState(() {
          _messages.add({"role": "assistant", "content": response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"role": "assistant", "content": "Bir hata oluştu: $e"});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: widget.title,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return LoadingBubble(color: widget.themeColor);
                }
                
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                return MessageBubble(
                  text: message['content'] ?? '',
                  isUser: isUser,
                  themeColor: widget.themeColor,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.1),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) _sendMessage(value);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      hintText: 'Mesaj yaz...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: widget.themeColor,
                  onPressed: _isLoading
                      ? null
                      : () {
                          final text = _controller.text.trim();
                          if (text.isNotEmpty) _sendMessage(text);
                        },
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Message bubble widget
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color themeColor;

  const MessageBubble({
    super.key, 
    required this.text, 
    required this.isUser,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? themeColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.1),
            )
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// Loading animation when waiting for response
class LoadingBubble extends StatelessWidget {
  final Color color;
  
  const LoadingBubble({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(1),
            _buildDot(2),
            _buildDot(3),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: AnimatedOpacity(
        opacity: 0.5,
        duration: Duration(milliseconds: 300 * index),
        alwaysIncludeSemantics: true,
        child: Container(),
      ),
    );
  }
}

class Page1 extends StatelessWidget {
  const Page1({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      title: 'Genel Sohbet',
      themeColor: Colors.blue,
      icon: Icons.chat,
      welcomeMessage: 'Merhaba! Ben DeepSeek AI asistanım. Genel Sohbet odasına hoş geldiniz. Size nasıl yardımcı olabilirim?',
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      title: 'Eğitim Asistanı',
      themeColor: Colors.green,
      icon: Icons.school,
      welcomeMessage: 'Eğitim Asistanı olarak size yardımcı olmaktan mutluluk duyarım. Ders çalışma, ödev veya akademik konularda sorularınızı sorabilirsiniz.',
    );
  }
}

class Page3 extends StatelessWidget {
  const Page3({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      title: 'Teknoloji Rehberi',
      themeColor: Colors.orange,
      icon: Icons.computer,
      welcomeMessage: 'Teknoloji Rehberi olarak hizmetinizdeyim. Yazılım, donanım veya diğer teknolojik konularda sorularınızı yanıtlayabilirim.',
    );
  }
}

class Page4 extends StatelessWidget {
  const Page4({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      title: 'Sağlık Danışmanı',
      themeColor: Colors.purple,
      icon: Icons.health_and_safety,
      welcomeMessage: 'Sağlık Danışmanı olarak genel bilgi vermekten memnuniyet duyarım. Sağlıklı yaşam, beslenme veya fitness hakkında sorularınızı sorabilirsiniz. Not: Tıbbi tavsiye için her zaman bir doktora danışın.',
    );
  }
}

class Page5 extends StatelessWidget {
  const Page5({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      title: 'Sanat ve Kültür',
      themeColor: Colors.red,
      icon: Icons.palette,
      welcomeMessage: 'Sanat ve Kültür alanında sizlere yardımcı olmaktan mutluluk duyarım. Resim, müzik, edebiyat, tarih veya kültürel konularda sorularınızı sorabilirsiniz.',
    );
  }
} 