import 'package:flutter/services.dart';

class NativeSafDataSource {
  const NativeSafDataSource();

  static const MethodChannel _channel = MethodChannel(
    'com.mvcode.workspace/saf',
  );

  Future<Map<Object?, Object?>?> pickDirectory() async {
    return _channel.invokeMapMethod<Object?, Object?>('pickDirectory');
  }

  Future<Map<Object?, Object?>?> inspect(String uri) {
    return _channel.invokeMapMethod<Object?, Object?>(
      'inspect',
      <String, Object>{'uri': uri},
    );
  }

  Future<List<Object?>> listChildren(String uri) async {
    return await _channel.invokeListMethod<Object?>(
          'listChildren',
          <String, Object>{'uri': uri},
        ) ??
        <Object?>[];
  }

  Future<String> readText(String uri) async {
    return await _channel.invokeMethod<String>('readText', <String, Object>{
          'uri': uri,
        }) ??
        '';
  }

  Future<void> writeText(String uri, String content) {
    return _channel.invokeMethod<void>('writeText', <String, Object>{
      'uri': uri,
      'content': content,
    });
  }

  Future<Map<Object?, Object?>> createFile(
    String parentUri,
    String name,
  ) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          'createFile',
          <String, Object>{'parentUri': parentUri, 'name': name},
        ) ??
        <Object?, Object?>{};
  }

  Future<Map<Object?, Object?>> createDirectory(
    String parentUri,
    String name,
  ) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          'createDirectory',
          <String, Object>{'parentUri': parentUri, 'name': name},
        ) ??
        <Object?, Object?>{};
  }

  Future<Map<Object?, Object?>> rename(String uri, String name) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          'rename',
          <String, Object>{'uri': uri, 'name': name},
        ) ??
        <Object?, Object?>{};
  }

  Future<void> delete(String uri) {
    return _channel.invokeMethod<void>('delete', <String, Object>{'uri': uri});
  }

  Future<Map<Object?, Object?>> copyEntry(
    String uri,
    String targetParentUri,
  ) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          'copyEntry',
          <String, Object>{'uri': uri, 'targetParentUri': targetParentUri},
        ) ??
        <Object?, Object?>{};
  }

  Future<Map<Object?, Object?>> moveEntry(
    String uri,
    String sourceParentUri,
    String targetParentUri,
  ) async {
    return await _channel.invokeMapMethod<Object?, Object?>(
          'moveEntry',
          <String, Object>{
            'uri': uri,
            'sourceParentUri': sourceParentUri,
            'targetParentUri': targetParentUri,
          },
        ) ??
        <Object?, Object?>{};
  }

  Future<List<Object?>> pickFiles() async {
    return await _channel.invokeListMethod<Object?>('pickFiles') ?? <Object?>[];
  }

  Future<List<Object?>> search(
    String rootUri,
    String query, {
    required bool caseSensitive,
  }) async {
    return await _channel.invokeListMethod<Object?>(
          'searchText',
          <String, Object>{
            'rootUri': rootUri,
            'query': query,
            'caseSensitive': caseSensitive,
          },
        ) ??
        <Object?>[];
  }
}
