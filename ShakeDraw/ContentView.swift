//
//  ContentView.swift
//  ShakeDraw
//
//  Created by 赵粒宇 on 2025/8/19.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var folderManager = FolderManager()
    @StateObject private var imageLoader = ImageLoader()
    @StateObject private var shakeDetector = ShakeDetector()
    @StateObject private var drawManager = RandomDrawManager()
    @State private var isShaking = false
    // 保留最近结果用于背景，即便 currentImage 暂时被置空
    @State private var backgroundImage: UIImage?
    @State private var showSettings = false
    @State private var isSlideshow = false
    @State private var slideshowTimer: Timer?
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 1.0
    // Share (imperative presentation to avoid first-time blank issue)
    @State private var isPresentingShare = false
    
    var body: some View {
        let mainContent = NavigationView {
            ZStack {
                // 高斯模糊背景：使用最近结果图片作为背景
                if let bg = backgroundImage {
                    BlurredBackgroundView(image: bg, blurRadius: 24)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
                VStack(spacing: 20) {
                    if !folderManager.hasPermission {
                        setupView
                    } else {
                        mainView
                    }
                }
                .padding()
                
                // 左上角图片数量按钮 - 点击开始/停止幻灯片
                if folderManager.hasPermission && !imageLoader.images.isEmpty {
                    VStack {
                        HStack {
                            Button(action: toggleSlideshow) {
                                HStack(spacing: 6) {
                                    Image(systemName: isSlideshow ? "play.slash.fill" : "photo.stack.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("\(imageLoader.images.count)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(isSlideshow ? .orange : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.regularMaterial)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .scaleEffect(isSlideshow ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isSlideshow)
                            }
                            .disabled(drawManager.isDrawing || drawManager.isRestoring)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
                
                // 右上角设置按钮 - 始终显示
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(.regularMaterial)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .sheet(isPresented: $showSettings, onDismiss: {
                    // 返回时刷新图片列表，但不自动还原上次图片（避免误触发缓存显示）
                    loadImagesIfNeeded(suppressAutoRestore: true)
                }) {
                    SettingsView(folderManager: folderManager)
                }

                // 左下角抽签 + 右下角分享（仅在已授权且有图片目录时显示）
                if folderManager.hasPermission && !imageLoader.images.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            // 抽签按钮（左下）
                            Button(action: {
                                guard !drawManager.isDrawing, !drawManager.isRestoring else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                drawManager.performRandomDraw() // 立即开始，避免空闲闪屏
                            }) {
                                Image(systemName: "die.face.5.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(.regularMaterial)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .disabled(drawManager.isDrawing || drawManager.isRestoring)

                            Spacer()

                            // 分享按钮（右下）
                            Button(action: {
                                guard let image = drawManager.currentImage else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                presentShareSheet(items: [image])
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(drawManager.currentImage == nil ? .secondary : .primary)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(.regularMaterial)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .disabled(drawManager.currentImage == nil)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                drawManager.setDependencies(imageLoader: imageLoader, folderManager: folderManager)
                
                // 只有在有权限的情况下才显示缓存
                if folderManager.hasPermission {
                    drawManager.showCachedPreviewIfAny()
                    // 初始化背景图
                    backgroundImage = drawManager.currentImage
                }
                
                shakeDetector.setShakeCallback {
                    if folderManager.hasPermission && !imageLoader.images.isEmpty {
                        // 触发强烈的触感反馈，提示已检测到摇动
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.prepare()
                        generator.impactOccurred()
                        
                        // 添加额外的强烈震动
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }

                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShaking = true
                        }
                        drawManager.performRandomDraw()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShaking = false
                        }
                    }
                }
                
                loadImagesIfNeeded()
            }
            .onChange(of: folderManager.folders) { _, _ in
                // 文件夹列表变化时重新加载图片
                loadImagesIfNeeded(suppressAutoRestore: true)
            }
            .onChange(of: showSettings) { _, isShown in
                // 设置页打开时禁用摇一摇，避免触发导致导航栈重建
                shakeDetector.isEnabled = !isShown
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    AppLog.d("🐞 场景切回前台：刷新收藏目录计数与图片池")
                    folderManager.refreshFolderCounts()
                    loadImagesIfNeeded(suppressAutoRestore: true)
                }
            }
            .onChange(of: drawManager.currentImage) { _, newImage in
                if let img = newImage {
                    backgroundImage = img
                }
            }
            .onChange(of: folderManager.hasPermission) { _, hasPermission in
                // 任何权限状态切换，都先回到"摇一摇"初始态（不展示上次图片）
                withAnimation(.easeOut(duration: 0.2)) { backgroundImage = nil }
                drawManager.resetDraw()
                stopSlideshow() // 停止幻灯片
                
                if hasPermission {
                    // 重新获得权限时，仅重新加载图片池，不触发自动还原
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        loadImagesIfNeeded(suppressAutoRestore: true)
                    }
                }
            }
            .onDisappear {
                stopSlideshow() // 视图消失时停止幻灯片
            }
            .onChange(of: slideshowInterval) { _, newInterval in
                // 如果幻灯片正在运行，重启以应用新的间隔时间
                if isSlideshow {
                    stopSlideshow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startSlideshow()
                    }
                    AppLog.d("🔄 幻灯片间隔更新为: \(newInterval)秒")
                }
            }
        }
        return mainContent
    }

    // MARK: - Share Sheet
    private func presentShareSheet(items: [Any]) {
        DispatchQueue.main.async {
            if isPresentingShare { return }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let window = scenes
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow }) else { return }

            guard let top = topViewController(from: window.rootViewController) else { return }

            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            // Avoid customizing detents to prevent SharingUIService crash on iOS 18 simulator.
            // The system defaults to a half-sheet on iPhone.
            if #available(iOS 16.0, *), let sheet = vc.sheetPresentationController {
                sheet.prefersGrabberVisible = true
            }
            if let pop = vc.popoverPresentationController {
                pop.sourceView = window
                pop.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.maxY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            vc.completionWithItemsHandler = { _, _, _, _ in
                DispatchQueue.main.async { isPresentingShare = false }
            }
            isPresentingShare = true
            top.present(vc, animated: true, completion: nil)
        }
    }

    private func topViewController(from root: UIViewController?) -> UIViewController? {
        guard let root = root else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController {
            return nav.visibleViewController ?? nav
        }
        if let tab = top as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return top
    }
    
    private func getCachedImagePath() -> String? {
        return UserDefaults.standard.string(forKey: "ShakeDraw_LastResultRelativePath")
    }
    
    private func loadImagesIfNeeded(suppressAutoRestore: Bool = false) {
        guard folderManager.hasPermission else {
            return
        }
        
        let folderInfo = folderManager.includedFolderInfo()
        guard !folderInfo.isEmpty else { return }
        // 统一通过 Manager 的恢复接口处理，避免重复逻辑
        if !suppressAutoRestore {
            drawManager.startRestoreIfNeeded()
        }
        imageLoader.loadImages(from: folderInfo)
    }
    
    private func toggleSlideshow() {
        guard folderManager.hasPermission && !imageLoader.images.isEmpty else { return }
        
        if isSlideshow {
            stopSlideshow()
        } else {
            startSlideshow()
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func startSlideshow() {
        isSlideshow = true
        
        // 立即开始第一次抽签
        drawManager.performRandomDraw()
        
        // 设置定时器，使用用户配置的间隔时间
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: slideshowInterval, repeats: true) { _ in
            guard isSlideshow && folderManager.hasPermission && !imageLoader.images.isEmpty else {
                stopSlideshow()
                return
            }
            
            // 只有在不是正在抽签状态时才继续下一轮
            if !drawManager.isDrawing && !drawManager.isRestoring {
                drawManager.performRandomDraw()
            }
        }
        
        AppLog.d("🎬 幻灯片模式已开始，间隔: \(slideshowInterval)秒")
    }
    
    private func stopSlideshow() {
        isSlideshow = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
        
        AppLog.d("🛑 幻灯片模式已停止")
    }
    
    private var setupView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 20) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))
                
                VStack(spacing: 8) {
                    Text("欢迎使用晃动抽签")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("让随机选择更有趣")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 20) {
                VStack(spacing: 15) {
                    HStack(spacing: 15) {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("点击右上角设置导入图片文件夹")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 15) {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("摇动手机或点左下角按钮抽签")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 15) {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("享受随机选择的乐趣")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 15)
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 30) {
            if imageLoader.isLoading {
                ProgressView("加载图片中...")
                    .font(.title3)
            } else if imageLoader.images.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("文件夹中没有找到图片")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Button("打开设置") { showSettings = true }
                    .foregroundColor(.blue)
                }
            } else {
                drawingArea
            }
            
            if !imageLoader.images.isEmpty {
                statusView
            }
        }
    }
    
    private var drawingArea: some View {
        ZStack {
            // Idle 提示（底层）
            if !drawManager.isDrawing && !drawManager.showResult && !drawManager.isRestoring {
                VStack(spacing: 12) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(isShaking ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isShaking)
                    Text("摇一摇手机开始抽签")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("左下角按钮也可")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
            }

            // 结果（中层）
            if drawManager.showResult, let image = drawManager.currentImage {
                CrossfadeResultView(image: image)
                    .onAppear {
                        #if DEBUG
                        AppLog.d("🖥️ 显示结果图片界面（交叉淡入）")
                        #endif
                    }
            }

            // 按需求移除“抽签中”字样与动画覆盖层
        }
    }
    
    private var statusView: some View {
        VStack { EmptyView() }
    }
}


