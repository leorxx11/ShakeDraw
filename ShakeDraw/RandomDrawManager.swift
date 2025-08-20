import Foundation
import UIKit
import SwiftUI

class RandomDrawManager: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var isDrawing = false
    @Published var showResult = false
    @Published var pendingTargetURL: URL?
    @Published var pendingTargetImage: UIImage?
    @Published var isRestoring = false
    // 仅维护目标，去掉滚动所需的缩略图与揭示门控
    
    // 当前显示的图片URL，用于防重复
    private var currentImageURL: URL?
    
    // 最短加载时长（更快的节奏）
    let preSpinDuration: TimeInterval = 0.35
    
    private var imageLoader: ImageLoader?
    private var folderManager: FolderManager?
    private let lastResultPathKey = "ShakeDraw_LastResultRelativePath"
    private let lastPreviewFileName = "last_result_preview.jpg"
    private let lastFolderPathKey = "ShakeDraw_LastResultFolderPath"
    
    init() {
        // 空初始化，稍后设置依赖
    }
    
    func setDependencies(imageLoader: ImageLoader, folderManager: FolderManager) {
        self.imageLoader = imageLoader
        self.folderManager = folderManager
    }
    
    func performRandomDraw() {
        print("🎲 performRandomDraw 被调用")
        
        guard let folderManager = folderManager,
              let imageLoader = imageLoader else {
            print("❌ 依赖未设置")
            return
        }
        
        print("🎲 folderManager.hasPermission: \(folderManager.hasPermission)")
        print("🎲 imageLoader.images.isEmpty: \(imageLoader.images.isEmpty)")
        print("🎲 imageLoader.images.count: \(imageLoader.images.count)")
        
        guard folderManager.hasPermission,
              !imageLoader.images.isEmpty else {
            print("❌ 权限检查失败，退出抽签")
            return
        }
        
        print("✅ 权限检查通过，开始抽签")
        // 先进入“抽签中”状态，避免短暂闪回 Idle 提示
        isDrawing = true
        // 保留当前结果在加载覆盖层下，避免空白/闪屏
        pendingTargetURL = nil
        pendingTargetImage = nil

        // 先预选目标（避免 SlotMachine 在目标为空时启动）
        let startTime = Date()
        if let targetURL = imageLoader.getRandomImage(excluding: currentImageURL) {
            print("🎯 预选目标图片URL: \(targetURL)")
            print("🎯 排除的当前图片URL: \(currentImageURL?.lastPathComponent ?? "无")")
            pendingTargetURL = targetURL
            
            // 后台预加载目标全图
            DispatchQueue.global(qos: .userInitiated).async {
                let parentFolderURL = folderManager.parentFolder(for: targetURL)
                let loaded = imageLoader.loadUIImage(from: targetURL, parentFolderURL: parentFolderURL)
                let targetImage = loaded.flatMap { imageLoader.predecode($0) }
                DispatchQueue.main.async {
                    self.pendingTargetImage = targetImage
                    print("✅ 预加载完成：目标图片")
                }
            }
        }

        // 目标已就位后等待最短时长再揭示

        // 等待最短加载时长后展示结果
        finalizeAfter(minDelay: preSpinDuration, startedAt: startTime)
    }

    private func revealNow() {
        // 先让结果出现，再把加载状态稍后关掉，保证有重叠，避免白屏
        self.showResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.isDrawing = false
        }
    }

    // MARK: - Cached preview (for instant show on launch)
    private func previewFileURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(lastPreviewFileName)
    }

    private func savePreviewIfPossible(from image: UIImage) {
        guard let url = previewFileURL() else { return }
        let maxDimension: CGFloat = 600
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return }
        let scale = max(1, max(w, h) / maxDimension)
        let targetSize = CGSize(width: w/scale, height: h/scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let preview = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        if let data = preview.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url, options: [.atomic])
            print("💾 已保存预览图: \(url.path)")
        }
    }

    func showCachedPreviewIfAny() {
        guard hasStoredResult(), let url = previewFileURL(), FileManager.default.fileExists(atPath: url.path) else { return }
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            let decoded = imageLoader?.predecode(img) ?? img
            self.currentImage = decoded
            self.showResult = true
            print("✅ 已显示缓存预览图")
        }
    }
    
    private func finalizeAfter(minDelay: TimeInterval, startedAt: Date) {
        print("⏱️ finalizeAfter 调用，等待最短时长后展示结果")
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = max(0, minDelay - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
            // 不在主线程做磁盘读/解码，确保无白屏卡顿
            if let ready = self.pendingTargetImage {
                self.currentImage = ready
                self.currentImageURL = self.pendingTargetURL // 记录当前图片URL
                self.revealNow()
                if let url = self.pendingTargetURL { self.saveLastResult(url: url) }
                if let img = self.currentImage { self.savePreviewIfPossible(from: img) }
                print("🎯 设置结果完成 - 使用预载图片: true")
            } else if let url = self.pendingTargetURL, let loader = self.imageLoader {
                let parent = self.folderManager?.parentFolder(for: url)
                // A: 先尝试生成缩略图，尽快揭示
                DispatchQueue.global(qos: .userInitiated).async {
                    let thumb = loader.loadThumbnail(from: url, parentFolderURL: parent, maxDimension: 600)
                    DispatchQueue.main.async {
                        if self.currentImage == nil && self.showResult == false, let t = thumb {
                            self.currentImage = t
                            self.currentImageURL = url // 记录当前图片URL
                            self.revealNow()
                            print("🎯 先用缩略图揭示结果")
                        }
                    }
                }
                // B: 加载原图，准备好后替换缩略图
                DispatchQueue.global(qos: .userInitiated).async {
                    let loaded = loader.loadUIImage(from: url, parentFolderURL: parent)
                    let decoded = loaded.flatMap { loader.predecode($0) }
                    DispatchQueue.main.async {
                        if let img = decoded {
                            self.currentImage = img
                            self.currentImageURL = url // 记录当前图片URL
                            self.savePreviewIfPossible(from: img)
                        }
                        self.revealNow()
                        self.saveLastResult(url: url)
                        print("🎯 设置结果完成 - 原图加载并替换: \(decoded != nil)")
                    }
                }
            } else {
                // 兜底随机一次，也放到后台
                DispatchQueue.global(qos: .userInitiated).async {
                    let url = self.imageLoader?.getRandomImage(excluding: self.currentImageURL)
                    let loaded = url.flatMap { u in
                        let parent = self.folderManager?.parentFolder(for: u)
                        return self.imageLoader?.loadUIImage(from: u, parentFolderURL: parent)
                    }
                    let decoded = loaded.flatMap { self.imageLoader?.predecode($0) }
                    DispatchQueue.main.async {
                        self.currentImage = decoded
                        if let u = url { self.currentImageURL = u } // 记录当前图片URL
                        self.revealNow()
                        if let u = url { self.saveLastResult(url: u) }
                        if let img = decoded { self.savePreviewIfPossible(from: img) }
                        print("🎯 设置结果完成 - 兜底异步加载: \(decoded != nil)")
                    }
                }
            }
        }
    }

    // 保存最后结果（相对路径）
    private func saveLastResult(url: URL) {
        let parent = folderManager?.parentFolder(for: url)
        let folderPath = parent?.standardizedFileURL.path ?? ""
        let filePath = url.standardizedFileURL.path
        if !folderPath.isEmpty && filePath.hasPrefix(folderPath) {
            var rel = String(filePath.dropFirst(folderPath.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            UserDefaults.standard.set(rel, forKey: lastResultPathKey)
            UserDefaults.standard.set(folderPath, forKey: lastFolderPathKey)
            print("💾 已保存上次结果相对路径: \(rel)")
        } else {
            // 不在选中文件夹下，直接保存绝对路径（退化方案）
            UserDefaults.standard.set(filePath, forKey: lastResultPathKey)
            UserDefaults.standard.set(folderPath, forKey: lastFolderPathKey)
            print("💾 已保存上次结果绝对路径: \(filePath)")
        }
    }

    // 恢复上次结果
    func restoreLastResultIfAvailable() {
        guard folderManager?.hasPermission == true else {
            print("ℹ️ 无法恢复：无文件夹权限")
            return
        }
        guard let stored = UserDefaults.standard.string(forKey: lastResultPathKey), !stored.isEmpty else {
            print("ℹ️ 没有保存的上次结果")
            return
        }
        isRestoring = true

        let url: URL
        if stored.hasPrefix("/") || stored.hasPrefix("file://") {
            url = URL(fileURLWithPath: stored)
        } else {
            // Compose from stored folder path
            if let folderPath = UserDefaults.standard.string(forKey: lastFolderPathKey) {
                url = URL(fileURLWithPath: folderPath).appendingPathComponent(stored)
            } else {
                // Fallback: treat as absolute (unlikely)
                url = URL(fileURLWithPath: stored)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let parent = self.folderManager?.parentFolder(for: url)
            guard let img = self.imageLoader?.loadUIImage(from: url, parentFolderURL: parent),
                  let decoded = self.imageLoader?.predecode(img) else {
                print("❌ 恢复上次结果失败: \(url.lastPathComponent)")
                DispatchQueue.main.async { self.isRestoring = false }
                return
            }
            DispatchQueue.main.async {
                self.currentImage = decoded
                self.currentImageURL = url // 记录当前图片URL
                self.showResult = true
                self.isDrawing = false
                self.pendingTargetURL = url
                self.pendingTargetImage = decoded
                self.isRestoring = false
                print("✅ 已恢复上次结果: \(url.lastPathComponent)")
            }
        }
    }

    func hasStoredResult() -> Bool {
        guard let s = UserDefaults.standard.string(forKey: lastResultPathKey), !s.isEmpty else { return false }
        guard let folderPaths = folderManager?.allResolvedFolderURLs().map({ $0.standardizedFileURL.path }), !folderPaths.isEmpty else { return false }
        let storedFolderPath = UserDefaults.standard.string(forKey: lastFolderPathKey)
        return storedFolderPath != nil && folderPaths.contains(storedFolderPath!)
    }

    func startRestoreIfNeeded() {
        guard folderManager?.hasPermission == true else { return }
        if hasStoredResult() {
            isRestoring = true
            restoreLastResultIfAvailable()
        }
    }
    
    func resetDraw() {
        showResult = false
        currentImage = nil
        currentImageURL = nil
        pendingTargetURL = nil
        pendingTargetImage = nil
        isDrawing = false
        isRestoring = false
    }
    
    func clearAllData() {
        print("🗑️ 清除RandomDrawManager所有数据")
        resetDraw()
        
        // 清除UserDefaults中的相关数据
        UserDefaults.standard.removeObject(forKey: lastResultPathKey)
        UserDefaults.standard.removeObject(forKey: lastFolderPathKey)
        
        // 清除缓存预览图片
        if let url = previewFileURL() {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ 已删除RandomDrawManager预览缓存")
        }
    }
    
    // 兼容旧接口已移除（不再使用）
}
