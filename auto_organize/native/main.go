package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/fsnotify/fsnotify"
)

// ═══════════════════════════════════════════════════════════════
// 配置结构
// ═══════════════════════════════════════════════════════════════

type Config struct {
	DesktopPath         string              `json:"desktop_path"`
	TargetBasePath      string              `json:"target_base_path"`
	Categories          map[string]Category `json:"categories"`
	CustomRules         []CustomRule        `json:"custom_rules"`
	IgnorePatterns      []string            `json:"ignore_patterns"`
	ScanIntervalMinutes int                 `json:"scan_interval_minutes"`
	WatchRealtime       bool                `json:"watch_realtime"`
	MoveDelaySeconds    int                 `json:"move_delay_seconds"`
}

type Category struct {
	Extensions []string `json:"extensions"`
	FolderName string   `json:"folder_name"`
	Enabled    bool     `json:"enabled"`
}

type CustomRule struct {
	Name         string `json:"name"`
	MatchPattern string `json:"match_pattern"`
	TargetFolder string `json:"target_folder"`
	Enabled      bool   `json:"enabled"`
}

// ═══════════════════════════════════════════════════════════════
// 全局变量
// ═══════════════════════════════════════════════════════════════

var (
	config     Config
	configPath string
	logFile    *os.File
	logger     *log.Logger
)

func main() {
	fmt.Println("═══════════════════════════════════════════")
	fmt.Println("  桌面自动归类工具 v1.0.0")
	fmt.Println("═══════════════════════════════════════════")

	// 确定配置文件路径（与 exe 同目录）
	exePath, err := os.Executable()
	if err != nil {
		log.Fatalf("无法获取程序路径: %v", err)
	}
	exeDir := filepath.Dir(exePath)
	configPath = filepath.Join(exeDir, "config.json")

	// 初始化日志
	initLogger(exeDir)
	defer logFile.Close()

	// 加载配置
	if err := loadConfig(); err != nil {
		logger.Fatalf("加载配置失败: %v", err)
	}

	// 解析桌面路径
	desktopPath := resolveDesktopPath()
	logger.Printf("桌面路径: %s", desktopPath)
	logger.Printf("目标基础路径: %s", resolveTargetBase(desktopPath))

	// 首次全量扫描
	logger.Println("执行首次全量扫描...")
	fullScan(desktopPath)

	// 启动实时监控
	if config.WatchRealtime {
		go startWatcher(desktopPath)
		logger.Println("实时监控已启动")
	}

	// 启动定时扫描
	scanInterval := time.Duration(config.ScanIntervalMinutes) * time.Minute
	ticker := time.NewTicker(scanInterval)
	defer ticker.Stop()
	logger.Printf("定时扫描间隔: %d 分钟", config.ScanIntervalMinutes)

	// 等待退出信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	fmt.Println("\n服务运行中... (Ctrl+C 退出)")
	for {
		select {
		case <-ticker.C:
			logger.Println("执行定时扫描...")
			fullScan(desktopPath)
		case sig := <-sigChan:
			logger.Printf("收到退出信号: %v", sig)
			fmt.Println("\n正在退出...")
			return
		}
	}
}

// ═══════════════════════════════════════════════════════════════
// 日志
// ═══════════════════════════════════════════════════════════════

func initLogger(dir string) {
	logPath := filepath.Join(dir, "auto_organize.log")
	var err error
	logFile, err = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Fatalf("无法创建日志文件: %v", err)
	}

	// 同时输出到控制台和文件
	multiWriter := io.MultiWriter(os.Stdout, logFile)
	logger = log.New(multiWriter, "[AutoOrganize] ", log.LstdFlags)
}

// ═══════════════════════════════════════════════════════════════
// 配置加载
// ═══════════════════════════════════════════════════════════════

