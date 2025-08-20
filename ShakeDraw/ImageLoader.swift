import Foundation
import UIKit
import ImageIO

class ImageLoader: ObservableObject {
    @Published var images: [URL] = []
    @Published var isLoading = false
    
    private let supportedImageTypes: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
    private var parentFolderURL: URL?
    
    func loadImages(from folderInfo: [(url: URL, isAppGroup: Bool)]) {
        let paths = folderInfo.map { $0.url.path }.joined(separator: ", ")
        print("🖼️ 开始加载图片，文件夹集合: [\(paths)]")
        isLoading = true
        images.removeAll()

        DispatchQueue.global(qos: .userInitiated).async {
            var imageSet: Set<URL> = []

            for (folderURL, isAppGroup) in folderInfo {
                let startAccess = isAppGroup ? true : folderURL.startAccessingSecurityScopedResource()
                defer { if startAccess && !isAppGroup { folderURL.stopAccessingSecurityScopedResource() } }

                print("🖼️ [\(folderURL.lastPathComponent)] 安全访问权限: \(startAccess) (AppGroup: \(isAppGroup))")
                print("🖼️ [\(folderURL.lastPathComponent)] URL路径: \(folderURL.path)")
                
                // 即使安全访问失败，也尝试读取（可能权限仍然有效）
                if !startAccess && !isAppGroup {
                    print("⚠️ 安全访问权限失败，仍尝试读取文件夹")
                }

                if let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .nameKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey])
                            if resourceValues.isRegularFile == true && self.isImageFile(fileURL) {
                                imageSet.insert(fileURL)
                            }
                        } catch {
                            print("❌ 检查文件错误: \(error)")
                        }
                    }
                } else {
                    print("❌ 无法创建文件枚举器: \(folderURL.path)，尝试 NSFileCoordinator 回退")
                    // 对于来自“文件”/第三方文件提供者的目录，使用 NSFileCoordinator 协调读取可提升成功率
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    var coordError: NSError?
                    coordinator.coordinate(readingItemAt: folderURL, options: [], error: &coordError) { coordinatedURL in
                        if let fallbackEnum = FileManager.default.enumerator(at: coordinatedURL, includingPropertiesForKeys: [.isRegularFileKey, .nameKey], options: [.skipsHiddenFiles]) {
                            for case let fileURL as URL in fallbackEnum {
                                do {
                                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey])
                                    if resourceValues.isRegularFile == true && self.isImageFile(fileURL) {
                                        imageSet.insert(fileURL)
                                    }
                                } catch { /* ignore single file errors */ }
                            }
                        } else {
                            print("❌ NSFileCoordinator 回退仍失败: \(coordinatedURL.path)")
                        }
                    }
                }
            }

            let result = Array(imageSet)
            print("🖼️ 总共找到 \(result.count) 张图片（合并去重）")

            DispatchQueue.main.async {
                self.images = result.shuffled()
                self.isLoading = false
            }
        }
    }
    
    // Backward compatibility method
    func loadImages(from folderURLs: [URL]) {
        let folderInfo = folderURLs.map { (url: $0, isAppGroup: $0.lastPathComponent == "SharedImages" && $0.path.contains("/Shared/AppGroup/")) }
        loadImages(from: folderInfo)
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedImageTypes.contains(fileExtension)
    }
    
    func getRandomImage(excluding excludeURL: URL? = nil) -> URL? {
        print("🎲 getRandomImage 被调用，images.count: \(images.count)")
        guard !images.isEmpty else { 
            print("❌ images 数组为空")
            return nil 
        }
        
        // 如果只有一张图片，直接返回（无法避免重复）
        if images.count == 1 {
            let onlyImage = images.first
            print("🎲 只有一张图片，返回: \(onlyImage?.lastPathComponent ?? "nil")")
            return onlyImage
        }
        
        // 过滤掉当前图片
        let availableImages: [URL]
        if let excludeURL = excludeURL {
            availableImages = images.filter { $0.standardizedFileURL != excludeURL.standardizedFileURL }
            print("🎲 排除当前图片后，可选图片数: \(availableImages.count)")
        } else {
            availableImages = images
            print("🎲 无排除图片，全部可选图片数: \(availableImages.count)")
        }
        
        // 如果过滤后没有图片了，返回原数组中的随机图片
        let finalImages = availableImages.isEmpty ? images : availableImages
        let randomImage = finalImages.randomElement()
        
        print("🎲 返回随机图片: \(randomImage?.lastPathComponent ?? "nil")")
        if let exclude = excludeURL {
            print("🎲 是否避免了重复: \(randomImage?.standardizedFileURL != exclude.standardizedFileURL)")
        }
        
        return randomImage
    }
    
    func loadUIImage(from url: URL, parentFolderURL: URL? = nil, isAppGroup: Bool? = nil) -> UIImage? {
        print("🖼️ loadUIImage 被调用，URL: \(url)")
        
        let folderURL = parentFolderURL ?? self.parentFolderURL
        
        // Manage security access if we have a parent folder
        var needsSecurityCleanup = false
        var parentForCleanup: URL?
        
        if let parentURL = folderURL {
            // Normal case: we have a parent folder URL
            let appGroup = isAppGroup ?? (parentURL.lastPathComponent == "SharedImages" && parentURL.path.contains("group.com.leorxx.ShakeDraw"))
            let startAccess = appGroup ? true : parentURL.startAccessingSecurityScopedResource()
            if startAccess && !appGroup {
                needsSecurityCleanup = true
                parentForCleanup = parentURL
            }
        } else {
            // Fallback: try to load directly (security access might be active from scanning)
            #if DEBUG
            print("⚠️ 没有父文件夹URL，尝试直接加载: \(url.lastPathComponent)")
            #endif
        }
        
        defer { 
            if needsSecurityCleanup, let parent = parentForCleanup {
                parent.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            print("❌ 从文件加载图片失败: \(url.lastPathComponent)")
            return nil
        }
        print("✅ 从文件加载图片成功: \(url.lastPathComponent)")
        return image
    }

    /// 加载缩略图，避免在滚动动画中解码超大原图造成卡顿
    func loadThumbnail(from url: URL, parentFolderURL: URL? = nil, maxDimension: CGFloat = 200, isAppGroup: Bool? = nil) -> UIImage? {
        let folderURL = parentFolderURL ?? self.parentFolderURL
        
        // Manage security access if we have a parent folder
        var needsSecurityCleanup = false
        var parentForCleanup: URL?
        
        if let parentURL = folderURL {
            let appGroup = isAppGroup ?? (parentURL.lastPathComponent == "SharedImages" && parentURL.path.contains("group.com.leorxx.ShakeDraw"))
            let startAccess = appGroup ? true : parentURL.startAccessingSecurityScopedResource()
            if startAccess && !appGroup {
                needsSecurityCleanup = true
                parentForCleanup = parentURL
            }
        } else {
            #if DEBUG
            print("⚠️ loadThumbnail: 没有父文件夹URL，尝试直接加载: \(url.lastPathComponent)")
            #endif
        }
        
        defer { 
            if needsSecurityCleanup, let parent = parentForCleanup {
                parent.stopAccessingSecurityScopedResource()
            }
        }

        if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let opts: [NSString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(max(64, maxDimension))
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                return UIImage(cgImage: cg)
            }
        }

        // 回退：直接解码再缩放
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        let longer = max(image.size.width, image.size.height)
        let scale = max(1, longer / maxDimension)
        let targetSize = CGSize(width: image.size.width / scale, height: image.size.height / scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// 预解码图片，避免首帧渲染时才解码引起的卡顿/白屏
    func predecode(_ image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let decoded = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return decoded
    }
}
