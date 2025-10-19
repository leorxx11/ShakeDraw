import Foundation
import UIKit
import UniformTypeIdentifiers

class FolderManager: ObservableObject {
    struct ManagedFolder: Identifiable, Codable, Equatable {
        let id: UUID
        var bookmarkData: Data?
        var includeInDraw: Bool
        var lastResolvedPath: String
        var displayName: String?
        var isAppGroup: Bool? // 默认为 false；老数据无此字段
    }

    @Published private(set) var folders: [ManagedFolder] = []
    @Published var hasPermission: Bool = false
    @Published var folderCounts: [UUID: Int] = [:]

    private let foldersKey = "ShakeDraw_ManagedFolders"
    // Legacy single-folder key (for migration)
    private let legacyBookmarkKey = "ShakeDrawFolderBookmark"

    private var documentPickerDelegate: FolderPickerDelegate?

    // App Group 配置（请与工程 Capabilities 中的 App Group 保持一致）
    static let appGroupIdentifier = "group.com.leorxx.ShakeDraw"
    private let appGroupFolderName = "SharedImages"
    private let supportedImageTypes: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]

    init() {
        loadSavedFolders()
        validateBookmarks()
    }

    // MARK: - Public API

    func selectFolders() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.allowsMultipleSelection = true
        documentPicker.shouldShowFileExtensions = true
        documentPicker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        documentPicker.modalPresentationStyle = .formSheet

        documentPickerDelegate = FolderPickerDelegate(manager: self)
        documentPicker.delegate = documentPickerDelegate

        DispatchQueue.main.async {
            guard let top = Self.topMostViewController() else { return }
            // 避免重复呈现：如当前已有模态展示，取其最顶层再展示
            if top.presentedViewController == nil {
                top.present(documentPicker, animated: true)
            } else {
                // 如果已经有展示层（例如 SwiftUI 的 sheet），从其最顶层继续展示
                Self.topPresentedController(from: top).present(documentPicker, animated: true)
            }
        }
    }

    // MARK: - Top VC helpers
    private static func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return nil }
        let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        guard var top = keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return unwrapContainerController(top)
    }

    private static func topPresentedController(from vc: UIViewController) -> UIViewController {
        var top = vc
        while let presented = top.presentedViewController { top = presented }
        return unwrapContainerController(top)
    }

    private static func unwrapContainerController(_ vc: UIViewController) -> UIViewController {
        if let nav = vc as? UINavigationController { return nav.visibleViewController ?? nav }
        if let tab = vc as? UITabBarController { return tab.selectedViewController ?? tab }
        return vc
    }

    func addFolders(urls: [URL]) {
        var added = false
        for url in urls {
            #if DEBUG
            print("📁 [Import] 尝试添加文件夹: \(url.path)")
            #endif
            // Start accessing security-scoped resource first
            let hasAccess = url.startAccessingSecurityScopedResource()
            #if DEBUG
            print("📁 [Import] startAccessingSecurityScopedResource = \(hasAccess)")
            #endif
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            
            do {
                // Create bookmark data for persistent access (iOS: no withSecurityScope)
                #if os(iOS)
                var data: Data
                do {
                    data = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
                } catch {
                    // Fallback: some providers may not support minimalBookmark; try default options
                    #if DEBUG
                    print("⚠️ minimalBookmark 失败，尝试使用默认选项: \(error)")
                    #endif
                    data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                }
                #else
                let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                #endif
                let path = url.standardizedFileURL.path
                // de-dup by path
                if folders.contains(where: { $0.lastResolvedPath == path }) {
                    #if DEBUG
                    print("ℹ️ [Import] 已存在，跳过: \(path)")
                    #endif
                    continue
                }
                let item = ManagedFolder(id: UUID(), bookmarkData: data, includeInDraw: true, lastResolvedPath: path, displayName: url.lastPathComponent, isAppGroup: false)
                folders.append(item)
                added = true
                #if DEBUG
                print("✅ [Import] 已添加: \(url.lastPathComponent)")
                #endif
            } catch {
                print("❌ 保存书签失败: \(error)")
            }
        }
        if added { persist(); refreshPermissionFlag(); refreshFolderCounts() }
    }

    func removeFolders(at offsets: IndexSet) {
        folders.remove(atOffsets: offsets)
        persist(); refreshPermissionFlag(); refreshFolderCounts()
    }

    func removeFolder(id: UUID) {
        if let idx = folders.firstIndex(where: { $0.id == id }) {
            folders.remove(at: idx)
            persist(); refreshPermissionFlag(); refreshFolderCounts()
        }
    }

    func updateInclude(id: UUID, include: Bool) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].includeInDraw = include
        persist()
        refreshPermissionFlag()
    }

    func clearAllFolders() {
        // 只移除非共享文件夹，保留App Group文件夹
        folders.removeAll { folder in
            return folder.isAppGroup != true
        }
        persist(); refreshPermissionFlag(); refreshFolderCounts()
    }

    

    // All resolved URLs (included or not)
    func allResolvedFolderURLs() -> [URL] {
        folders.compactMap { resolvedURL(for: $0) }
    }
    
    // Get folder info with security access metadata
    func includedFolderInfo() -> [(url: URL, isAppGroup: Bool)] {
        return folders.compactMap { mf in
            guard mf.includeInDraw else { return nil }
            guard let url = resolvedURL(for: mf) else { return nil }
            return (url: url, isAppGroup: mf.isAppGroup == true)
        }
    }

    // Find parent managed folder root for a file url
    func parentFolder(for fileURL: URL) -> URL? {
        let filePath = fileURL.standardizedFileURL.path
        let filePathDecoded = filePath.removingPercentEncoding ?? filePath
        
        // Get all folder info with better matching
        let folderInfo = includedFolderInfo()
        
        // Try to find the best matching parent folder
        for (folderURL, _) in folderInfo {
            let folderPath = folderURL.standardizedFileURL.path
            let folderPathDecoded = folderPath.removingPercentEncoding ?? folderPath
            
            // Try multiple matching approaches
            if filePathDecoded.hasPrefix(folderPathDecoded) ||
               filePath.hasPrefix(folderPath) ||
               filePathDecoded.contains(folderPathDecoded) {
                #if DEBUG
                print("🔍 找到父文件夹匹配: \(folderURL.lastPathComponent) for \(fileURL.lastPathComponent)")
                #endif
                return folderURL
            }
        }
        
        #if DEBUG
        print("⚠️ 未找到父文件夹匹配，文件路径: \(filePathDecoded)")
        print("⚠️ 可用文件夹路径:")
        for (folderURL, _) in folderInfo {
            print("   - \(folderURL.standardizedFileURL.path)")
        }
        #endif
        
        return nil
    }
    
    // Check if a URL is an AppGroup URL
    func isAppGroupURL(_ url: URL) -> Bool {
        return folders.contains { mf in
            mf.isAppGroup == true && resolvedURL(for: mf)?.standardizedFileURL.path == url.standardizedFileURL.path
        }
    }

    // MARK: - Persistence
    private func persist() {
        do {
            let data = try JSONEncoder().encode(folders)
            UserDefaults.standard.set(data, forKey: foldersKey)
        } catch {
            print("❌ 编码文件夹列表失败: \(error)")
        }
    }

    private func loadSavedFolders() {
        // New format
        if let data = UserDefaults.standard.data(forKey: foldersKey) {
            do {
                var list = try JSONDecoder().decode([ManagedFolder].self, from: data)
                // 迁移：将内置 App Group 文件夹显示名从“共享图片”统一为“收藏”
                var didRename = false
                for i in list.indices {
                    if list[i].isAppGroup == true, list[i].displayName == "共享图片" {
                        list[i].displayName = "收藏"
                        didRename = true
                    }
                }
                self.folders = list
                if didRename { persist() }
                refreshPermissionFlag()
            } catch {
                print("❌ 解码文件夹列表失败: \(error)")
            }
        }
        // Migrate legacy single folder (if present and no new data)
        if folders.isEmpty, let legacy = UserDefaults.standard.data(forKey: legacyBookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: legacy, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale {
                    let path = url.standardizedFileURL.path
                    let item = ManagedFolder(id: UUID(), bookmarkData: legacy, includeInDraw: true, lastResolvedPath: path, displayName: url.lastPathComponent, isAppGroup: false)
                    folders = [item]
                    persist()
                    print("🔁 已迁移旧书签到多文件夹配置: \(path)")
                    // Clear legacy key
                    UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
                }
            } catch {
                print("❌ 解析旧书签失败: \(error)")
                UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
            }
        }
        // Ensure App Group folder entry exists (if App Group configured)
        ensureAppGroupFolderEntry()
        refreshPermissionFlag()
        refreshFolderCounts()
    }

    private func refreshPermissionFlag() {
        // 只有当存在启用的文件夹时才认为有权限
        // 使用 @Published 自动通知，避免手动发送造成多余刷新和潜在的导航回退
        hasPermission = folders.contains { $0.includeInDraw }
    }

    // MARK: - Validation
    private func validateBookmarks() {
        // 检测旧的.minimalBookmark书签并标记需要重新添加
        var needsUpdate = false
        var invalidFolders: [String] = []
        
        for (index, folder) in folders.enumerated() {
            if folder.isAppGroup == true { continue } // AppGroup不需要检查
            
            guard let data = folder.bookmarkData else { continue }
            
            // 尝试解析书签
            if let url = resolveBookmark(data) {
                // 测试安全访问权限
                let hasAccess = url.startAccessingSecurityScopedResource()
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                } else {
                    // 书签无效，需要重新添加
                    invalidFolders.append(folder.displayName ?? folder.lastResolvedPath)
                    folders[index].includeInDraw = false // 暂时禁用
                    needsUpdate = true
                }
            }
        }
        
        if needsUpdate {
            persist()
            print("⚠️ 发现 \(invalidFolders.count) 个无效文件夹书签: \(invalidFolders.joined(separator: ", "))")
            print("💡 请在设置中重新添加这些文件夹以恢复访问权限")
        }
    }
    
    // MARK: - Helpers
    private func resolveBookmark(_ data: Data) -> URL? {
        do {
            var stale = false
            // iOS: resolve without UI; macOS: resolve with security scope
            #if os(iOS)
            let url = try URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            #else
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            #endif
            if stale {
                print("🔄 书签已失效")
                return nil
            }
            return url
        } catch {
            print("❌ 解析书签失败: \(error)")
            return nil
        }
    }

    private func appGroupURL() -> URL? {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
        #if DEBUG
        if container == nil { print("🐞 AppGroup containerURL 为 nil: \(Self.appGroupIdentifier)") }
        else { print("🐞 AppGroup containerURL: \(container!.path)") }
        #endif
        guard let container else { return nil }
        let dir = container.appendingPathComponent(appGroupFolderName, isDirectory: true)
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                #if DEBUG
                print("🐞 已创建收藏目录: \(dir.path)")
                #endif
            } catch {
                print("❌ 创建 App Group 目录失败: \(error)")
            }
        } else {
            #if DEBUG
            print("🐞 收藏目录已存在: \(dir.path)")
            #endif
        }
        return dir
    }

    private func resolvedURL(for mf: ManagedFolder) -> URL? {
        if mf.isAppGroup == true { return appGroupURL() }
        if let data = mf.bookmarkData { return resolveBookmark(data) }
        return nil
    }

    private func ensureAppGroupFolderEntry() {
        guard let url = appGroupURL() else { return }
        if let idx = folders.firstIndex(where: { $0.isAppGroup == true }) {
            // 更新路径（若容器位置变化）
            folders[idx].lastResolvedPath = url.path
            if folders[idx].displayName == nil { folders[idx].displayName = "收藏" }
            persist()
            // 更新计数
            refreshFolderCounts()
            return
        }
        let item = ManagedFolder(
            id: UUID(),
            bookmarkData: nil,
            includeInDraw: true,
            lastResolvedPath: url.path,
            displayName: "收藏",
            isAppGroup: true
        )
        folders.insert(item, at: 0)
        persist()
        refreshFolderCounts()
    }

    // 清空 App Group 收藏目录（不删除目录本身）
    func clearAppGroupImages() {
        guard let dir = appGroupURL() else { return }
        do {
            let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
            for u in items { try? FileManager.default.removeItem(at: u) }
            print("🗑️ 已清空收藏目录: \(dir.path)")
            refreshFolderCounts()
        } catch {
            print("❌ 清空收藏目录失败: \(error)")
        }
    }

    // 异步刷新每个文件夹的图片数量
    func refreshFolderCounts() {
        DispatchQueue.global(qos: .userInitiated).async {
            var counts: [UUID: Int] = [:]
            for mf in self.folders {
                guard let root = self.resolvedURL(for: mf) else {
                    #if DEBUG
                    print("🐞 统计跳过：无法解析URL —— \(mf.displayName ?? mf.lastResolvedPath)")
                    #endif
                    continue
                }
                #if DEBUG
                print("🐞 开始统计：\(mf.displayName ?? URL(fileURLWithPath: mf.lastResolvedPath).lastPathComponent) at \(root.path)")
                #endif
                var count = 0
                let isAppGroup = mf.isAppGroup == true
                let startAccess = isAppGroup ? true : root.startAccessingSecurityScopedResource()
                defer { if startAccess && !isAppGroup { root.stopAccessingSecurityScopedResource() } }
                if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .nameKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey])
                            if values.isRegularFile == true {
                                let ext = fileURL.pathExtension.lowercased()
                                if self.supportedImageTypes.contains(ext) { count += 1 }
                            }
                        } catch { /* ignore */ }
                    }
                }
                #if DEBUG
                print("🐞 统计完成：\(mf.displayName ?? mf.lastResolvedPath) = \(count) 张")
                #endif
                counts[mf.id] = count
            }
            DispatchQueue.main.async {
                self.folderCounts = counts
                #if DEBUG
                print("🐞 所有文件夹计数刷新完成：\(counts)")
                #endif
            }
        }
    }

    // iOS 不支持升级为安全作用域书签；保留空实现避免误用

    // 已移除仅供调试的打印与列举函数，避免冗余代码
}

class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let manager: FolderManager

    init(manager: FolderManager) {
        self.manager = manager
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📁 文档选择器返回URLs: \(urls)")
        guard !urls.isEmpty else {
            print("❌ 没有选择文件夹")
            return
        }
        manager.addFolders(urls: urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📁 文档选择器被取消")
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("📁 文档选择器返回单个URL: \(url)")
        manager.addFolders(urls: [url])
    }
}
