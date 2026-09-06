class WorkspaceEntry {
  const WorkspaceEntry({
    required this.uri,
    required this.name,
    required this.mimeType,
    required this.isDirectory,
    required this.size,
    required this.lastModified,
    required this.flags,
    this.parentUri,
    this.relativePath = '',
  });

  factory WorkspaceEntry.fromMap(
    Map<Object?, Object?> map, {
    String? parentUri,
  }) {
    final String name = map['name'] as String? ?? 'Sem nome';
    final String parentPath = map['relativePath'] as String? ?? '';
    return WorkspaceEntry(
      uri: map['uri'] as String? ?? '',
      name: name,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      isDirectory: map['isDirectory'] as bool? ?? false,
      size: map['size'] as int? ?? 0,
      lastModified: map['lastModified'] as int? ?? 0,
      flags: map['flags'] as int? ?? 0,
      parentUri: parentUri ?? map['parentUri'] as String?,
      relativePath: parentPath.isEmpty ? name : parentPath,
    );
  }

  final String uri;
  final String name;
  final String mimeType;
  final bool isDirectory;
  final int size;
  final int lastModified;
  final int flags;
  final String? parentUri;
  final String relativePath;

  String get extension {
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  WorkspaceEntry copyWith({
    String? uri,
    String? name,
    String? parentUri,
    String? relativePath,
  }) {
    return WorkspaceEntry(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      mimeType: mimeType,
      isDirectory: isDirectory,
      size: size,
      lastModified: lastModified,
      flags: flags,
      parentUri: parentUri ?? this.parentUri,
      relativePath: relativePath ?? this.relativePath,
    );
  }
}

class OpenDocument {
  OpenDocument({
    required this.entry,
    required this.initialContent,
    this.loading = false,
  });

  WorkspaceEntry entry;
  String initialContent;
  bool loading;
  bool dirty = false;
  bool saving = false;

  String get uri => entry.uri;
}

class SearchMatch {
  const SearchMatch({
    required this.uri,
    required this.name,
    required this.path,
    required this.line,
    required this.column,
    required this.preview,
  });

  factory SearchMatch.fromMap(Map<Object?, Object?> map) => SearchMatch(
    uri: map['uri'] as String? ?? '',
    name: map['name'] as String? ?? '',
    path: map['path'] as String? ?? '',
    line: map['line'] as int? ?? 1,
    column: map['column'] as int? ?? 1,
    preview: map['preview'] as String? ?? '',
  );

  final String uri;
  final String name;
  final String path;
  final int line;
  final int column;
  final String preview;
}