// 苹果风格加载动画：多层次视觉元素组合
struct LoadingAnimationView: View {
    @State private var rotate = false
    @State private var innerRotate = false
    @State private var scale = 1.0
    @State private var opacity = 0.0
    @State private var dotsRotation = 0.0
    @State private var breathe = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // 外层背景圆环
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                // 中层脉动圆环
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                    .scaleEffect(breathe ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)
                
                // 主旋转弧形
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.1),
                                Color.blue.opacity(0.8),
                                Color.blue
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotate)
                
                // 内层反向旋转弧形
                Circle()
                    .trim(from: 0.2, to: 0.5)
                    .stroke(
                        Color.blue.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(innerRotate ? -360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: innerRotate)
                
                // 中心点缀小圆点
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: 3, height: 3)
                        .offset(x: 12)
                        .rotationEffect(.degrees(Double(index) * 120 + dotsRotation))
                }
                .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: dotsRotation)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 1.0
                    opacity = 1.0
                }
                rotate = true
                innerRotate = true
                breathe = true
                dotsRotation = 360
            }
            
            // 文字标签
            VStack(spacing: 6) {
                Text("抽签中")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .scaleEffect(breathe ? (index % 2 == 0 ? 1.2 : 0.8) : (index % 2 == 0 ? 0.8 : 1.2))
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: breathe
                            )
                    }
                }
            }
            .opacity(opacity * 0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ResultImageView: View {
    let image: UIImage
    @State private var scale = 0.9
    @State private var opacity = 0.0
    @State private var bounceScale = 1.0
    // 可配置：竖屏/横屏图片的最大高度占屏幕百分比
    @AppStorage("portraitMaxHeightFraction") private var portraitMaxHeightFraction: Double = 0.70
    @AppStorage("landscapeMaxHeightFraction") private var landscapeMaxHeightFraction: Double = 0.40
    
    // 计算图片显示尺寸，针对竖屏图片优化
    private var imageDisplaySize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // 判断是否为竖屏图片
        let isPortrait = aspectRatio < 1.0
        
        if isPortrait {
            // 竖屏图片：允许更高的显示高度，占用更多屏幕空间
            let maxHeight = screenSize.height * portraitMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        } else {
            // 横屏图片：增大显示尺寸
            let maxHeight = screenSize.height * landscapeMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        }
    }
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
            .id(ObjectIdentifier(image)) // 强制视图在替换缩略图->原图时完全重建，避免蒙版丢失
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .compositingGroup() // 确保裁剪与后续效果一致应用
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .scaleEffect(scale * bounceScale)
            .opacity(opacity)
            .onAppear {
                // 快速、干净的弹出
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    scale = 1.0
                    opacity = 1.0
                }
                // 轻微二段回弹
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bounceScale = 1.02 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) { bounceScale = 1.0 }
                    }
                }
                // 触感
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }
}