func loadConfig() error {
	data, err := os.ReadFile(configPath)
	if err != nil {
		// 配置不存在，创建默认
		logger.Println("配置文件不存在，创建默认配置...")
		config = defaultConfig()
		return saveConfig()
	}

	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("解析配置失败: %w", err)
	}

	// 设置默认值
	if config.ScanIntervalMinutes <= 0 {
		config.ScanIntervalMinutes = 5
	}
	if config.MoveDelaySeconds <= 0 {
		config.MoveDelaySeconds = 3
	}

	logger.Printf("已加载配置: %d 个分类, %d 条自定义规则",
		len(config.Categories), len(config.CustomRules))
	return nil
}

func saveConfig() error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configPath, data, 0644)
}

func defaultConfig() Config {
	return Config{
		DesktopPath:    "",
		TargetBasePath: "",
		Categories: map[string]Category{
			"文档": {
				Extensions: []string{".doc", ".docx", ".pdf", ".txt", ".xls", ".xlsx", ".ppt", ".pptx", ".md", ".csv", ".rtf"},
				FolderName: "📄 文档",
				Enabled:    true,
			},
			"图片": {
				Extensions: []string{".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".webp", ".ico", ".psd", ".raw", ".tiff"},
				FolderName: "🖼️ 图片",
				Enabled:    true,
			},
			"视频": {
				Extensions: []string{".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v"},
				FolderName: "🎬 视频",
				Enabled:    true,
			},
			"音乐": {
				Extensions: []string{".mp3", ".wav", ".flac", ".aac", ".ogg", ".wma", ".m4a"},
				FolderName: "🎵 音乐",
				Enabled:    true,
			},
			"压缩包": {
				Extensions: []string{".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz"},
				FolderName: "📦 压缩包",
				Enabled:    true,
			},
			"安装包": {
				Extensions: []string{".exe", ".msi", ".dmg", ".deb", ".rpm", ".appx"},
				FolderName: "💿 安装包",
				Enabled:    true,
			},
			"代码": {
				Extensions: []string{".py", ".js", ".ts", ".go", ".rs", ".java", ".c", ".cpp", ".h", ".cs", ".dart", ".html", ".css", ".json", ".yaml", ".yml", ".xml", ".sql"},
				FolderName: "💻 代码",
				Enabled:    true,
			},
			"快捷方式": {
				Extensions: []string{".lnk", ".url"},
				FolderName: "🔗 快捷方式",
				Enabled:    true,
			},
		},
		CustomRules: []CustomRule{
			{Name: "微信文件", MatchPattern: "WeChat*", TargetFolder: "📱 微信文件", Enabled: true},
			{Name: "截图", MatchPattern: "Screenshot*", TargetFolder: "📸 截图", Enabled: true},
		},
		IgnorePatterns:      []string{"desktop.ini", "*.tmp", "~$*"},
		ScanIntervalMinutes: 5,
		WatchRealtime:       true,
		MoveDelaySeconds:    3,
	}
}

// ═══════════════════════════════════════════════════════════════
// 路径解析
// ═══════════════════════════════════════════════════════════════

func resolveDesktopPath() string {
	if config.DesktopPath != "" {
		return config.DesktopPath
	}
	// Windows 桌面路径
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Desktop")
}

func resolveTargetBase(desktopPath string) string {
	if config.TargetBasePath != "" {
		return config.TargetBasePath
	}
	return desktopPath
}

// ═══════════════════════════════════════════════════════════════
// 文件匹配
// ═══════════════════════════════════════════════════════════════

func shouldIgnore(name string) bool {
	for _, pattern := range config.IgnorePatterns {
		matched, _ := filepath.Match(strings.ToLower(pattern), strings.ToLower(name))
		if matched {
			return true
		}
	}
	return false
}

func getTargetFolder(fileName string) string {
	// 1. 先检查自定义规则（优先级更高）
	for _, rule := range config.CustomRules {
		if !rule.Enabled {
			continue
		}
		matched, _ := filepath.Match(strings.ToLower(rule.MatchPattern), strings.ToLower(fileName))
		if matched {
			return rule.TargetFolder
		}
	}

	// 2. 按后缀匹配分类
	ext := strings.ToLower(filepath.Ext(fileName))
	if ext == "" {
		return ""
	}

	for _, cat := range config.Categories {
		if !cat.Enabled {
			continue
		}
		for _, e := range cat.Extensions {
			if strings.ToLower(e) == ext {
				return cat.FolderName
			}
		}
	}

	return ""
}

// ═══════════════════════════════════════════════════════════════
// 文件移动
// ═══════════════════════════════════════════════════════════════

func moveFile(srcPath, desktopPath string) {
	fileName := filepath.Base(srcPath)

	// 检查忽略
	if shouldIgnore(fileName) {
		return
	}

	// 获取目标文件夹
	targetFolder := getTargetFolder(fileName)
	if targetFolder == "" {
		return
	}

	// 创建目标目录
	targetBase := resolveTargetBase(desktopPath)
	targetDir := filepath.Join(targetBase, targetFolder)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		logger.Printf("创建目录失败 [%s]: %v", targetDir, err)
		return
	}

	// 目标路径
	destPath := filepath.Join(targetDir, fileName)

	// 处理同名文件
	destPath = resolveConflict(destPath)

	// 检查源文件是否在目标文件夹内（避免循环移动）
	srcAbs, _ := filepath.Abs(srcPath)
	targetDirAbs, _ := filepath.Abs(targetDir)
	if strings.HasPrefix(srcAbs, targetDirAbs+string(filepath.Separator)) {
		return
	}

	// 执行移动
	if err := os.Rename(srcPath, destPath); err != nil {
		// Rename 跨分区失败时，用 copy + delete
		if err := copyAndDelete(srcPath, destPath); err != nil {
			logger.Printf("移动失败 [%s → %s]: %v", fileName, targetFolder, err)
			return
		}
	}

	logger.Printf("✓ 移动: %s → %s/", fileName, targetFolder)
}

