import Foundation
import UIKit
import UniformTypeIdentifiers

class FolderManager: ObservableObject {
    struct ManagedFolder: Identifiable, Codable, Equatable {
        let id: UUID
        var bookmarkData: Data
        var includeInDraw: Bool
        var lastResolvedPath: String
        var displayName: String?
    }

    @Published private(set) var folders: [ManagedFolder] = []
    @Published var hasPermission: Bool = false

    private let foldersKey = "ShakeDraw_ManagedFolders"
    // Legacy single-folder key (for migration)
    private let legacyBookmarkKey = "ShakeDrawFolderBookmark"

    private var documentPickerDelegate: FolderPickerDelegate?

    init() {
        loadSavedFolders()
    }

    // MARK: - Public API
    func selectFolder() { selectFolders() }

    func selectFolders() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.allowsMultipleSelection = true
        documentPicker.shouldShowFileExtensions = true
        documentPicker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        documentPickerDelegate = FolderPickerDelegate(manager: self)
        documentPicker.delegate = documentPickerDelegate

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = windowScene.windows.first(where: \.isKeyWindow) {
                window.rootViewController?.present(documentPicker, animated: true)
            }
        }
    }

    func addFolders(urls: [URL]) {
        var added = false
        for url in urls {
            do {
                let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                let path = url.standardizedFileURL.path
                // de-dup by path
                if folders.contains(where: { $0.lastResolvedPath == path }) { continue }
                let item = ManagedFolder(id: UUID(), bookmarkData: data, includeInDraw: true, lastResolvedPath: path, displayName: url.lastPathComponent)
                folders.append(item)
                added = true
            } catch {
                print("❌ 保存书签失败: \(error)")
            }
        }
        if added { persist(); refreshPermissionFlag() }
    }

    func removeFolders(at offsets: IndexSet) {
        folders.remove(atOffsets: offsets)
        persist(); refreshPermissionFlag()
    }

    func removeFolder(id: UUID) {
        if let idx = folders.firstIndex(where: { $0.id == id }) {
            folders.remove(at: idx)
            persist(); refreshPermissionFlag()
        }
    }

    func updateInclude(id: UUID, include: Bool) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].includeInDraw = include
        persist()
    }

    func clearAllFolders() {
        folders.removeAll()
        persist(); refreshPermissionFlag()
    }

    // Resolved URLs for included folders
    func includedFolderURLs() -> [URL] {
        folders.compactMap { $0.includeInDraw ? resolveBookmark($0.bookmarkData) : nil }
    }

    // All resolved URLs (included or not)
    func allResolvedFolderURLs() -> [URL] {
        folders.compactMap { resolveBookmark($0.bookmarkData) }
    }

    // Find parent managed folder root for a file url
    func parentFolder(for fileURL: URL) -> URL? {
        let filePath = fileURL.standardizedFileURL.path
        // Prefer included folders first
        let roots = includedFolderURLs() + allResolvedFolderURLs()
        return roots.first { filePath.hasPrefix($0.standardizedFileURL.path) }
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
                let list = try JSONDecoder().decode([ManagedFolder].self, from: data)
                self.folders = list
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
                    let item = ManagedFolder(id: UUID(), bookmarkData: legacy, includeInDraw: true, lastResolvedPath: path, displayName: url.lastPathComponent)
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
        refreshPermissionFlag()
    }

    private func refreshPermissionFlag() {
        hasPermission = !folders.isEmpty
        objectWillChange.send()
    }

    // MARK: - Helpers
    private func resolveBookmark(_ data: Data) -> URL? {
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale { return nil }
            return url
        } catch {
            print("❌ 解析书签失败: \(error)")
            return nil
        }
    }
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
