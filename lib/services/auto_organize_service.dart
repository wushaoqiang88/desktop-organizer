import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/organize_config.dart';
import '../utils/app_logger.dart';

/// 桌面文件自动归类服务
///
/// 功能:
/// - 实时监控桌面目录，新文件按后缀自动移动到分类文件夹
/// - 定时全量扫描兜底
/// - 自定义规则支持文件名模式匹配
class AutoOrganizeService {
  AutoOrganizeService._();
  static final instance = AutoOrganizeService._();

  static const _configKey = 'auto_organize_config';

  OrganizeConfig _config = const OrganizeConfig();
  OrganizeConfig get config => _config;

  Timer? _scanTimer;
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  bool _running = false;
  bool get isRunning => _running;

  /// 最近移动的文件记录（用于UI展示）
  final List<OrganizeMoveRecord> recentMoves = [];
  static const _maxRecentMoves = 50;

  /// 状态变更通知
  void Function()? onStateChanged;

  // ═══════════════════════════════════════════════════════════════
  // 生命周期
  // ═══════════════════════════════════════════════════════════════

  /// 初始化：从 SharedPreferences 加载配置
  Future<void> init() async {
    await _loadConfig();
    if (_config.enabled) {
      start();
    }
  }

  /// 启动服务
  void start() {
    if (_running) return;
    _running = true;
    _config = _config.copyWith(enabled: true);
    _saveConfig();

    AppLogger.info('AutoOrganize started');
    _startWatcher();
    _startPeriodicScan();
    onStateChanged?.call();
  }

  /// 停止服务
  void stop() {
    if (!_running) return;
    _running = false;
    _config = _config.copyWith(enabled: false);
    _saveConfig();

    _stopWatcher();
    _scanTimer?.cancel();
    _scanTimer = null;
    AppLogger.info('AutoOrganize stopped');
    onStateChanged?.call();
  }

  /// 更新配置
  Future<void> updateConfig(OrganizeConfig newConfig) async {
    final wasRunning = _running;
    if (wasRunning) {
      _stopWatcher();
      _scanTimer?.cancel();
      _scanTimer = null;
    }

    _config = newConfig;
    await _saveConfig();

    if (wasRunning && newConfig.enabled) {
      _startWatcher();
      _startPeriodicScan();
    }
    onStateChanged?.call();
  }

  /// 手动触发一次全量扫描
  Future<int> runFullScan() async {
    return await _fullScan();
  }

