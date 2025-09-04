import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var folderManager: FolderManager
    @State private var showSharedImagesManager = false
    @State private var navPath = NavigationPath()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack(path: $navPath) {
            // 主菜单仅保留两个子入口：奖池、系数
            List {
                Section {
                    Button {
                        navPath.append(SettingsRoute.pool)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("奖池")
                                    .font(.body)
                                Text("管理图片来源与参与抽签的文件夹")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Button {
                        navPath.append(SettingsRoute.coefficients)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("系数")
                                    .font(.body)
                                Text("体感、展示比例、拖拽/缩放、回弹与播放间隔")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { dismiss() } } }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .pool:
                    PoolSettingsView(folderManager: folderManager, showSharedImagesManager: $showSharedImagesManager)
                case .coefficients:
                    CoefficientsSettingsView()
                }
            }
        }
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
    
    // 已移除未使用的顶部统计视图与卡片组件
    
    // 已移除未使用的 statisticColumn 组件
    
    // 已移除未使用的 emptySection（顶层）
    
    // 已移除未使用的 foldersListSection（顶层）
    
    // 已移除未使用的 sharedFolderRow（顶层）
    
    // 已移除未使用的 folderRow（顶层）
    
    // 已移除未使用的 simpleAddButton
    
    // 已移除未使用的 compactHeaderCard 组件
    
    // 已移除未使用的 headerCard 组件
    
    // 已移除未使用的 statisticItem 组件
    
    // 已移除未使用的 foldersSection 组件
    
    // 已移除未使用的 emptyStateView 组件
    
    // 已移除未使用的 sharedFolderCard 组件
    
    // 已移除未使用的 folderCard 组件
    
    // 已移除未使用的 statusBadge 组件
    
    // 已移除未使用的 actionsSection 组件
    
    // 已移除未使用的 addButton 组件
    
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

// MARK: - Navigation Route
private enum SettingsRoute: Hashable {
    case pool
    case coefficients
}

// 子菜单：奖池（管理图片来源与参与抽签的文件夹）
struct PoolSettingsView: View {
    @ObservedObject var folderManager: FolderManager
    @Binding var showSharedImagesManager: Bool

    var body: some View {
        List {
            if !folderManager.folders.isEmpty {
                Section { statisticsRow }
            }
            if folderManager.folders.isEmpty { emptySection } else { foldersListSection }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("奖池")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("添加") { folderManager.selectFolders() } } }
        .onAppear { folderManager.refreshFolderCounts() }
        // “收藏”弹窗由上层 SettingsView 管理，避免本视图重建时状态被重置
    }

    // MARK: - Section & Rows
    private var statisticsRow: some View {
        HStack(spacing: 0) {
            compactStatisticCard(icon: "folder.fill", title: "文件夹", value: "\(folderManager.folders.count)", color: .blue)
            compactStatisticCard(icon: "photo.fill", title: "总图片", value: "\(totalImageCount)", color: .green)
            compactStatisticCard(icon: "checkmark.circle.fill", title: "参与抽签", value: "\(activeImageCount)", color: .orange)
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
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: icon).font(.system(size: 24, weight: .semibold)).foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus").font(.system(size: 48)).foregroundColor(.secondary)
                Text("还没有添加图片文件夹").font(.headline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private var foldersListSection: some View {
        Section("图片文件夹") {
            ForEach(folderManager.folders.filter { $0.isAppGroup == true }) { folder in
                sharedFolderRow(folder)
            }
            ForEach(folderManager.folders.filter { ($0.isAppGroup ?? false) == false }) { folder in
                folderRow(folder)
            }
            .onDelete { indexSet in
                let nonSharedFolders = folderManager.folders.filter { ($0.isAppGroup ?? false) == false }
                let idsToDelete = indexSet.map { nonSharedFolders[$0].id }
                for id in idsToDelete { folderManager.removeFolder(id: id) }
            }
        }
    }

    private func sharedFolderRow(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack {
            Image(systemName: folder.includeInDraw ? "star.fill" : "star")
                .font(.title3)
                .foregroundColor(folder.includeInDraw ? .blue : .secondary)
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.2), value: folder.includeInDraw)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName ?? "收藏").font(.body)
                if let count = folderManager.folderCounts[folder.id] {
                    Text("\(count) 张图片").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: includeBinding(for: folder.id))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { showSharedImagesManager = true }
    }

    private func folderRow(_ folder: FolderManager.ManagedFolder) -> some View {
        HStack {
            Image(systemName: folder.includeInDraw ? "folder.fill" : "folder")
                .font(.title3)
                .foregroundColor(folder.includeInDraw ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.2), value: folder.includeInDraw)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName ?? URL(fileURLWithPath: folder.lastResolvedPath).lastPathComponent).font(.body)
                if let count = folderManager.folderCounts[folder.id] {
                    Text("\(count) 张图片").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: includeBinding(for: folder.id))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
        }
    }

    // MARK: - Helpers
    private var totalImageCount: Int { folderManager.folderCounts.values.reduce(0, +) }
    private var activeImageCount: Int {
        folderManager.folders.filter { $0.includeInDraw }.compactMap { folderManager.folderCounts[$0.id] }.reduce(0, +)
    }
    private func includeBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { folderManager.folders.first(where: { $0.id == id })?.includeInDraw ?? false },
            set: { folderManager.updateInclude(id: id, include: $0) }
        )
    }
}