// 支持缩放和拖拽的图片卡片
struct ZoomableImageCard: View {
    let image: UIImage
    let scale: CGFloat
    let offset: CGSize
    let magnifyBy: CGFloat
    let dragOffset: CGSize
    // 可配置：竖屏/横屏图片的最大高度占屏幕百分比
    @AppStorage("portraitMaxHeightFraction") private var portraitMaxHeightFraction: Double = 0.70
    @AppStorage("landscapeMaxHeightFraction") private var landscapeMaxHeightFraction: Double = 0.40

    private var imageDisplaySize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let isPortrait = aspectRatio < 1.0
        if isPortrait {
            let maxHeight = screenSize.height * portraitMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        } else {
            let maxHeight = screenSize.height * landscapeMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .scaleEffect(scale * magnifyBy)
            .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
    }
}

// 静态图片卡片（统一样式，无入场弹跳），用于交叉淡入容器
struct ResultImageCard: View {
    let image: UIImage
    // 可配置：竖屏/横屏图片的最大高度占屏幕百分比
    @AppStorage("portraitMaxHeightFraction") private var portraitMaxHeightFraction: Double = 0.70
    @AppStorage("landscapeMaxHeightFraction") private var landscapeMaxHeightFraction: Double = 0.40

    private var imageDisplaySize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let isPortrait = aspectRatio < 1.0
        if isPortrait {
            let maxHeight = screenSize.height * portraitMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        } else {
            let maxHeight = screenSize.height * landscapeMaxHeightFraction
            let maxWidth = screenSize.width * 0.92
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
    }
}