  // ═══════════════════════════════════════════════════════════════
  // 配置持久化
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _config = OrganizeConfig.fromJsonString(jsonStr);
      } else {
        _config = OrganizeConfig.defaultConfig();
        await _saveConfig();
      }
    } catch (e) {
      AppLogger.error('AutoOrganize loadConfig failed', error: e);
      _config = OrganizeConfig.defaultConfig();
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, _config.toJsonString());
    } catch (e) {
      AppLogger.error('AutoOrganize saveConfig failed', error: e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 文件监控
  // ═══════════════════════════════════════════════════════════════

  void _startWatcher() {
    if (!_config.watchRealtime) return;

    final desktopPath = _resolveDesktopPath();
    final dir = Directory(desktopPath);
    if (!dir.existsSync()) return;

    _watchSubscription = dir.watch(events: FileSystemEvent.create).listen(
      (event) {
        if (event is FileSystemCreateEvent && !event.isDirectory) {
          // 延迟处理，等文件写入完成
          Future.delayed(
            Duration(seconds: _config.moveDelaySeconds),
            () => _processFile(event.path, desktopPath),
          );
        }
      },
      onError: (e) {
        AppLogger.error('AutoOrganize watcher error', error: e);
      },
    );
  }

  void _stopWatcher() {
    _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 定时扫描
  // ═══════════════════════════════════════════════════════════════

  void _startPeriodicScan() {
    _scanTimer?.cancel();
    final interval = Duration(seconds: _config.scanIntervalSeconds);
    _scanTimer = Timer.periodic(interval, (_) => _fullScan());
  }

  Future<int> _fullScan() async {
    final desktopPath = _resolveDesktopPath();
    final dir = Directory(desktopPath);
    if (!dir.existsSync()) return 0;

    int moved = 0;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final didMove = await _processFile(entity.path, desktopPath);
          if (didMove) moved++;
        }
      }
    } catch (e) {
      AppLogger.error('AutoOrganize fullScan error', error: e);
    }

    if (moved > 0) {
      AppLogger.info('AutoOrganize scan: moved $moved files');
    }
    return moved;
  }

  // ═══════════════════════════════════════════════════════════════
  // 文件处理
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _processFile(String filePath, String desktopPath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final fileName = path.basename(filePath);

      // 检查忽略列表
      if (_shouldIgnore(fileName)) return false;

      // 确定目标文件夹
      final targetFolder = _getTargetFolder(fileName);
      if (targetFolder == null || targetFolder.isEmpty) return false;

      // 目标目录
      final targetBase = _config.targetBasePath.isNotEmpty
          ? _config.targetBasePath
          : desktopPath;
      final targetDir = path.join(targetBase, targetFolder);

      // 检查是否已在目标目录中
      final srcDir = path.dirname(filePath);
      if (path.equals(srcDir, targetDir)) return false;

      // 创建目标目录
      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // 处理文件名冲突
      var destPath = path.join(targetDir, fileName);
      destPath = _resolveConflict(destPath);

      // 移动文件
      await file.rename(destPath);

      // 记录
      final record = OrganizeMoveRecord(
        fileName: fileName,
        targetFolder: targetFolder,
        timestamp: DateTime.now(),
      );
      recentMoves.insert(0, record);
      if (recentMoves.length > _maxRecentMoves) {
        recentMoves.removeRange(_maxRecentMoves, recentMoves.length);
      }
      onStateChanged?.call();

      AppLogger.info('AutoOrganize moved: $fileName → $targetFolder/');
      return true;
    } catch (e) {
      // rename 跨盘符时会失败，用 copy + delete
      try {
        final file = File(filePath);
        if (!file.existsSync()) return false;

        final fileName = path.basename(filePath);
        final targetFolder = _getTargetFolder(fileName);
        if (targetFolder == null) return false;

        final targetBase = _config.targetBasePath.isNotEmpty
            ? _config.targetBasePath
            : desktopPath;
        final targetDir = path.join(targetBase, targetFolder);
        final dir = Directory(targetDir);
        if (!dir.existsSync()) dir.createSync(recursive: true);

        var destPath = path.join(targetDir, fileName);
        destPath = _resolveConflict(destPath);

        await file.copy(destPath);
        await file.delete();

        final record = OrganizeMoveRecord(
          fileName: fileName,
          targetFolder: targetFolder,
          timestamp: DateTime.now(),
        );
        recentMoves.insert(0, record);
        if (recentMoves.length > _maxRecentMoves) {
          recentMoves.removeRange(_maxRecentMoves, recentMoves.length);
        }
        onStateChanged?.call();
        return true;
      } catch (e2) {
        AppLogger.error('AutoOrganize move failed: $filePath', error: e2);
        return false;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 匹配逻辑
  // ═══════════════════════════════════════════════════════════════

  bool _shouldIgnore(String fileName) {
    final lower = fileName.toLowerCase();
    for (final pattern in _config.ignorePatterns) {
      if (_matchWildcard(pattern.toLowerCase(), lower)) {
        return true;
      }
    }
    return false;
  }

  String? _getTargetFolder(String fileName) {
    final lower = fileName.toLowerCase();

    // 1. 先匹配自定义规则（优先级高）
    for (final rule in _config.customRules) {
      if (!rule.enabled) continue;
      if (_matchWildcard(rule.matchPattern.toLowerCase(), lower)) {
        return rule.targetFolder;
      }
    }

    // 2. 按后缀匹配分类
    final ext = path.extension(fileName).toLowerCase();
    if (ext.isEmpty) return null;

    for (final category in _config.categories) {
      if (!category.enabled) continue;
      for (final catExt in category.extensions) {
        if (catExt.toLowerCase() == ext) {
          return category.folderName;
        }
      }
    }

    return null;
  }

  /// 简单通配符匹配（支持 * 和 ?）
  bool _matchWildcard(String pattern, String text) {
    // 转换为正则
    final escaped = RegExp.escape(pattern);
    final regexStr = '^${escaped.replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
    try {
      return RegExp(regexStr, caseSensitive: false).hasMatch(text);
    } catch (_) {
      return false;
    }
  }

  String _resolveConflict(String filePath) {
    if (!File(filePath).existsSync()) return filePath;

    final dir = path.dirname(filePath);
    final ext = path.extension(filePath);
    final name = path.basenameWithoutExtension(filePath);

    for (var i = 1; i < 1000; i++) {
      final newPath = path.join(dir, '${name}_$i$ext');
      if (!File(newPath).existsSync()) return newPath;
    }
    return filePath;
  }

  String _resolveDesktopPath() {
    if (_config.desktopPath.isNotEmpty) return _config.desktopPath;
    // 使用环境变量获取桌面路径
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isNotEmpty) {
      return path.join(userProfile, 'Desktop');
    }
    return r'C:\Users\Public\Desktop';
  }
}

/// 文件移动记录
class OrganizeMoveRecord {
  final String fileName;
  final String targetFolder;
  final DateTime timestamp;

  const OrganizeMoveRecord({
    required this.fileName,
    required this.targetFolder,
    required this.timestamp,
  });
}
