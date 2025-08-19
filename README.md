# 🎲 ShakeDraw - 晃动抽签

一款简洁优雅的iOS随机抽签应用，通过摇动手机或点击按钮从图片文件夹中随机选择图片。

![iOS Version](https://img.shields.io/badge/iOS-18.0+-blue.svg)
![Swift Version](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ 特色功能

### 🎯 核心功能
- **智能抽签**：从图片文件夹中随机选择图片
- **防重复机制**：确保连续抽签不会重复当前图片
- **多种触发方式**：支持摇一摇手机或点击按钮
- **记忆功能**：自动记住上次抽签结果和选择的文件夹

### 🎨 界面设计
- **苹果设计风格**：完全遵循 Apple Human Interface Guidelines
- **精美加载动画**：多层次旋转动画，具有苹果设计风味
- **夜间模式适配**：完美支持系统深色/浅色模式切换
- **响应式布局**：优化竖屏图片显示，智能调整图片尺寸

### 🔧 高级功能
- **文件管理**：支持从文件导入和清除数据
- **敏感摇动检测**：优化的重力感应，提高触发灵敏度
- **缓存机制**：预加载和缓存图片，提供流畅体验
- **安全访问**：使用安全范围资源访问，保护用户隐私

## 📱 系统要求

- iOS 18.0+
- Xcode 15.0+
- Swift 5.0+

## 🚀 快速开始

### 安装运行

1. 克隆项目到本地
```bash
git clone https://github.com/leorxx11/ShakeDraw.git
cd ShakeDraw
```

2. 使用 Xcode 打开项目
```bash
open ShakeDraw.xcodeproj
```

3. 选择目标设备或模拟器，点击运行

### 使用方法

1. **导入图片**：点击右上角 ➕ 按钮，选择包含图片的文件夹
2. **开始抽签**：摇动手机或点击"开始抽签"按钮
3. **享受结果**：查看随机选中的图片，可点击"再次抽签"继续

## 🏗️ 项目架构

### 核心组件
```
ShakeDraw/
├── ContentView.swift          # 主界面视图
├── FolderManager.swift        # 文件夹管理器
├── ImageLoader.swift          # 图片加载器
├── RandomDrawManager.swift    # 抽签管理器
├── ShakeDetector.swift        # 摇一摇检测器
└── ShakeDrawApp.swift        # 应用入口
```

### 主要功能模块

- **FolderManager**: 处理文件夹选择、权限管理和书签保存
- **ImageLoader**: 负责图片加载、缓存和格式支持
- **RandomDrawManager**: 管理抽签逻辑、状态和结果缓存
- **ShakeDetector**: 检测设备摇动并触发抽签
- **ContentView**: 主界面，整合所有组件和用户交互

## 🎨 设计亮点

### 用户体验
- **直观的欢迎界面**：清晰的使用步骤指引
- **流畅的动画过渡**：精心设计的加载和结果展示动画
- **智能图片显示**：针对竖屏图片优化显示尺寸
- **优雅的错误处理**：友好的错误提示和恢复机制

### 技术特色
- **防重复算法**：智能排除当前图片，提供更好的随机体验
- **多线程优化**：后台加载图片，确保UI流畅性
- **内存管理**：高效的图片预解码和缓存策略
- **数据持久化**：使用UserDefaults和文件缓存保存状态

## 📝 更新日志

### v1.0.0 (2025-08-19)
- ✨ 初版发布
- 🎨 苹果风格UI设计
- 🎯 防重复抽签机制
- 🔧 完整的文件管理功能
- 📱 夜间模式适配
- 🎭 精美的加载动画

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发规范
- 遵循 Swift API 设计准则
- 保持代码简洁和注释完整
- 确保与现有架构兼容
- 添加适当的错误处理

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 👨‍💻 作者

**Leo Zhao** - *Initial work* - [leorxx11](https://github.com/leorxx11)

---

⭐ 如果这个项目对你有帮助，请给个 Star！

📧 有问题或建议？欢迎 [提交 Issue](https://github.com/leorxx11/ShakeDraw/issues)