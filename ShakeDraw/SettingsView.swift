import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var folderManager: FolderManager
    @State private var showImporter = false
    @State private var showSharedImagesManager = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 1.0
    // 体感跟随（视差）设置
    @AppStorage("parallaxEnabled") private var parallaxEnabled: Bool = true
    @AppStorage("parallaxStrength") private var parallaxStrength: Double = 0.85 // 0.0~1.0（默认推荐 85%）
    // 交互范围设置（拖拽与缩放）
    @AppStorage("panLimitFractionX") private var panLimitFractionX: Double = 0.20 // 水平比例 0.05~0.5（默认推荐 20%）
    @AppStorage("panLimitFractionY") private var panLimitFractionY: Double = 0.20 // 垂直比例 0.05~0.5（默认推荐 20%）
    @AppStorage("zoomMin") private var zoomMin: Double = 0.9
    @AppStorage("zoomMax") private var zoomMax: Double = 2.0
    // 动画与回弹参数设置
    @AppStorage("reboundSpeed") private var reboundSpeed: Double = 0.40   // 秒（默认推荐 0.40）
    @AppStorage("reboundDamping") private var reboundDamping: Double = 0.85 // 0~1（默认推荐 0.85）

    var body: some View {
        // 注意：外部（如 ContentView 的 sheet）会包裹 NavigationView，这里不再嵌套，避免导航栏高度异常。
        List {
            // 统计信息区域
            if !folderManager.folders.isEmpty {
                Section {
                    statisticsRow
                }
            }
            
            // 幻灯片设置区域
            slideshowSettingsSection

            // 体感跟随设置
            parallaxSettingsSection

            // 交互范围设置
            interactionRangeSection

            // 动画与回弹
            animationTuningSection
            
            // 文件夹列表
            if folderManager.folders.isEmpty {
                emptySection
            } else {
                foldersListSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("图片库设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                simpleAddButton
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                folderManager.addFolders(urls: urls)
            case .failure(let error):
                print("❌ 文件夹导入失败: \(error)")
            }
        }
        .onAppear { folderManager.refreshFolderCounts() }
        .sheet(isPresented: $showSharedImagesManager) {
            SharedImagesManagerView(folderManager: folderManager)
        }
    }
    
    // MARK: - 组件视图
    
    private var slideshowSettingsSection: some View {
        Section("幻灯片设置") {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播放间隔")
                            .font(.body)
                        Text("设置幻灯片自动切换的时间间隔（推荐 1.0 秒）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f 秒", slideshowInterval))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.blue.opacity(0.1))
                        )
                }
                
                HStack {
                    Text("0.5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $slideshowInterval, in: 0.5...5.0, step: 0.1) {
                        Text("播放间隔")
                    }
                    .accentColor(.blue)
                    
                    Text("5.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var parallaxSettingsSection: some View {
        Section("体感跟随") {
            VStack(spacing: 14) {
                Toggle(isOn: $parallaxEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "view.3d")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("随设备倾斜轻微视差")
                                .font(.body)
                            Text("不触发摇一摇，仅用于展示时的体感。尊重‘降低动态效果’设置。（推荐强度 85%）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Text("强度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .leading)

                    Slider(value: $parallaxStrength, in: 0...1, step: 0.05) {
                        Text("体感强度")
                    }
                    .disabled(!parallaxEnabled)
                    .tint(.green)

                    Text(String(format: "%.0f%%", parallaxStrength * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                .opacity(parallaxEnabled ? 1 : 0.4)
            }
            .padding(.vertical, 6)
        }
    }

    private var interactionRangeSection: some View {
        Section("交互范围") {
            VStack(spacing: 16) {
                // 水平拖拽幅度
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("水平拖拽幅度")
                        Text("限制水平方向可拖动的最大距离，占屏幕宽度比例（推荐 20%）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", panLimitFractionX * 100))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.purple.opacity(0.12)))
                }
                HStack {
                    Text("5%").font(.caption).foregroundColor(.secondary)
                    Slider(value: $panLimitFractionX, in: 0.05...0.5, step: 0.01) { Text("水平拖拽幅度") }
                        .tint(.purple)
                    Text("50%").font(.caption).foregroundColor(.secondary)
                }

                // 垂直拖拽幅度
                HStack {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.indigo)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("垂直拖拽幅度")
                        Text("限制垂直方向可拖动的最大距离，占屏幕高度比例（推荐 20%）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", panLimitFractionY * 100))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.indigo.opacity(0.12)))
                }
                HStack {
                    Text("5%").font(.caption).foregroundColor(.secondary)
                    Slider(value: $panLimitFractionY, in: 0.05...0.5, step: 0.01) { Text("垂直拖拽幅度") }
                        .tint(.indigo)
                    Text("50%").font(.caption).foregroundColor(.secondary)
                }

                Divider()

                // 缩放范围
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.teal)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("缩放范围")
                        Text("双指缩放时的最小/最大倍率（手指松开将回弹至原始大小，推荐最小 ×0.9、最大 ×2.0）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("最小")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                    Slider(value: $zoomMin, in: 0.5...1.0, step: 0.05) { Text("最小缩放") }
                        .tint(.teal)
                    Text(String(format: "×%.2f", zoomMin))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Text("最大")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                    Slider(value: $zoomMax, in: 1.0...3.0, step: 0.1) { Text("最大缩放") }
                        .tint(.teal)
                    Text(String(format: "×%.1f", zoomMax))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .padding(.vertical, 6)
            .onChange(of: zoomMin) { _, newMin in
                if newMin >= zoomMax { zoomMax = min(3.0, newMin + 0.1) }
            }
            .onChange(of: zoomMax) { _, newMax in
                if newMax <= zoomMin { zoomMin = max(0.5, newMax - 0.1) }
            }
        }
    }

    private var animationTuningSection: some View {
        Section("动画与回弹") {
            VStack(spacing: 14) {
                // 回弹速度
                HStack {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("回弹速度")
                        Text("越小越快（响应时间，单位秒，推荐 0.40s）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2fs", reboundSpeed))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.orange.opacity(0.12)))
                }
                HStack {
                    Text("快").font(.caption).foregroundColor(.secondary)
                    Slider(value: $reboundSpeed, in: 0.1...0.6, step: 0.01) { Text("回弹速度") }
                        .tint(.orange)
                    Text("慢").font(.caption).foregroundColor(.secondary)
                }

                // 回弹幅度
                HStack {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.pink)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("回弹幅度")
                        Text("越大越干净（阻尼，1为无过冲，推荐 0.85）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f", reboundDamping))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.pink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.pink.opacity(0.12)))
                }
                HStack {
                    Text("小").font(.caption).foregroundColor(.secondary)
                    Slider(value: $reboundDamping, in: 0.5...1.0, step: 0.01) { Text("回弹幅度") }
                        .tint(.pink)
                    Text("大").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private var statisticsRow: some View {
        HStack(spacing: 0) {
            compactStatisticCard(
                icon: "folder.fill",
                title: "文件夹",
                value: "\(folderManager.folders.count)",
                color: .blue
            )
            
            compactStatisticCard(
                icon: "photo.fill",
                title: "总图片",
                value: "\(totalImageCount)",
                color: .green
            )
            
            compactStatisticCard(
                icon: "checkmark.circle.fill",
                title: "参与抽签",
                value: "\(activeImageCount)",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func compactStatisticCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 12) {
            // 图标背景圆圈
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 数值
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            
            // 标题
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statisticColumn(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptySection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("还没有添加图片文件夹")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    private var foldersListSection: some View {
        Section("图片文件夹") {
            // 共享图片文件夹
            ForEach(folderManager.folders.filter { $0.isAppGroup == true }) { folder in
                sharedFolderRow(folder)
            }
            
            // 普通文件夹
            ForEach(folderManager.folders.filter { ($0.isAppGroup ?? false) == false }) { folder in
                folderRow(folder)
            }
            .onDelete { indexSet in
                // 只能删除非共享文件夹
                let nonSharedFolders = folderManager.folders.filter { ($0.isAppGroup ?? false) == false }
                let idsToDelete = indexSet.map { nonSharedFolders[$0].id }
                
                for id in idsToDelete {
                    folderManager.removeFolder(id: id)
                }
            }
        }
    }
    
    private func sharedFolderRow(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack {
            Image(systemName: folder.includeInDraw ? "icloud.and.arrow.down.fill" : "icloud.and.arrow.down")
                .font(.title3)
                .foregroundColor(folder.includeInDraw ? .blue : .secondary)
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.2), value: folder.includeInDraw)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName ?? "共享图片")
                    .font(.body)
                
                if let count = folderManager.folderCounts[folder.id] {
                    Text("\(count) 张图片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: includeBinding(for: folder.id))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showSharedImagesManager = true
        }
    }
    
    private func folderRow(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack {
            Image(systemName: folder.includeInDraw ? "folder.fill" : "folder")
                .font(.title3)
                .foregroundColor(folder.includeInDraw ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.2), value: folder.includeInDraw)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName ?? URL(fileURLWithPath: folder.lastResolvedPath).lastPathComponent)
                    .font(.body)
                
                if let count = folderManager.folderCounts[folder.id] {
                    Text("\(count) 张图片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: includeBinding(for: folder.id))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
        }
    }
    
    private var simpleAddButton: some View {
        Button("添加") {
            showImporter = true
        }
    }
    
    private var compactHeaderCard: some View {
        HStack(spacing: 24) {
            statisticItem(
                icon: "folder.fill",
                title: "文件夹",
                value: "\(folderManager.folders.count)",
                color: .blue
            )
            
            Divider()
                .frame(height: 50)
            
            statisticItem(
                icon: "photo.fill",
                title: "总图片",
                value: "\(totalImageCount)",
                color: .green
            )
            
            Divider()
                .frame(height: 50)
            
            statisticItem(
                icon: "checkmark.circle.fill",
                title: "参与抽签",
                value: "\(activeImageCount)",
                color: .orange
            )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ShakeDraw")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("管理您的图片文件夹")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !folderManager.folders.isEmpty {
                Divider()
                
                HStack {
                    statisticItem(
                        icon: "folder.fill",
                        title: "文件夹",
                        value: "\(folderManager.folders.count)",
                        color: .blue
                    )
                    
                    Spacer()
                    
                    statisticItem(
                        icon: "photo.fill",
                        title: "总图片",
                        value: "\(totalImageCount)",
                        color: .green
                    )
                    
                    Spacer()
                    
                    statisticItem(
                        icon: "checkmark.circle.fill",
                        title: "参与抽签",
                        value: "\(activeImageCount)",
                        color: .orange
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
    
    private func statisticItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("图片文件夹")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if folderManager.folders.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 10) {
                    // 共享图片文件夹
                    ForEach(folderManager.folders.filter { $0.isAppGroup == true }) { folder in
                        sharedFolderCard(folder)
                    }
                    
                    // 普通文件夹
                    ForEach(folderManager.folders.filter { ($0.isAppGroup ?? false) == false }) { folder in
                        folderCard(folder)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            Text("还没有添加图片文件夹")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private func sharedFolderCard(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.displayName ?? "共享图片")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 12) {
                    if let count = folderManager.folderCounts[folder.id] {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 11))
                            Text("\(count) 张")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    statusBadge(isActive: folder.includeInDraw)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // 开关居中
            VStack {
                Toggle("", isOn: includeBinding(for: folder.id))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        )
        .onTapGesture {
            showSharedImagesManager = true
        }
        .contextMenu {
            Button {
                showSharedImagesManager = true
            } label: {
                Label("管理共享图片", systemImage: "photo.on.rectangle.angled")
            }
            
            Button(role: .destructive) {
                folderManager.clearAppGroupImages()
            } label: {
                Label("清空共享图片", systemImage: "trash")
            }
        }
    }
    
    private func folderCard(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(folder.includeInDraw ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: folder.includeInDraw ? "folder.fill" : "folder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(folder.includeInDraw ? .blue : .secondary)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.displayName ?? URL(fileURLWithPath: folder.lastResolvedPath).lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let count = folderManager.folderCounts[folder.id] {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 11))
                            Text("\(count) 张")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    statusBadge(isActive: folder.includeInDraw)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // 开关居中
            VStack {
                Toggle("", isOn: includeBinding(for: folder.id))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                if let index = folderManager.folders.firstIndex(where: { $0.id == folder.id }) {
                    folderManager.removeFolders(at: IndexSet(integer: index))
                }
            } label: {
                Label("删除文件夹", systemImage: "trash")
            }
        }
    }
    
    private func statusBadge(isActive: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "slash.circle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isActive ? "参与" : "排除")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(isActive ? .green : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isActive ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                folderManager.clearAllFolders()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空本地文件夹")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("仅移除本地文件夹访问配置，保留共享图片")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
    }
    
    private var addButton: some View {
        Button(action: { showImporter = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("添加")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
    }
    
    // MARK: - 计算属性
    
    private var totalImageCount: Int {
        folderManager.folderCounts.values.reduce(0, +)
    }
    
    private var activeImageCount: Int {
        folderManager.folders
            .filter { $0.includeInDraw }
            .compactMap { folderManager.folderCounts[$0.id] }
            .reduce(0, +)
    }
    
    private var hasNonSharedFolders: Bool {
        folderManager.folders.contains { folder in
            folder.isAppGroup != true
        }
    }

    private func includeBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                folderManager.folders.first(where: { $0.id == id })?.includeInDraw ?? false
            },
            set: { newValue in
                folderManager.updateInclude(id: id, include: newValue)
            }
        )
    }
}

#Preview {
    SettingsView(folderManager: FolderManager())
}
