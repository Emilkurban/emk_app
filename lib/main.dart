import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      debugShowCheckedModeBanner: false,
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

  static const String REGION_KEY = 'emk_user_region';
  static const String CITY_KEY = 'emk_user_city_label';

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => isLoading = false);
            _restoreRegionToWebView();
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('tel:')) {
              _makePhoneCall(request.url);
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith('https://wa.me/') ||
                request.url.startsWith('whatsapp:')) {
              _openWhatsApp(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://emk.az'));
  }

  Future<void> _restoreRegionToWebView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRegion = prefs.getString(REGION_KEY);
      final savedCity = prefs.getString(CITY_KEY);

      if (savedRegion != null || savedCity != null) {
        String js = '';
        if (savedRegion != null) {
          js += "document.cookie = 'emk_user_region=${_escapeJs(savedRegion)}; path=/; max-age=31536000';";
          js += "localStorage.setItem('emk_user_region', '${_escapeJs(savedRegion)}');";
        }
        if (savedCity != null) {
          js += "document.cookie = 'emk_user_city_label=${_escapeJs(savedCity)}; path=/; max-age=31536000';";
          js += "localStorage.setItem('emk_user_city_label', '${_escapeJs(savedCity)}');";
        }
        
        String displayValue = '';
        if (savedCity != null && savedCity.isNotEmpty) {
          displayValue = savedCity;
        } else if (savedRegion != null && savedRegion.isNotEmpty) {
          displayValue = savedRegion;
        }
        
        if (displayValue.isNotEmpty) {
          js += """
            var input = document.querySelector('input[name="location"]');
            if (input) {
              input.value = '${_escapeJs(displayValue)}';
              input.dispatchEvent(new Event('change', {bubbles: true}));
            }
            var btn = document.querySelector('#emkBtn span:first-child');
            if (btn) btn.innerText = '${_escapeJs(displayValue)}';
          """;
        }
        await controller.runJavaScript(js);
      }
    } catch (e) {
      print('Restore error: $e');
    }
  }

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

  String _escapeJs(String text) {
    return text.replaceAll("'", "\\'").replaceAll('"', '\\"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
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