func resolveConflict(path string) string {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return path
	}

	dir := filepath.Dir(path)
	ext := filepath.Ext(path)
	name := strings.TrimSuffix(filepath.Base(path), ext)

	for i := 1; i < 1000; i++ {
		newPath := filepath.Join(dir, fmt.Sprintf("%s_%d%s", name, i, ext))
		if _, err := os.Stat(newPath); os.IsNotExist(err) {
			return newPath
		}
	}
	return path
}

func copyAndDelete(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	if _, err := io.Copy(dstFile, srcFile); err != nil {
		os.Remove(dst)
		return err
	}

	srcFile.Close()
	return os.Remove(src)
}

// ═══════════════════════════════════════════════════════════════
// 全量扫描
// ═══════════════════════════════════════════════════════════════

func fullScan(desktopPath string) {
	entries, err := os.ReadDir(desktopPath)
	if err != nil {
		logger.Printf("扫描桌面失败: %v", err)
		return
	}

	moved := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		filePath := filepath.Join(desktopPath, entry.Name())
		targetFolder := getTargetFolder(entry.Name())
		if targetFolder != "" && !shouldIgnore(entry.Name()) {
			moveFile(filePath, desktopPath)
			moved++
		}
	}

	if moved > 0 {
		logger.Printf("扫描完成: 移动了 %d 个文件", moved)
	} else {
		logger.Println("扫描完成: 桌面整洁 ✓")
	}
}

// ═══════════════════════════════════════════════════════════════
// 实时监控
// ═══════════════════════════════════════════════════════════════

func startWatcher(desktopPath string) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		logger.Printf("创建文件监控失败: %v", err)
		return
	}
	defer watcher.Close()

	if err := watcher.Add(desktopPath); err != nil {
		logger.Printf("监控桌面目录失败: %v", err)
		return
	}

	delay := time.Duration(config.MoveDelaySeconds) * time.Second

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			// 只处理新建和重命名
			if event.Has(fsnotify.Create) || event.Has(fsnotify.Rename) {
				// 延迟处理（等文件写入完成）
				go func(path string) {
					time.Sleep(delay)
					// 确认文件仍然存在
					if _, err := os.Stat(path); err == nil {
						moveFile(path, desktopPath)
					}
				}(event.Name)
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			logger.Printf("监控错误: %v", err)
		}
	}
}
