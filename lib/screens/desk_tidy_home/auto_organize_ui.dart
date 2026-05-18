part of '../desk_tidy_home_page.dart';

extension _AutoOrganizeUI on _DeskTidyHomePageState {
  void _showAutoOrganizeSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AutoOrganizeSettingsDialog(
        config: AutoOrganizeService.instance.config,
        onSave: (newConfig) async {
          await AutoOrganizeService.instance.updateConfig(newConfig);
          if (mounted) {
            _setState(() {
              _autoOrganizeEnabled = newConfig.enabled;
            });
          }
        },
      ),
    );
  }
}

class _AutoOrganizeSettingsDialog extends StatefulWidget {
  final OrganizeConfig config;
  final Future<void> Function(OrganizeConfig) onSave;

  const _AutoOrganizeSettingsDialog({
    required this.config,
    required this.onSave,
  });

  @override
  State<_AutoOrganizeSettingsDialog> createState() =>
      _AutoOrganizeSettingsDialogState();
}

class _AutoOrganizeSettingsDialogState
    extends State<_AutoOrganizeSettingsDialog> {
  late OrganizeConfig _config;
  bool _scanning = false;
  int _lastScanResult = 0;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_fix_high, size: 22),
          const SizedBox(width: 8),
          const Text('自动归类设置'),
          const Spacer(),
          if (_scanning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 扫描间隔
              _buildSliderTile(
                '扫描间隔',
                '${(_config.scanIntervalSeconds / 60).toInt()} 分钟',
                _config.scanIntervalSeconds.toDouble(),
                60,
                1800,
                30,
                (v) => setState(() {
                  _config = _config.copyWith(scanIntervalSeconds: v.toInt());
                }),
              ),
              // 延迟移动
              _buildSliderTile(
                '新文件延迟',
                '${_config.moveDelaySeconds} 秒',
                _config.moveDelaySeconds.toDouble(),
                1,
                10,
                9,
                (v) => setState(() {
                  _config = _config.copyWith(moveDelaySeconds: v.toInt());
                }),
              ),
              // 实时监控开关
              SwitchListTile(
                title: const Text('实时监控'),
                subtitle: const Text('监听桌面新文件事件'),
                value: _config.watchRealtime,
                onChanged: (v) => setState(() {
                  _config = _config.copyWith(watchRealtime: v);
                }),
              ),
              const Divider(),
              // 分类列表
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('分类规则',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              ..._config.categories.asMap().entries.map((entry) {
                final idx = entry.key;
                final cat = entry.value;
                return CheckboxListTile(
                  title: Text(cat.name),
                  subtitle: Text(
                    '${cat.folderName} · ${cat.extensions.take(5).join(", ")}${cat.extensions.length > 5 ? "..." : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: cat.enabled,
                  dense: true,
                  onChanged: (v) {
                    setState(() {
                      final updated = List<OrganizeCategory>.from(_config.categories);
                      updated[idx] = cat.copyWith(enabled: v ?? true);
                      _config = _config.copyWith(categories: updated);
                    });
                  },
                );
              }),
              const Divider(),
              // 自定义规则
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text('自定义规则',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加'),
                      onPressed: _addCustomRule,
                    ),
                  ],
                ),
              ),
              ..._config.customRules.asMap().entries.map((entry) {
                final idx = entry.key;
                final rule = entry.value;
                return ListTile(
                  dense: true,
                  title: Text(rule.name),
                  subtitle: Text('${rule.matchPattern} → ${rule.targetFolder}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.enabled,
                        onChanged: (v) {
                          setState(() {
                            final updated =
                                List<OrganizeCustomRule>.from(_config.customRules);
                            updated[idx] = rule.copyWith(enabled: v);
                            _config = _config.copyWith(customRules: updated);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () {
                          setState(() {
                            final updated =
                                List<OrganizeCustomRule>.from(_config.customRules);
                            updated.removeAt(idx);
                            _config = _config.copyWith(customRules: updated);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              // 手动扫描按钮
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_scanning
                      ? '扫描中...'
                      : '立即扫描${_lastScanResult > 0 ? " (上次移动$_lastScanResult个)" : ""}'),
                  onPressed: _scanning ? null : _runScan,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onSave(_config);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSliderTile(
    String title,
    String trailing,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
      trailing: Text(trailing),
    );
  }

  void _addCustomRule() {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    final folderController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                hintText: '如：微信文件',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: patternController,
              decoration: const InputDecoration(
                labelText: '匹配模式',
                hintText: '如：WeChat* 或 *.tmp',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: folderController,
              decoration: const InputDecoration(
                labelText: '目标文件夹',
                hintText: '如：微信文件',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  patternController.text.isNotEmpty &&
                  folderController.text.isNotEmpty) {
                setState(() {
                  final updated =
                      List<OrganizeCustomRule>.from(_config.customRules);
                  updated.add(OrganizeCustomRule(
                    name: nameController.text,
                    matchPattern: patternController.text,
                    targetFolder: folderController.text,
                  ));
                  _config = _config.copyWith(customRules: updated);
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _runScan() async {
    setState(() => _scanning = true);
    final result = await AutoOrganizeService.instance.runFullScan();
    if (mounted) {
      setState(() {
        _scanning = false;
        _lastScanResult = result;
      });
    }
  }
}