// 子菜单：系数（体感、拖拽/缩放、回弹、播放间隔）
struct CoefficientsSettingsView: View {
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 1.0
    @AppStorage("parallaxEnabled") private var parallaxEnabled: Bool = true
    @AppStorage("parallaxStrength") private var parallaxStrength: Double = 0.85
    @AppStorage("panLimitFractionX") private var panLimitFractionX: Double = 0.20
    @AppStorage("panLimitFractionY") private var panLimitFractionY: Double = 0.20
    @AppStorage("zoomMin") private var zoomMin: Double = 0.9
    @AppStorage("zoomMax") private var zoomMax: Double = 2.0
    @AppStorage("reboundSpeed") private var reboundSpeed: Double = 0.40
    @AppStorage("reboundDamping") private var reboundDamping: Double = 0.85
    // 图片展示比例：竖图/横图最大高度相对屏幕高度
    @AppStorage("portraitMaxHeightFraction") private var portraitMaxHeightFraction: Double = 0.70
    @AppStorage("landscapeMaxHeightFraction") private var landscapeMaxHeightFraction: Double = 0.40

    @State private var showResetConfirm = false

    var body: some View {
        List {
            radarOverviewSection
            slideshowSettingsSection
            parallaxSettingsSection
            displayRatioSection
            interactionRangeSection
            animationTuningSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("系数")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("重置为推荐默认值？", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("重置", role: .destructive) { resetToDefaults() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅重置系数、展示比例与播放间隔，不影响‘奖池’设置。")
        }
    }

    // 顶部雷达统计图
    private var radarOverviewSection: some View {
        Section("系数总览") {
            VStack(spacing: 12) {
                RadarChartView(
                    values: radarValues.map { $0.value },
                    labels: radarValues.map { $0.label },
                    referenceValues: defaultRadarNormalizedValues,
                    levels: 4,
                    valueColor: .blue,
                    referenceColor: .gray
                )
                .frame(height: 220)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 10) {
                        legendItem(color: .gray, text: "默认")
                        legendItem(color: .blue, text: "当前")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(2)
                }
            }
        }
    }

    // 计算雷达值（0~1 归一化）
    private var radarValues: [(label: String, value: Double)] {
        let clamp: (Double, Double, Double) -> Double = { v, lo, hi in max(0.0, min(1.0, (v - lo) / (hi - lo))) }
        return [
            ("体感", parallaxEnabled ? parallaxStrength : 0.0),
            ("竖图占屏", clamp(portraitMaxHeightFraction, 0.5, 0.9)),
            ("横图占屏", clamp(landscapeMaxHeightFraction, 0.2, 0.7)),
            ("拖拽X", clamp(panLimitFractionX, 0.05, 0.5)),
            ("拖拽Y", clamp(panLimitFractionY, 0.05, 0.5)),
            ("缩放最小", clamp(zoomMin, 0.5, 1.0)),
            ("缩放最大", clamp(zoomMax, 1.0, 3.0)),
            ("回弹快度", max(0.0, min(1.0, (0.6 - reboundSpeed) / (0.6 - 0.1)))),
            ("回弹幅度", clamp(reboundDamping, 0.5, 1.0)),
            ("切换频率", max(0.0, min(1.0, (5.0 - slideshowInterval) / (5.0 - 0.5))))
        ]
    }

    // 推荐默认值的归一化，用于与当前系数对比展示
    private var defaultRadarNormalizedValues: [Double] {
        let clamp: (Double, Double, Double) -> Double = { v, lo, hi in max(0.0, min(1.0, (v - lo) / (hi - lo))) }
        let defaultParallaxStrength = 0.85
        let defaultPanX = 0.20
        let defaultPanY = 0.20
        let defaultZoomMin = 0.9
        let defaultZoomMax = 2.0
        let defaultReboundSpeed = 0.40
        let defaultReboundDamping = 0.85
        let defaultInterval = 1.0
        let defaultPortrait = 0.70
        let defaultLandscape = 0.40

        return [
            defaultParallaxStrength,
            clamp(defaultPortrait, 0.5, 0.9),
            clamp(defaultLandscape, 0.2, 0.7),
            clamp(defaultPanX, 0.05, 0.5),
            clamp(defaultPanY, 0.05, 0.5),
            clamp(defaultZoomMin, 0.5, 1.0),
            clamp(defaultZoomMax, 1.0, 3.0),
            max(0.0, min(1.0, (0.6 - defaultReboundSpeed) / (0.6 - 0.1))),
            clamp(defaultReboundDamping, 0.5, 1.0),
            max(0.0, min(1.0, (5.0 - defaultInterval) / (5.0 - 0.5)))
        ]
    }

    // （已去掉雷达图下方标签）

    // 底部重置按钮
    private var resetSection: some View {
        Section {
            Button(role: .destructive) { showResetConfirm = true } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重置为推荐默认值")
                }
            }
        } footer: {
            Text("将体感、展示比例、拖拽/缩放、回弹及播放间隔恢复为推荐默认值。")
        }
    }

    private func resetToDefaults() {
        // 推荐默认值
        slideshowInterval = 1.0
        parallaxEnabled = true
        parallaxStrength = 0.85
        panLimitFractionX = 0.20
        panLimitFractionY = 0.20
        zoomMin = 0.9
        zoomMax = 2.0
        reboundSpeed = 0.40
        reboundDamping = 0.85
        portraitMaxHeightFraction = 0.70
        landscapeMaxHeightFraction = 0.40
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
    }

    private var slideshowSettingsSection: some View {
        Section("幻灯片设置") {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播放间隔").font(.body)
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
                        .background(Capsule().fill(.blue.opacity(0.1)))
                }
                HStack {
                    Text("0.5").font(.caption).foregroundColor(.secondary)
                    Slider(value: $slideshowInterval, in: 0.5...5.0, step: 0.1) { Text("播放间隔") }
                        .accentColor(.blue)
                    Text("5.0").font(.caption).foregroundColor(.secondary)
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
                            Text("随设备倾斜轻微视差").font(.body)
                            Text("不触发摇一摇，仅用于展示时的体感。尊重‘降低动态效果’设置。（推荐强度 85%）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                HStack {
                    Text("强度").font(.caption).foregroundColor(.secondary).frame(width: 32, alignment: .leading)
                    Slider(value: $parallaxStrength, in: 0...1, step: 0.05) { Text("体感强度") }
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

    // 图片展示比例（竖图/横图）
    private var displayRatioSection: some View {
        Section("展示比例") {
            VStack(spacing: 16) {
                // 竖图高度占屏
                HStack {
                    Image(systemName: "rectangle.portrait")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mint)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("竖图高度占屏")
                        Text("竖屏图片最大高度相对屏幕高度（默认 70%）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", portraitMaxHeightFraction * 100))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.mint.opacity(0.12)))
                }
                HStack {
                    Text("50%").font(.caption).foregroundColor(.secondary)
                    Slider(value: $portraitMaxHeightFraction, in: 0.5...0.9, step: 0.01) { Text("竖图高度占屏") }
                        .tint(.mint)
                    Text("90%").font(.caption).foregroundColor(.secondary)
                }

                // 横图高度占屏
                HStack {
                    Image(systemName: "rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("横图高度占屏")
                        Text("横屏图片最大高度相对屏幕高度（默认 40%）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", landscapeMaxHeightFraction * 100))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.cyan.opacity(0.12)))
                }
                HStack {
                    Text("20%").font(.caption).foregroundColor(.secondary)
                    Slider(value: $landscapeMaxHeightFraction, in: 0.2...0.7, step: 0.01) { Text("横图高度占屏") }
                        .tint(.cyan)
                    Text("70%").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var interactionRangeSection: some View {
        Section("交互范围") {
            VStack(spacing: 16) {
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
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.teal)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("缩放范围")
                        Text("双指缩放时的最小/最大倍率（推荐最小 ×0.9、最大 ×2.0）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Text("最小").font(.caption).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
                    Slider(value: $zoomMin, in: 0.5...1.0, step: 0.05) { Text("最小缩放") }
                        .tint(.teal)
                    Text(String(format: "×%.2f", zoomMin)).font(.caption).foregroundColor(.secondary).frame(width: 50, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Text("最大").font(.caption).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
                    Slider(value: $zoomMax, in: 1.0...3.0, step: 0.1) { Text("最大缩放") }
                        .tint(.teal)
                    Text(String(format: "×%.1f", zoomMax)).font(.caption).foregroundColor(.secondary).frame(width: 50, alignment: .trailing)
                }
            }
            .padding(.vertical, 6)
            .onChange(of: zoomMin) { _, newMin in if newMin >= zoomMax { zoomMax = min(3.0, newMin + 0.1) } }
            .onChange(of: zoomMax) { _, newMax in if newMax <= zoomMin { zoomMin = max(0.5, newMax - 0.1) } }
        }
    }

    private var animationTuningSection: some View {
        Section("动画与回弹") {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("回弹速度")
                        Text("越小越快（单位秒，推荐 0.40s）")
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
}

// 轻量级雷达图（0~1 值）
struct RadarChartView: View {
    let values: [Double]
    let labels: [String]
    var referenceValues: [Double]? = nil
    var levels: Int = 4
    var valueColor: Color = .accentColor
    var referenceColor: Color = .gray

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let size = min(w, h)
            let center = CGPoint(x: w/2, y: h/2)
            let radius = size/2 - 20
            let count = max(3, min(values.count, labels.count))
            let angles = (0..<count).map { i -> Double in
                let step = 2.0 * .pi / Double(count)
                return -Double.pi/2 + Double(i) * step
            }

            ZStack {
                // 同心多边形网格
                ForEach(1..<(levels+1), id: \.self) { level in
                    let r = radius * CGFloat(level) / CGFloat(levels)
                    Path { path in
                        for (idx, a) in angles.enumerated() {
                            let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                            if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                // 轴线
                ForEach(0..<count, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        let pt = CGPoint(x: center.x + radius * CGFloat(cos(angles[i])), y: center.y + radius * CGFloat(sin(angles[i])))
                        path.addLine(to: pt)
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                // 参考默认值多边形
                if let ref = referenceValues {
                    let refClamped = Array(ref.prefix(count)).map { max(0.0, min(1.0, $0)) }
                    Path { path in
                        for (idx, a) in angles.enumerated() {
                            let r = radius * CGFloat(refClamped[idx])
                            let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                            if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        path.closeSubpath()
                    }
                    .fill(referenceColor.opacity(0.18))
                    .overlay(
                        Path { path in
                            for (idx, a) in angles.enumerated() {
                                let r = radius * CGFloat(refClamped[idx])
                                let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                                if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                            }
                            path.closeSubpath()
                        }
                        .stroke(referenceColor.opacity(0.6), lineWidth: 1.5)
                    )
                }

                // 当前值多边形
                let clamped = values.prefix(count).map { max(0.0, min(1.0, $0)) }
                Path { path in
                    for (idx, a) in angles.enumerated() {
                        let r = radius * CGFloat(clamped[idx])
                        let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                        if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [valueColor.opacity(0.28), valueColor.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Path { path in
                        for (idx, a) in angles.enumerated() {
                            let r = radius * CGFloat(clamped[idx])
                            let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                            if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        path.closeSubpath()
                    }
                    .stroke(valueColor.opacity(0.5), lineWidth: 2)
                )

                // 顶点小圆点
                ForEach(0..<count, id: \.self) { i in
                    let r = radius * CGFloat(clamped[i])
                    let pt = CGPoint(x: center.x + r * CGFloat(cos(angles[i])), y: center.y + r * CGFloat(sin(angles[i])))
                    Circle()
                        .fill(valueColor)
                        .frame(width: 6, height: 6)
                        .position(pt)
                }

                // 标签
                ForEach(0..<count, id: \.self) { i in
                    let labelRadius = radius + 14
                    let pt = CGPoint(x: center.x + labelRadius * CGFloat(cos(angles[i])), y: center.y + labelRadius * CGFloat(sin(angles[i])))
                    Text(labels[i])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(pt)
                }
            }
        }
    }
}

#Preview {
    SettingsView(folderManager: FolderManager())
}