// 两张图片之间的交叉淡入过渡容器
struct CrossfadeResultView: View {
    let image: UIImage
    @State private var backImage: UIImage?
    @State private var frontImage: UIImage?
    @State private var showFront = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var magnifyBy = 1.0
    @GestureState private var dragOffset = CGSize.zero

    // 体感跟随（视差）
    @StateObject private var parallax = MotionParallaxManager()
    @AppStorage("parallaxEnabled") private var parallaxEnabled: Bool = true
    @AppStorage("parallaxStrength") private var parallaxStrength: Double = 0.85 // 0.0~1.0（默认推荐 85%）
    // 交互范围设置（拖拽与缩放）
    @AppStorage("panLimitFractionX") private var panLimitFractionX: Double = 0.20 // 水平相对屏幕比例（默认推荐 20%）
    @AppStorage("panLimitFractionY") private var panLimitFractionY: Double = 0.20 // 垂直相对屏幕比例（默认推荐 20%）
    @AppStorage("zoomMin") private var zoomMin: Double = 0.9
    @AppStorage("zoomMax") private var zoomMax: Double = 2.0
    // 回弹参数（用户可在设置中自定义）：速度与幅度
    @AppStorage("reboundSpeed") private var reboundSpeed: Double = 0.40   // 响应时间（s），越小越快，建议 0.1~0.6（默认推荐 0.40）
    @AppStorage("reboundDamping") private var reboundDamping: Double = 0.85 // 阻尼（0~1），越大越干净（默认推荐 0.85）
    // 拖拽边界触达去抖（椭圆边界）：到边单次触感
    @State private var didHitEdge = false
    @State private var didHitZoomMin = false
    @State private var didHitZoomMax = false

    // 基于设置生成统一回弹动画
    private var reboundAnimation: Animation {
        let resp = max(0.1, min(0.6, reboundSpeed))
        let damp = max(0.6, min(1.0, reboundDamping))
        return .spring(response: resp, dampingFraction: damp)
    }

    private var isInteracting: Bool {
        (abs(magnifyBy - 1.0) > 0.001) || (abs(dragOffset.width) > 0.5) || (abs(dragOffset.height) > 0.5)
    }

    private var tiltOffset: CGSize {
        guard parallaxEnabled, !UIAccessibility.isReduceMotionEnabled, !isInteracting else { return .zero }
        let hMax = 12.0 * parallaxStrength
        let vMax = 8.0 * parallaxStrength
        return CGSize(width: CGFloat(parallax.normX * hMax), height: CGFloat(parallax.normY * vMax))
    }

    private var tiltAngles: (x: Double, y: Double) {
        guard parallaxEnabled, !UIAccessibility.isReduceMotionEnabled, !isInteracting else { return (0, 0) }
        let maxAngle = 6.0 * parallaxStrength
        let rollNorm = max(-1.0, min(1.0, parallax.rollDeg / 45.0))
        let pitchNorm = max(-1.0, min(1.0, parallax.pitchDeg / 45.0))
        let xDeg = -pitchNorm * maxAngle
        let yDeg = -rollNorm * maxAngle
        return (xDeg, yDeg)
    }

