import 'dart:convert';

/// 自动归类规则配置模型
class OrganizeCategory {
  final String name;
  final List<String> extensions;
  final String folderName;
  final bool enabled;

  const OrganizeCategory({
    required this.name,
    required this.extensions,
    required this.folderName,
    this.enabled = true,
  });

  OrganizeCategory copyWith({
    String? name,
    List<String>? extensions,
    String? folderName,
    bool? enabled,
  }) {
    return OrganizeCategory(
      name: name ?? this.name,
      extensions: extensions ?? this.extensions,
      folderName: folderName ?? this.folderName,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'extensions': extensions,
    'folder_name': folderName,
    'enabled': enabled,
  };

  factory OrganizeCategory.fromJson(Map<String, dynamic> json) {
    return OrganizeCategory(
      name: json['name'] as String? ?? '',
      extensions: (json['extensions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      folderName: json['folder_name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// 自定义规则（文件名匹配）
class OrganizeCustomRule {
  final String name;
  final String matchPattern;
  final String targetFolder;
  final bool enabled;

  const OrganizeCustomRule({
    required this.name,
    required this.matchPattern,
    required this.targetFolder,
    this.enabled = true,
  });

  OrganizeCustomRule copyWith({
    String? name,
    String? matchPattern,
    String? targetFolder,
    bool? enabled,
  }) {
    return OrganizeCustomRule(
      name: name ?? this.name,
      matchPattern: matchPattern ?? this.matchPattern,
      targetFolder: targetFolder ?? this.targetFolder,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'match_pattern': matchPattern,
    'target_folder': targetFolder,
    'enabled': enabled,
  };

  factory OrganizeCustomRule.fromJson(Map<String, dynamic> json) {
    return OrganizeCustomRule(
      name: json['name'] as String? ?? '',
      matchPattern: json['match_pattern'] as String? ?? '',
      targetFolder: json['target_folder'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// 完整的自动归类配置
class OrganizeConfig {
  final String desktopPath;
  final String targetBasePath;
  final List<OrganizeCategory> categories;
  final List<OrganizeCustomRule> customRules;
  final List<String> ignorePatterns;
  final int scanIntervalSeconds;
  final bool watchRealtime;
  final int moveDelaySeconds;
  final bool enabled;

  const OrganizeConfig({
    this.desktopPath = '',
    this.targetBasePath = '',
    this.categories = const [],
    this.customRules = const [],
    this.ignorePatterns = const [],
    this.scanIntervalSeconds = 300,
    this.watchRealtime = true,
    this.moveDelaySeconds = 3,
    this.enabled = false,
  });

  OrganizeConfig copyWith({
    String? desktopPath,
    String? targetBasePath,
    List<OrganizeCategory>? categories,
    List<OrganizeCustomRule>? customRules,
    List<String>? ignorePatterns,
    int? scanIntervalSeconds,
    bool? watchRealtime,
    int? moveDelaySeconds,
    bool? enabled,
  }) {
    return OrganizeConfig(
      desktopPath: desktopPath ?? this.desktopPath,
      targetBasePath: targetBasePath ?? this.targetBasePath,
      categories: categories ?? this.categories,
      customRules: customRules ?? this.customRules,
      ignorePatterns: ignorePatterns ?? this.ignorePatterns,
      scanIntervalSeconds: scanIntervalSeconds ?? this.scanIntervalSeconds,
      watchRealtime: watchRealtime ?? this.watchRealtime,
      moveDelaySeconds: moveDelaySeconds ?? this.moveDelaySeconds,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'desktop_path': desktopPath,
    'target_base_path': targetBasePath,
    'categories': categories.map((c) => c.toJson()).toList(),
    'custom_rules': customRules.map((r) => r.toJson()).toList(),
    'ignore_patterns': ignorePatterns,
    'scan_interval_seconds': scanIntervalSeconds,
    'watch_realtime': watchRealtime,
    'move_delay_seconds': moveDelaySeconds,
    'enabled': enabled,
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory OrganizeConfig.fromJson(Map<String, dynamic> json) {
    return OrganizeConfig(
      desktopPath: json['desktop_path'] as String? ?? '',
      targetBasePath: json['target_base_path'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => OrganizeCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customRules: (json['custom_rules'] as List<dynamic>?)
              ?.map(
                  (e) => OrganizeCustomRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ignorePatterns: (json['ignore_patterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      scanIntervalSeconds: json['scan_interval_seconds'] as int? ?? 300,
      watchRealtime: json['watch_realtime'] as bool? ?? true,
      moveDelaySeconds: json['move_delay_seconds'] as int? ?? 3,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  factory OrganizeConfig.fromJsonString(String jsonStr) {
    return OrganizeConfig.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>);
  }

  /// 默认配置（8大分类）
  factory OrganizeConfig.defaultConfig() {
    return const OrganizeConfig(
      enabled: false,
      scanIntervalSeconds: 300,
      watchRealtime: true,
      moveDelaySeconds: 3,
      categories: [
        OrganizeCategory(
          name: '文档',
          extensions: [
            '.doc', '.docx', '.pdf', '.txt', '.xls', '.xlsx',
            '.ppt', '.pptx', '.md', '.csv', '.rtf',
          ],
          folderName: '文档',
        ),
        OrganizeCategory(
          name: '图片',
          extensions: [
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg',
            '.webp', '.ico', '.psd', '.raw', '.tiff',
          ],
          folderName: '图片',
        ),
        OrganizeCategory(
          name: '视频',
          extensions: [
            '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v',
          ],
          folderName: '视频',
        ),
        OrganizeCategory(
          name: '音乐',
          extensions: [
            '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a',
          ],
          folderName: '音乐',
        ),
        OrganizeCategory(
          name: '压缩包',
          extensions: ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz'],
          folderName: '压缩包',
        ),
        OrganizeCategory(
          name: '安装包',
          extensions: ['.exe', '.msi', '.dmg', '.deb', '.rpm', '.appx'],
          folderName: '安装包',
        ),
        OrganizeCategory(
          name: '代码',
          extensions: [
            '.py', '.js', '.ts', '.go', '.rs', '.java', '.c', '.cpp',
            '.h', '.cs', '.dart', '.html', '.css', '.json', '.yaml',
            '.yml', '.xml', '.sql',
          ],
          folderName: '代码',
        ),
        OrganizeCategory(
          name: '快捷方式',
          extensions: ['.lnk', '.url'],
          folderName: '快捷方式',
        ),
      ],
      customRules: [
        OrganizeCustomRule(
          name: '微信文件',
          matchPattern: 'WeChat*',
          targetFolder: '微信文件',
        ),
        OrganizeCustomRule(
          name: '截图',
          matchPattern: 'Screenshot*',
          targetFolder: '截图',
        ),
      ],
      ignorePatterns: ['desktop.ini', '*.tmp', '~\$*'],
    );
  }
}
