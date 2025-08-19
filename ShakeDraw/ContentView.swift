//
//  ContentView.swift
//  ShakeDraw
//
//  Created by 赵粒宇 on 2025/8/19.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var folderManager = FolderManager()
    @StateObject private var imageLoader = ImageLoader()
    @StateObject private var shakeDetector = ShakeDetector()
    @StateObject private var drawManager = RandomDrawManager()
    @State private var isShaking = false
    // 保留最近结果用于背景，即便 currentImage 暂时被置空
    @State private var backgroundImage: UIImage?
    
    var body: some View {
        NavigationView {
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
                
                // 左上角图片数量标签
                if folderManager.hasPermission && !imageLoader.images.isEmpty {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.stack.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(imageLoader.images.count)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.regularMaterial)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
                
                // 右上角菜单按钮 - 始终显示
                VStack {
                    HStack {
                        Spacer()
                        
                        Menu {
                            Button(action: {
                                folderManager.selectFolder()
                            }) {
                                Label("从文件导入", systemImage: "folder.badge.plus")
                            }
                            
                            if folderManager.hasPermission {
                                Button(role: .destructive, action: {
                                    // 清除所有数据
                                    drawManager.clearAllData()
                                    imageLoader.images.removeAll()
                                    folderManager.clearFolder()
                                    // 确保返回欢迎界面时不再保留上次背景
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        backgroundImage = nil
                                    }
                                }) {
                                    Label("清除", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: folderManager.hasPermission ? "ellipsis.circle" : "plus.circle")
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

                // 左下角常驻抽签按钮（仅在已授权且有图片时显示）
                if folderManager.hasPermission && !imageLoader.images.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                drawManager.setDependencies(imageLoader: imageLoader, folderManager: folderManager)
                // 在任何权限判断之前，优先展示缓存预览（若存在）
                drawManager.showCachedPreviewIfAny()
                // 初始化背景图
                backgroundImage = drawManager.currentImage
                
                shakeDetector.setShakeCallback {
                    if folderManager.hasPermission && !imageLoader.images.isEmpty {
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
            .onChange(of: folderManager.selectedFolderURL) { _, _ in
                // 文件夹URL发生变化时重新加载图片
                loadImagesIfNeeded()
            }
            .onChange(of: drawManager.currentImage) { _, newImage in
                if let img = newImage {
                    backgroundImage = img
                }
            }
            .onChange(of: folderManager.hasPermission) { _, hasPermission in
                // 失去权限（回到欢迎界面）时，清空背景以避免残留
                if hasPermission == false {
                    withAnimation(.easeOut(duration: 0.2)) {
                        backgroundImage = nil
                    }
                }
            }
        }
    }
    
    private func loadImagesIfNeeded() {
        guard folderManager.hasPermission, let folderURL = folderManager.selectedFolderURL else {
            return
        }
        
        // 统一通过 Manager 的恢复接口处理，避免重复逻辑
        drawManager.startRestoreIfNeeded()
        imageLoader.loadImages(from: folderURL)
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
                        Text("点击右上角导入图片文件夹")
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
                    
                    Button("重新选择文件夹") {
                        folderManager.selectFolder()
                    }
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
                        print("🖥️ 显示结果图片界面（交叉淡入）")
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
    
    // 计算图片显示尺寸，针对竖屏图片优化
    private var imageDisplaySize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // 判断是否为竖屏图片
        let isPortrait = aspectRatio < 1.0
        
        if isPortrait {
            // 竖屏图片：允许更高的显示高度，占用更多屏幕空间
            let maxHeight = screenSize.height * 0.65 // 从300提升到屏幕高度的65%
            let maxWidth = screenSize.width * 0.85
            
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        } else {
            // 横屏图片：维持原有逻辑
            let maxHeight: CGFloat = 300
            let maxWidth = screenSize.width * 0.9
            
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

// 静态图片卡片（统一样式，无入场弹跳），用于交叉淡入容器
struct ResultImageCard: View {
    let image: UIImage

    private var imageDisplaySize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let isPortrait = aspectRatio < 1.0
        if isPortrait {
            let maxHeight = screenSize.height * 0.65
            let maxWidth = screenSize.width * 0.85
            let heightBasedWidth = maxHeight * aspectRatio
            let widthBasedHeight = maxWidth / aspectRatio
            if heightBasedWidth <= maxWidth {
                return CGSize(width: heightBasedWidth, height: maxHeight)
            } else {
                return CGSize(width: maxWidth, height: widthBasedHeight)
            }
        } else {
            let maxHeight: CGFloat = 300
            let maxWidth = screenSize.width * 0.9
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

    var body: some View {
        ZStack {
            if let back = backImage {
                ResultImageCard(image: back)
                    .opacity(showFront ? 0 : 1)
                    .animation(.easeInOut(duration: 0.28), value: showFront)
            }
            if let front = frontImage {
                ResultImageCard(image: front)
                    .opacity(showFront ? 1 : 0)
                    .scaleEffect(showFront ? 1.0 : 0.985)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showFront)
            }
        }
        .onAppear {
            // 初次显示
            frontImage = image
            backImage = nil
            showFront = true
        }
        .onChange(of: image) { _, new in
            // 切换到新图：先把当前front放到背后，再把新图放在前面，触发淡入
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
