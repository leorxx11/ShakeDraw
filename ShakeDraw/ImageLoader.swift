import Foundation
import UIKit
import ImageIO

class ImageLoader: ObservableObject {
    @Published var images: [URL] = []
    @Published var isLoading = false
    
    private let supportedImageTypes: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
    private var parentFolderURL: URL?
    
    func loadImages(from folderURL: URL) {
        print("🖼️ 开始加载图片，文件夹: \(folderURL.path)")
        isLoading = true
        images.removeAll()
        parentFolderURL = folderURL
        
        DispatchQueue.global(qos: .userInitiated).async {
            var imageURLs: [URL] = []
            
            let startAccess = folderURL.startAccessingSecurityScopedResource()
            defer {
                if startAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            
            print("🖼️ 安全访问权限: \(startAccess)")
            
            guard startAccess else {
                print("❌ 无法获取文件夹访问权限")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            if let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .nameKey], options: [.skipsHiddenFiles]) {
                
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey])
                        if resourceValues.isRegularFile == true && self.isImageFile(fileURL) {
                            imageURLs.append(fileURL)
                            print("🖼️ 找到图片: \(resourceValues.name ?? fileURL.lastPathComponent)")
                        }
                    } catch {
                        print("❌ 检查文件错误: \(error)")
                    }
                }
            } else {
                print("❌ 无法创建文件枚举器")
            }
            
            print("🖼️ 总共找到 \(imageURLs.count) 张图片")
            
            DispatchQueue.main.async {
                self.images = imageURLs.shuffled()
                self.isLoading = false
            }
        }
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
    
    func loadUIImage(from url: URL, parentFolderURL: URL? = nil) -> UIImage? {
        print("🖼️ loadUIImage 被调用，URL: \(url)")
        
        let folderURL = parentFolderURL ?? self.parentFolderURL
        
        guard let parentURL = folderURL else {
            print("❌ 没有父文件夹URL")
            return nil
        }
        
        let startAccess = parentURL.startAccessingSecurityScopedResource()
        defer {
            if startAccess {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard startAccess else {
            print("❌ 无法获取父文件夹访问权限")
            return nil
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
    func loadThumbnail(from url: URL, parentFolderURL: URL? = nil, maxDimension: CGFloat = 200) -> UIImage? {
        let folderURL = parentFolderURL ?? self.parentFolderURL
        guard let parentURL = folderURL else { return nil }

        let startAccess = parentURL.startAccessingSecurityScopedResource()
        defer { if startAccess { parentURL.stopAccessingSecurityScopedResource() } }
        guard startAccess else { return nil }

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
