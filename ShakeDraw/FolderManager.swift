import Foundation
import UIKit
import UniformTypeIdentifiers

class FolderManager: ObservableObject {
    @Published var selectedFolderURL: URL?
    @Published var hasPermission = false
    
    private let bookmarkKey = "ShakeDrawFolderBookmark"
    private var documentPickerDelegate: FolderPickerDelegate?
    
    init() {
        loadSavedFolder()
    }
    
    func selectFolder() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.allowsMultipleSelection = false
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
    
    func setSelectedFolder(_ url: URL) {
        print("🔧 尝试设置选中文件夹: \(url.path)")
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        print("🔧 获取安全访问权限: \(didStartAccessing)")
        
        if didStartAccessing {
            selectedFolderURL = url
            hasPermission = true
            saveBookmark(for: url)
            print("✅ 文件夹设置成功")
        } else {
            print("❌ 无法获取文件夹访问权限")
            hasPermission = false
            selectedFolderURL = nil
        }
    }
    
    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            print("✅ 成功保存书签: \(url.path)")
        } catch {
            print("❌ 保存书签失败: \(error)")
        }
    }
    
    private func loadSavedFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else { 
            print("📝 没有找到保存的书签")
            return 
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if !isStale {
                if url.startAccessingSecurityScopedResource() {
                    selectedFolderURL = url
                    hasPermission = true
                    print("✅ 成功恢复文件夹访问权限: \(url.path)")
                } else {
                    print("❌ 无法获取文件夹访问权限")
                }
            } else {
                print("📝 书签已过期，需要重新选择文件夹")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
            }
        } catch {
            print("❌ 解析书签失败: \(error)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }
    
    func stopAccessing() {
        selectedFolderURL?.stopAccessingSecurityScopedResource()
        hasPermission = false
    }
    
    func clearFolder() {
        print("🗑️ 清除文件夹和相关数据")
        
        // 停止访问当前文件夹
        selectedFolderURL?.stopAccessingSecurityScopedResource()
        
        // 清除用户数据
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        
        // 清除RandomDrawManager相关的缓存数据
        UserDefaults.standard.removeObject(forKey: "ShakeDraw_LastResultRelativePath")
        UserDefaults.standard.removeObject(forKey: "ShakeDraw_LastResultFolderPath")
        
        // 清除缓存预览图片
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let previewURL = cacheURL.appendingPathComponent("last_result_preview.jpg")
            try? FileManager.default.removeItem(at: previewURL)
            print("🗑️ 已删除预览缓存: \(previewURL.path)")
        }
        
        // 重置状态
        selectedFolderURL = nil
        hasPermission = false
        
        print("✅ 文件夹和相关数据已清除")
    }
}

class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let manager: FolderManager
    
    init(manager: FolderManager) {
        self.manager = manager
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📁 文档选择器返回URLs: \(urls)")
        guard let url = urls.first else { 
            print("❌ 没有选择文件夹")
            return 
        }
        print("📁 选中文件夹: \(url)")
        manager.setSelectedFolder(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📁 文档选择器被取消")
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("📁 文档选择器返回单个URL: \(url)")
        manager.setSelectedFolder(url)
    }
}
