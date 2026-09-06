import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/workspace_entry.dart';
import 'native_saf_data_source.dart';

class WorkspaceRepository {
  WorkspaceRepository(this._source);

  final NativeSafDataSource _source;

  Future<WorkspaceEntry?> pickWorkspace() => _guard(() async {
    final Map<Object?, Object?>? raw = await _source.pickDirectory();
    return raw == null ? null : WorkspaceEntry.fromMap(raw);
  });

  Future<WorkspaceEntry?> inspect(String uri) => _guard(() async {
    final Map<Object?, Object?>? raw = await _source.inspect(uri);
    return raw == null ? null : WorkspaceEntry.fromMap(raw);
  });

  Future<List<WorkspaceEntry>> listChildren(String parentUri) =>
      _guard(() async {
        final List<Object?> raw = await _source.listChildren(parentUri);
        final List<WorkspaceEntry> entries = raw
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) =>
                  WorkspaceEntry.fromMap(item, parentUri: parentUri),
            )
            .toList();
        entries.sort((WorkspaceEntry a, WorkspaceEntry b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return entries;
      });

  Future<String> readText(String uri) => _guard(() => _source.readText(uri));

  Future<void> writeText(String uri, String content) =>
      _guard(() => _source.writeText(uri, content));

  Future<WorkspaceEntry> createFile(String parentUri, String name) => _guard(
    () async => WorkspaceEntry.fromMap(
      await _source.createFile(parentUri, name),
      parentUri: parentUri,
    ),
  );

  Future<WorkspaceEntry> createDirectory(String parentUri, String name) =>
      _guard(
        () async => WorkspaceEntry.fromMap(
          await _source.createDirectory(parentUri, name),
          parentUri: parentUri,
        ),
      );

  Future<WorkspaceEntry> rename(WorkspaceEntry entry, String name) => _guard(
    () async => WorkspaceEntry.fromMap(
      await _source.rename(entry.uri, name),
      parentUri: entry.parentUri,
    ),
  );

  Future<void> delete(String uri) => _guard(() => _source.delete(uri));

  Future<WorkspaceEntry> copyTo(WorkspaceEntry entry, String targetParentUri) =>
      _guard(
        () async => WorkspaceEntry.fromMap(
          await _source.copyEntry(entry.uri, targetParentUri),
          parentUri: targetParentUri,
        ),
      );

  Future<WorkspaceEntry> moveTo(WorkspaceEntry entry, String targetParentUri) =>
      _guard(
        () async => WorkspaceEntry.fromMap(
          await _source.moveEntry(
            entry.uri,
            entry.parentUri ?? '',
            targetParentUri,
          ),
          parentUri: targetParentUri,
        ),
      );

  Future<List<WorkspaceEntry>> pickFiles() => _guard(() async {
    final List<Object?> raw = await _source.pickFiles();
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(WorkspaceEntry.fromMap)
        .toList();
  });

  Future<List<SearchMatch>> search(
    String rootUri,
    String query, {
    bool caseSensitive = false,
  }) => _guard(() async {
    final List<Object?> raw = await _source.search(
      rootUri,
      query,
      caseSensitive: caseSensitive,
    );
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(SearchMatch.fromMap)
        .toList();
  });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw AppException(
        error.message ?? 'Falha ao acessar o armazenamento.',
        code: error.code,
        cause: error,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Não foi possível concluir a operação.', cause: error);
    }
  }
}
