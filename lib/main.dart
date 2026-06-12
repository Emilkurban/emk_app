import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';   // ← ОБЯЗАТЕЛЬНО

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => isLoading = false);
          },
          onNavigationRequest: (request) {
            // 1. Обработка телефонных звонков
            if (request.url.startsWith('tel:')) {
              _makePhoneCall(request.url);
              return NavigationDecision.prevent;
            }
            // 2. Обработка WhatsApp
            if (request.url.startsWith('https://wa.me/') ||
                request.url.startsWith('whatsapp:')) {
              _openWhatsApp(request.url);
              return NavigationDecision.prevent;
            }
            // 3. Все остальные ссылки загружаем внутри WebView
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://emk.az'));
  }

  // Функция звонка
  Future<void> _makePhoneCall(String url) async {
    final Uri phoneUri = Uri.parse(url);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showErrorDialog('Невозможно совершить звонок');
      }
    } catch (e) {
      _showErrorDialog('Ошибка при звонке');
    }
  }

  // Функция открытия WhatsApp
  Future<void> _openWhatsApp(String url) async {
    final Uri whatsappUri = Uri.parse(url);
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        _showErrorDialog('Невозможно открыть WhatsApp');
      }
    } catch (e) {
      _showErrorDialog('Ошибка при открытии WhatsApp');
    }
  }

  // Диалог ошибки
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
