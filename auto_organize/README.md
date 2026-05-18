# 🗂️ 桌面自动归类工具 (Auto Organize)

> 无感自动化 —— 按文件后缀将桌面文件物理移动到分类收纳盒文件夹

## ✨ 功能

| 功能 | 说明 |
|------|------|
| **实时监控** | FileSystemWatcher 监听桌面新文件，立即触发归类 |
| **定时扫描** | 每5分钟全量扫描桌面（兜底机制） |
| **后缀分类** | 8大内置分类：文档/图片/视频/音乐/压缩包/安装包/代码/快捷方式 |
| **自定义规则** | 支持文件名模式匹配（如 `WeChat*` → 微信文件） |
| **开机自启** | 注册为 Windows 计划任务，后台无窗口运行 |
| **安全移动** | 同名文件自动重命名，不覆盖 |
| **日志记录** | 完整操作日志，自动轮转 |

## 📦 文件结构

```
auto_organize/
├── AutoOrganize.ps1      # 主脚本（监控+扫描+移动）
├── Install-Service.ps1   # 安装/卸载为计划任务
├── config.json           # 分类规则配置
└── README.md             # 本文件
```

## 🚀 使用方法

### 1. 首次运行（测试）

```powershell
# 进入目录
cd auto_organize

# 试运行（DryRun模式，不实际移动）
.\AutoOrganize.ps1 -DryRun

# 单次扫描（不启动监控）
.\AutoOrganize.ps1 -OneShot
```

### 2. 正常运行

```powershell
# 前台运行（可看到日志输出）
.\AutoOrganize.ps1

# Ctrl+C 停止
```

### 3. 安装为后台服务（推荐）

```powershell
# 安装计划任务（开机自启）
.\Install-Service.ps1 -Action Install

# 立即启动
.\Install-Service.ps1 -Action Run

# 查看状态
.\Install-Service.ps1 -Action Status

# 停止
.\Install-Service.ps1 -Action Stop

# 卸载
.\Install-Service.ps1 -Action Uninstall
```

## ⚙️ 配置说明 (config.json)

### 基础配置

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `desktop_path` | 桌面路径（空=自动检测） | `""` |
| `target_base_path` | 分类文件夹创建位置（空=桌面） | `""` |
| `scan_interval_minutes` | 定时扫描间隔 | `5` |
| `watch_realtime` | 是否启用实时监控 | `true` |
| `move_delay_seconds` | 新文件延迟处理（等写入完成） | `3` |

### 添加自定义分类

在 `config.json` 的 `categories` 中添加：

```json
"我的分类": {
  "extensions": [".abc", ".xyz"],
  "folder_name": "📂 我的分类",
  "enabled": true
}
```

### 添加自定义规则（文件名匹配）

在 `custom_rules` 中添加：

```json
{
  "name": "规则名称",
  "match_pattern": "文件名模式*",
  "target_folder": "目标文件夹名",
  "enabled": true
}
```

支持通配符: `*`（任意字符）, `?`（单个字符）

## 🔄 与 desk_tidy 的协同

此工具独立运行，与 desk_tidy 主程序互补：

- **desk_tidy**: 虚拟分类展示 + 快捷启动（不移动文件）
- **auto_organize**: 物理移动文件到分类文件夹

建议 `target_base_path` 设为桌面，这样 desk_tidy 的收纳盒可以直接展示分类文件夹内容。

## ❓ FAQ

**Q: 会不会误移动正在编辑的文件？**
A: 新文件有3秒延迟处理；已存在的文件仅在定时扫描时处理。

**Q: 移动后找不到文件？**
A: 查看 `auto_organize.log` 日志文件，记录了所有移动操作。

**Q: 如何排除某些文件？**
A: 在 `config.json` 的 `ignore_patterns` 中添加模式。

**Q: 不需要 DropIt 吗？**
A: 不需要。本工具使用 Windows 原生 FileSystemWatcher + 计划任务，零依赖。
