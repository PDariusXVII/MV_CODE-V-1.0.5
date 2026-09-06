import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({required this.title, required this.html, super.key});

  final String title;
  final String html;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  InAppWebViewController? _controller;
  final List<String> _console = <String>[];
  bool _showConsole = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pré-visualização — ${widget.title}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recarregar',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Console',
            onPressed: () => setState(() => _showConsole = !_showConsole),
            icon: Badge(
              isLabelVisible: _console.isNotEmpty,
              label: Text('${_console.length}'),
              child: const Icon(Icons.terminal),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: widget.html,
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: WebUri('https://mvcode.local/'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                cacheEnabled: false,
                blockNetworkLoads: true,
                supportZoom: true,
                mediaPlaybackRequiresUserGesture: true,
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                _controller = controller;
              },
              onConsoleMessage: (_, ConsoleMessage message) {
                setState(() {
                  _console.add('[${message.messageLevel}] ${message.message}');
                  if (_console.length > 200) _console.removeAt(0);
                });
              },
            ),
          ),
          if (_showConsole)
            Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: _console.isEmpty
                  ? const Center(child: Text('Console vazio.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _console.length,
                      itemBuilder: (_, int index) => SelectableText(
                        _console[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFD5D9E0),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
