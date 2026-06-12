import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';  // для сохранения данных

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

  // Ключи для сохранения региона
  static const String REGION_KEY = 'emk_user_region';
  static const String CITY_KEY = 'emk_user_city_label';

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => isLoading = false);
            // После загрузки страницы восстанавливаем сохранённый регион из iOS
            _restoreRegionToWebView();
            // Добавляем JavaScript-обработчик для сохранения региона при его изменении на сайте
            _injectSaveRegionHandler();
          },
          onNavigationRequest: (request) {
            // Обработка звонков
            if (request.url.startsWith('tel:')) {
              _makePhoneCall(request.url);
              return NavigationDecision.prevent;
            }
            // Обработка WhatsApp
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

  /// Восстанавливает сохранённый регион из памяти iOS и вставляет в WebView
  Future<void> _restoreRegionToWebView() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRegion = prefs.getString(REGION_KEY);
    final savedCity = prefs.getString(CITY_KEY);

    if (savedRegion != null || savedCity != null) {
      // Формируем JavaScript код для восстановления кук и localStorage
      String js = '';
      if (savedRegion != null) {
        js += "document.cookie = 'emk_user_region=${_escapeJs(savedRegion)}; path=/; max-age=31536000';";
        js += "localStorage.setItem('emk_user_region', '${_escapeJs(savedRegion)}');";
      }
      if (savedCity != null) {
        js += "document.cookie = 'emk_user_city_label=${_escapeJs(savedCity)}; path=/; max-age=31536000';";
        js += "localStorage.setItem('emk_user_city_label', '${_escapeJs(savedCity)}');";
      }
      // Обновляем input location, если есть
      js += """
        var input = document.querySelector('input[name="location"]');
        if (input) {
          input.value = '${_escapeJs(savedCity ?? savedRegion)}';
          input.dispatchEvent(new Event('change', {bubbles: true}));
        }
        // Обновляем отображение кнопки выбора региона
        var btn = document.querySelector('#emkBtn span:first-child');
        if (btn) btn.innerText = '${_escapeJs(savedCity ?? savedRegion)}';
      """;
      await controller.runJavaScript(js);
      print('Восстановлен регион: ${savedCity ?? savedRegion}');
    }
  }

  /// Внедряет JavaScript, который при изменении региона на сайте отправляет данные во Flutter
  Future<void> _injectSaveRegionHandler() async {
    final String jsCode = """
      (function() {
        // Функция сохранения региона
        function saveRegionToFlutter(region, city) {
          // Отправляем данные во Flutter через специальный канал
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('saveRegion', region, city);
          } else {
            // Для webview_flutter используем window.location.href (костыль)
            // Можно также использовать window.webkit.messageHandlers, но проще так:
            console.log('Region changed:', region, city);
            // Создаём кастомное событие, которое будем перехватывать через onPageStarted (не идеально)
            // Поэтому лучше перейти на flutter_inappwebview, но для простоты:
            const iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = 'jsbridge://saveRegion?region=' + encodeURIComponent(region) + '&city=' + encodeURIComponent(city);
            document.body.appendChild(iframe);
            setTimeout(() => iframe.remove(), 100);
          }
        }

        // Перехватываем установку кук (вызывается при выборе региона на сайте)
        const originalSetCookie = document.cookie.__lookupSetter__;
        Object.defineProperty(document, 'cookie', {
          set: function(value) {
            if (value.includes('emk_user_region=')) {
              let region = value.split('emk_user_region=')[1].split(';')[0];
              saveRegionToFlutter(region, null);
            }
            if (value.includes('emk_user_city_label=')) {
              let city = value.split('emk_user_city_label=')[1].split(';')[0];
              saveRegionToFlutter(null, city);
            }
            originalSetCookie?.call(this, value);
          },
          get: function() {
            return originalGetCookie?.call(this);
          }
        });

        // Также следим за изменениями localStorage
        const originalSetItem = localStorage.setItem;
        localStorage.setItem = function(key, value) {
          if (key === 'emk_user_region') saveRegionToFlutter(value, null);
          if (key === 'emk_user_city_label') saveRegionToFlutter(null, value);
          originalSetItem.apply(this, arguments);
        };
      })();
    """;
    await controller.runJavaScript(jsCode);
  }

  /// Сохраняет регион в SharedPreferences (вызывается из JavaScript)
  Future<void> _saveRegionToNative(String? region, String? city) async {
    final prefs = await SharedPreferences.getInstance();
    if (region != null) {
      await prefs.setString(REGION_KEY, region);
      print('Сохранён регион: $region');
    }
    if (city != null) {
      await prefs.setString(CITY_KEY, city);
      print('Сохранён город: $city');
    }
  }

  // Обработка звонков
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

  // Обработка WhatsApp
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