    var body: some View {
        ZStack {
            if let back = backImage {
                ZoomableImageCard(image: back, scale: scale, offset: offset, magnifyBy: magnifyBy, dragOffset: dragOffset)
                    .offset(tiltOffset)
                    .rotation3DEffect(.degrees(tiltAngles.x), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(tiltAngles.y), axis: (x: 0, y: 1, z: 0))
                    .opacity(showFront ? 0 : 1)
                    .animation(.easeInOut(duration: 0.28), value: showFront)
                    // 当手势结束、GestureState 复位时，使用弹簧回弹动画
                    .animation(reboundAnimation, value: magnifyBy)
                    .animation(reboundAnimation, value: dragOffset)
            }
            if let front = frontImage {
                ZoomableImageCard(image: front, scale: scale, offset: offset, magnifyBy: magnifyBy, dragOffset: dragOffset)
                    .offset(tiltOffset)
                    .rotation3DEffect(.degrees(tiltAngles.x), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(tiltAngles.y), axis: (x: 0, y: 1, z: 0))
                    .opacity(showFront ? 1 : 0)
                    .scaleEffect(showFront ? 1.0 : 0.985)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showFront)
                    // 当手势结束、GestureState 复位时，使用弹簧回弹动画
                    .animation(reboundAnimation, value: magnifyBy)
                    .animation(reboundAnimation, value: dragOffset)
            }
        }
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .updating($magnifyBy) { currentState, gestureState, _ in
                        // 规范缩放范围
                        let minZ = max(0.5, zoomMin)
                        let maxZ = min(3.0, max(zoomMax, minZ + 0.05))
                        let eff = min(max(currentState, minZ), maxZ)
                        gestureState = eff
                    }
                    .onChanged { value in
                        // 触达缩放边界时触发一次触觉反馈
                        let minZ = max(0.5, zoomMin)
                        let maxZ = min(3.0, max(zoomMax, minZ + 0.05))
                        let eff = min(max(value, minZ), maxZ)
                        if eff <= minZ {
                            if !didHitZoomMin {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                didHitZoomMin = true
                            }
                        } else {
                            didHitZoomMin = false
                        }
                        if eff >= maxZ {
                            if !didHitZoomMax {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                didHitZoomMax = true
                            }
                        } else {
                            didHitZoomMax = false
                        }
                    },
                DragGesture()
                    .updating($dragOffset) { currentState, gestureState, _ in
                        // 椭圆边界夹取：半轴 a/b 基于屏幕与系数
                        let screen = UIScreen.main.bounds.size
                        let a = max(1, CGFloat(screen.width * panLimitFractionX))   // 水平半轴
                        let b = max(1, CGFloat(screen.height * panLimitFractionY))  // 垂直半轴
                        let t = currentState.translation
                        let dx = t.width
                        let dy = t.height
                        // r^2 = (dx/a)^2 + (dy/b)^2
                        let r2 = (dx*dx)/(a*a) + (dy*dy)/(b*b)
                        if r2 <= 1 {
                            gestureState = CGSize(width: dx, height: dy)
                        } else {
                            let r = CGFloat(sqrt(Double(r2)))
                            let s = 1 / max(0.0001, r)
                            gestureState = CGSize(width: dx * s, height: dy * s)
                        }
                    }
                    .onChanged { value in
                        // 靠近/触达边界时以固定节奏连续触发触觉反馈，营造“阻尼”感
                        let screen = UIScreen.main.bounds.size
                        let a = max(1, CGFloat(screen.width * panLimitFractionX))
                        let b = max(1, CGFloat(screen.height * panLimitFractionY))
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let r = sqrt((dx*dx)/(a*a) + (dy*dy)/(b*b))

                        // 椭圆边界：到边时单次触感；回到安全区再允许下次触发
                        let hitThreshold: CGFloat = 1.0   // 达边界
                        let resetThreshold: CGFloat = 0.92 // 回到安全区
                        if !didHitEdge && r >= hitThreshold {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            didHitEdge = true
                        } else if didHitEdge && r < resetThreshold {
                            didHitEdge = false
                        }
                    }
            )
        )
        .onAppear {
            // 初次显示
            frontImage = image
            backImage = nil
            showFront = true
            if parallaxEnabled && !UIAccessibility.isReduceMotionEnabled { parallax.start() }
        }
        .onChange(of: image) { _, new in
            // 切换到新图：先把当前front放到背后，再把新图放在前面，触发淡入
            // 保持当前的缩放和位置状态
            backImage = frontImage
            frontImage = new
            showFront = false
            // 下一帧开始淡入
            DispatchQueue.main.async {
                withAnimation { showFront = true }
                // 动画完成后释放背面图，节省内存
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if showFront { backImage = nil }
                }
            }
        }
        .onChange(of: parallaxEnabled) { _, enabled in
            if enabled && !UIAccessibility.isReduceMotionEnabled {
                parallax.start()
            } else {
                parallax.stop()
            }
        }
        .onDisappear {
            parallax.stop()
        }
    }
}

// 模糊背景视图
struct BlurredBackgroundView: View {
    let image: UIImage
    var blurRadius: CGFloat = 20
    
    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .blur(radius: blurRadius, opaque: true)
                .saturation(0.9)
                .overlay(Color.black.opacity(0.08))
        }
    }
}

// 透明胶囊按钮按压样式：轻微缩放 + 强调色淡叠加
struct PressableTranslucentCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .overlay(
                Capsule()
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.28 : 0.12))
            )
            .brightness(configuration.isPressed ? -0.05 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
