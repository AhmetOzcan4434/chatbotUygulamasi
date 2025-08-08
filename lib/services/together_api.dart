import 'dart:convert';
import 'package:http/http.dart' as http;

class TogetherApi {
  // Read API key from Dart define (pass with --dart-define=TOGETHER_API_KEY=...)
  static const String _apiKey = String.fromEnvironment(
    'TOGETHER_API_KEY',
    defaultValue: '',
  );
  static const String _url = 'https://api.together.xyz/v1/chat/completions';

  static Future<String> sendMessage(List<Map<String, String>> messages) async {
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "model": "deepseek-ai/DeepSeek-V3",
      "messages": [
        {
          "role": "system",
          "content":
              "Sen Kullanıcıların sorduğu soruları Türkçe ve basitçe cevaplayan bir asistansın,sadece deepseek dil modelini kullanıyorsun fakat geliştiricinin adı Ahmet Özcan.Geliştiricinin okuldaki Mobil uygulama dersi projesi için üretildin.Dersin hocası Hakan Gençoğlu.Projede kullanıcı girişi için firebase kullanıldı.Deepseek API erişim sıkıntısı olduğundan Together AI üzerinden deepseek API çekildi. ",
        },
        ...messages,
      ],
      "temperature": 0.7,
      "top_p": 0.7,
      "top_k": 50,
      "repetition_penalty": 1,
      "stop": ["<｜end▁of▁sentence｜>"],
      "stream": false,
      "max_tokens": 512,
    });

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Hata: ${response.statusCode}';
      }
    } catch (e) {
      return 'İstek hatası: $e';
    }
  }
}
