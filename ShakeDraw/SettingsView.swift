import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var folderManager: FolderManager
    @State private var showImporter = false
    @State private var showSharedImagesManager = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 3.0

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
                        Text("设置幻灯片自动切换的时间间隔")
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
