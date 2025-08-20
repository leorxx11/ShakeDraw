//
//  ShareViewController.swift
//  Share to ShakeDraw
//
//  Created by 赵粒宇 on 2025/8/20.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupIdentifier = "group.com.leorxx.ShakeDraw"
    private let sharedFolderName = "SharedImages"
    private let supportedImageTypes: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
    
    // UI Elements
    private var containerView: UIView!
    private var imagePreview: UIImageView!
    private var titleLabel: UILabel!
    private var statusLabel: UILabel!
    private var saveButton: UIButton!
    private var cancelButton: UIButton!
    private var progressView: UIProgressView!
    private var activityIndicator: UIActivityIndicatorView!
    
    private var previewImage: UIImage?
    private var isProcessing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedContent()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // 创建容器视图
        containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // 标题
        titleLabel = UILabel()
        titleLabel.text = "保存到 ShakeDraw"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 图片预览
        imagePreview = UIImageView()
        imagePreview.contentMode = .scaleAspectFit
        imagePreview.backgroundColor = UIColor.systemGray6
        imagePreview.layer.cornerRadius = 12
        imagePreview.layer.masksToBounds = true
        imagePreview.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imagePreview)
        
        // 状态标签
        statusLabel = UILabel()
        statusLabel.text = "正在加载预览..."
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // 进度条
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = UIColor.systemBlue
        progressView.isHidden = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(progressView)
        
        // 活动指示器
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(activityIndicator)
        
        // 按钮容器
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 取消按钮
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        cancelButton.setTitleColor(UIColor.systemRed, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray6
        cancelButton.layer.cornerRadius = 12
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        // 保存按钮
        saveButton = UIButton(type: .system)
        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.setTitleColor(UIColor.white, for: .normal)
        saveButton.backgroundColor = UIColor.systemBlue
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.isEnabled = false
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(saveButton)
        containerView.addSubview(buttonStack)
        
        // 约束
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 450),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // 图片预览
            imagePreview.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            imagePreview.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imagePreview.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            imagePreview.heightAnchor.constraint(equalToConstant: 200),
            
            // 状态标签
            statusLabel.topAnchor.constraint(equalTo: imagePreview.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // 进度条
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // 活动指示器
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            
            // 按钮
            buttonStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            buttonStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "UserCanceled", code: 0, userInfo: nil))
    }
    
    @objc private func saveTapped() {
        guard !isProcessing else { return }
        isProcessing = true
        
        updateUI(status: "正在保存...", showProgress: true, enableSave: false)
        
        // 直接保存内容，不依赖预览状态
        saveSharedContent { [weak self] success in
            DispatchQueue.main.async {
                self?.isProcessing = false
                if success {
                    self?.showSuccessAndDismiss()
                } else {
                    self?.showError()
                }
            }
        }
    }
    
    private func processSharedContent(completion: ((Bool) -> Void)? = nil) {
        guard let extensionContext = extensionContext else {
            completion?(false)
            return
        }
        
        let inputItems = extensionContext.inputItems as? [NSExtensionItem] ?? []
        
        if let completion = completion {
            // 用户点击保存按钮，真正保存内容
            processContent(inputItems) { success in
                completion(success)
            }
        } else {
            // 初始化时只加载预览，不保存
            loadPreviewImage(from: inputItems)
        }
    }
    
    // 新增：专门用于保存的方法，简化逻辑
    private func saveSharedContent(completion: @escaping (Bool) -> Void) {
        guard let extensionContext = extensionContext else {
            completion(false)
            return
        }
        
        let inputItems = extensionContext.inputItems as? [NSExtensionItem] ?? []
        processContent(inputItems) { success in
            completion(success)
        }
    }
    
    private func loadPreviewImage(from inputItems: [NSExtensionItem]) {
        // 扩大预览兼容性：按优先级尝试 public.image -> public.file-url -> public.url
        let providers: [NSItemProvider] = inputItems.compactMap { $0.attachments }.flatMap { $0 }
        guard !providers.isEmpty else {
            DispatchQueue.main.async { self.updateUI(status: "点击保存将内容添加到 ShakeDraw", showProgress: false, enableSave: true) }
            return
        }

        // 设置超时，避免无限等待
        var hasCompleted = false
        let timeout = DispatchWorkItem {
            guard !hasCompleted else { return }
            hasCompleted = true
            DispatchQueue.main.async { 
                self.updateUI(status: "点击保存将内容添加到 ShakeDraw", showProgress: false, enableSave: true) 
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: timeout)

        func tryNext(index: Int) {
            guard !hasCompleted else { return }
            
            if index >= providers.count {
                hasCompleted = true
                timeout.cancel()
                print("📄 所有预览尝试都失败，显示占位图")
                DispatchQueue.main.async { 
                    self.showPlaceholderPreview()
                }
                return
            }
            
            print("🔄 尝试提供者 \(index + 1)/\(providers.count)")
            attemptLoadPreview(from: providers[index]) { success in
                guard !hasCompleted else { return }
                if success { 
                    print("✅ 提供者 \(index + 1) 预览成功")
                    hasCompleted = true
                    timeout.cancel()
                    return 
                }
                print("❌ 提供者 \(index + 1) 预览失败，尝试下一个")
                tryNext(index: index + 1)
            }
        }

        tryNext(index: 0)
    }

    private func attemptLoadPreview(from provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        print("🔍 尝试加载预览，支持的类型：")
        print("  - image: \(provider.hasItemConformingToTypeIdentifier(UTType.image.identifier))")
        print("  - fileURL: \(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))")
        print("  - url: \(provider.hasItemConformingToTypeIdentifier(UTType.url.identifier))")
        
        // 1) 优先直接取 image
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            print("📸 尝试加载 UTType.image")
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                guard let self = self else { completion(false); return }
                
                if let error = error {
                    print("❌ 加载 image 类型失败: \(error)")
                    self.tryFileURLPreview(with: provider, completion: completion)
                    return
                }
                
                if let image = data as? UIImage {
                    print("✅ 直接获取到 UIImage")
                    DispatchQueue.main.async { self.showPreview(image: image) }
                    completion(true)
                    return
                }
                if let imageData = data as? Data, let image = UIImage(data: imageData) {
                    print("✅ 从 Data 转换为 UIImage")
                    DispatchQueue.main.async { self.showPreview(image: image) }
                    completion(true)
                    return
                }
                if let url = data as? URL {
                    print("🔗 从 image 类型获取到 URL: \(url)")
                    if url.isFileURL, let d = try? Data(contentsOf: url), let img = UIImage(data: d) {
                        print("✅ 从文件URL加载图片成功")
                        DispatchQueue.main.async { self.showPreview(image: img) }
                        completion(true)
                        return
                    }
                    if self.isLikelyImageURL(url) {
                        print("🌐 尝试从网络URL获取预览")
                        self.fetchPreviewImage(from: url) { img in
                            if let img = img { 
                                print("✅ 网络预览图加载成功")
                                DispatchQueue.main.async { self.showPreview(image: img) }; 
                                completion(true) 
                            } else { 
                                print("❌ 网络预览图加载失败")
                                completion(false) 
                            }
                        }
                        return
                    }
                }
                print("❌ image 类型未能提取图片，尝试其他类型")
                // 回退尝试其他类型
                self.tryFileURLPreview(with: provider, completion: completion)
            }
            return
        }
        // 2) 回退 file-url
        print("📁 回退到 fileURL 类型")
        tryFileURLPreview(with: provider, completion: completion)
    }

    private func tryFileURLPreview(with provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (data, _) in
                guard let self = self, let url = data as? URL else { completion(false); return }
                if url.isFileURL, let d = try? Data(contentsOf: url), let img = UIImage(data: d) {
                    DispatchQueue.main.async { self.showPreview(image: img) }
                    completion(true)
                } else if self.isLikelyImageURL(url) {
                    self.fetchPreviewImage(from: url) { img in
                        if let img = img { DispatchQueue.main.async { self.showPreview(image: img) }; completion(true) } else { completion(false) }
                    }
                } else {
                    self.tryURLPreview(with: provider, completion: completion)
                }
            }
        } else {
            tryURLPreview(with: provider, completion: completion)
        }
    }

    private func tryURLPreview(with provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            print("🌐 尝试从 URL 类型获取预览")
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                guard let self = self, let url = data as? URL else { 
                    print("❌ URL 类型加载失败")
                    completion(false)
                    return 
                }
                
                print("🔗 获取到 URL: \(url)")
                
                // 首先检查是否可能是图片URL
                if self.isLikelyImageURL(url) {
                    print("📸 URL 看起来像图片，尝试获取预览")
                    self.fetchPreviewImage(from: url) { img in
                        if let img = img { 
                            DispatchQueue.main.async { self.showPreview(image: img) }
                            completion(true) 
                        } else { 
                            print("❌ 从图片URL获取预览失败")
                            completion(false) 
                        }
                    }
                } else {
                    print("🌐 URL 不像图片，尝试通过 HEAD 请求检查")
                    // 尝试检查URL的Content-Type
                    self.checkContentType(for: url) { isImage in
                        if isImage {
                            print("✅ HEAD 请求确认是图片，获取预览")
                            self.fetchPreviewImage(from: url) { img in
                                if let img = img {
                                    DispatchQueue.main.async { self.showPreview(image: img) }
                                    completion(true)
                                } else {
                                    completion(false)
                                }
                            }
                        } else {
                            print("❌ 不是图片内容，预览失败")
                            completion(false)
                        }
                    }
                }
            }
        } else {
            print("❌ 不支持 URL 类型")
            completion(false)
        }
    }

    private func isLikelyImageURL(_ url: URL) -> Bool {
        if url.isFileURL { return true }
        let lower = url.absoluteString.lowercased()
        return supportedImageTypes.contains { ext in lower.contains(".\(ext)") }
    }

    private func fetchPreviewImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        print("🖼️ 开始获取预览图: \(url)")
        
        // 为预览设置较短的超时时间
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0  // 10秒超时
        request.cachePolicy = .returnCacheDataElseLoad  // 优先使用缓存
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 预览图获取失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ 预览图数据为空")
                completion(nil)
                return
            }
            
            print("✅ 预览图数据获取成功，大小: \(data.count) bytes")
            
            // 检查是否为图片数据
            guard let img = UIImage(data: data) else {
                print("❌ 数据无法转换为图片")
                completion(nil)
                return
            }
            
            // 为了预览性能，如果图片太大就缩小
            let maxSize: CGFloat = 300
            if img.size.width > maxSize || img.size.height > maxSize {
                let scaledImg = self.resizeImageForPreview(img, maxSize: maxSize)
                print("📏 图片已缩放用于预览: \(img.size) -> \(scaledImg?.size ?? CGSize.zero)")
                completion(scaledImg)
            } else {
                print("✅ 预览图加载完成: \(img.size)")
                completion(img)
            }
        }
        task.resume()
    }
    
    private func resizeImageForPreview(_ image: UIImage, maxSize: CGFloat) -> UIImage? {
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func showPreview(image: UIImage) {
        previewImage = image
        imagePreview.image = image
        updateUI(status: "点击保存将图片添加到 ShakeDraw", showProgress: false, enableSave: true)
    }
    
    private func showPlaceholderPreview() {
        // 创建一个简单的占位图
        let placeholderImage = createPlaceholderImage()
        imagePreview.image = placeholderImage
        updateUI(status: "点击保存将内容添加到 ShakeDraw", showProgress: false, enableSave: true)
    }
    
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 背景
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 图片图标
            let iconSize: CGFloat = 60
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2 - 10,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.systemGray3.setFill()
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 8)
            path.fill()
            
            // 文本
            let text = "图片"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.systemGray2
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: iconRect.maxY + 8,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func updateUI(status: String, showProgress: Bool, enableSave: Bool) {
        statusLabel.text = status
        progressView.isHidden = !showProgress
        saveButton.isEnabled = enableSave
        
        if showProgress {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        
        saveButton.backgroundColor = enableSave ? UIColor.systemBlue : UIColor.systemGray4
    }
    
    private func showSuccessAndDismiss() {
        statusLabel.text = "✅ 保存成功！"
        statusLabel.textColor = UIColor.systemGreen
        progressView.isHidden = true
        activityIndicator.stopAnimating()
        
        // 延迟关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func showError() {
        statusLabel.text = "❌ 保存失败，请重试"
        statusLabel.textColor = UIColor.systemRed
        progressView.isHidden = true
        activityIndicator.stopAnimating()
        saveButton.isEnabled = true
        saveButton.backgroundColor = UIColor.systemBlue
    }

    // MARK: - Content Processing (保持原有的处理逻辑)
    
    private func processContent(_ inputItems: [NSExtensionItem], completion: @escaping (Bool) -> Void) {
        print("🔍 开始处理内容，inputItems 数量: \(inputItems.count)")
        
        // 首先尝试处理直接的图片附件
        if hasImageAttachment(in: inputItems) {
            print("📸 发现图片附件，开始处理")
            processImageAttachments(inputItems, completion: completion)
            return
        }
        
        // 如果没有直接图片，尝试从网页内容提取
        if hasWebContent(in: inputItems) {
            print("🌐 发现网页内容，尝试提取图片")
            processWebContent(inputItems, completion: completion)
            return
        }
        
        print("❌ 未找到可处理的内容")
        completion(false)
    }
    
    private func hasImageAttachment(in inputItems: [NSExtensionItem]) -> Bool {
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                   attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    print("🔍 发现附件类型: image=\(attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier)), fileURL=\(attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))")
                    return true
                }
            }
        }
        return false
    }
    
    private func hasWebContent(in inputItems: [NSExtensionItem]) -> Bool {
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                   attachment.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    return true
                }
            }
        }
        return false
    }
    
    private func processImageAttachments(_ inputItems: [NSExtensionItem], completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        // 任一图片保存成功即视为成功，避免被无关失败覆盖
        var hadAtLeastOneSuccess = false
        var processedCount = 0
        var totalCount = 0
        
        // 计算总数
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                   attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    totalCount += 1
                }
            }
        }
        
        print("📊 总共需要处理 \(totalCount) 个图片附件")
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                        defer { 
                            group.leave()
                            processedCount += 1
                            DispatchQueue.main.async {
                                if totalCount > 0 {
                                    self?.progressView.progress = Float(processedCount) / Float(totalCount)
                                }
                            }
                        }
                        
                        if let error = error {
                            print("❌ 加载图片失败: \(error)")
                            return
                        }
                        
                        guard let self = self else { return }
                        
                        var success = false
                        if let imageData = data as? Data {
                            print("📱 处理 Data 类型图片，大小: \(imageData.count) bytes")
                            success = self.saveImageData(imageData)
                        } else if let imageURL = data as? URL {
                            print("🔗 处理 URL 类型图片: \(imageURL)")
                            success = self.saveImageFromURL(imageURL)
                        } else if let image = data as? UIImage {
                            print("🖼️ 处理 UIImage 类型图片，尺寸: \(image.size)")
                            success = self.saveUIImage(image)
                        } else {
                            print("⚠️ 未识别的图片数据类型: \(type(of: data))")
                        }
                        
                        if success { 
                            hadAtLeastOneSuccess = true
                            print("✅ 成功保存一张图片")
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    group.enter()
                    
                    attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (data, error) in
                        defer { 
                            group.leave()
                            processedCount += 1
                            DispatchQueue.main.async {
                                if totalCount > 0 {
                                    self?.progressView.progress = Float(processedCount) / Float(totalCount)
                                }
                            }
                        }
                        
                        if let error = error {
                            print("❌ 加载文件URL失败: \(error)")
                            return
                        }
                        
                        guard let self = self, let fileURL = data as? URL else { return }
                        
                        print("📁 处理文件URL: \(fileURL)")
                        let success = self.saveImageFromURL(fileURL)
                        
                        if success { 
                            hadAtLeastOneSuccess = true
                            print("✅ 成功保存一张图片")
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .global()) {
            print("🎯 图片处理完成，成功: \(hadAtLeastOneSuccess)")
            completion(hadAtLeastOneSuccess)
        }
    }
    
    private func saveImageData(_ data: Data) -> Bool {
        // 检测图片格式并保存
        let format = detectImageFormat(from: data)
        return saveImageData(data, withFormat: format)
    }
    
    private func saveImageFromURL(_ url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            return saveImageData(data)
        } catch {
            print("❌ 从URL读取图片失败: \(error)")
            return false
        }
    }
    
    private func saveUIImage(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            print("❌ 转换UIImage为JPEG失败")
            return false
        }
        return saveImageData(data)
    }
    
    private func getSharedImagesURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ 无法访问App Group容器: \(appGroupIdentifier)")
            return nil
        }
        
        let sharedURL = containerURL.appendingPathComponent(sharedFolderName, isDirectory: true)
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: sharedURL.path) {
            do {
                try FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ 创建共享目录: \(sharedURL.path)")
            } catch {
                print("❌ 创建共享目录失败: \(error)")
                return nil
            }
        }
        
        return sharedURL
    }
    
    private func detectImageFormat(from data: Data) -> String {
        guard data.count > 4 else { return "jpg" }
        
        let bytes = data.prefix(12)
        let header = Array(bytes)
        
        // PNG
        if header.count >= 8 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "png"
        }
        
        // JPEG
        if header.count >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "jpg"
        }
        
        // GIF
        if header.count >= 6 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 {
            return "gif"
        }
        
        // HEIC
        if header.count >= 12 {
            let heicSignature: [UInt8] = [0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63] // "ftypheic"
            let offset4 = Array(header[4...11])
            if offset4 == heicSignature {
                return "heic"
            }
        }
        
        // WebP
        if header.count >= 12 && header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            let webpSignature: [UInt8] = [0x57, 0x45, 0x42, 0x50] // "WEBP"
            let offset8 = Array(header[8...11])
            if offset8 == webpSignature {
                return "webp"
            }
        }
        
        // 默认使用 jpg
        return "jpg"
    }
    
    private func generateFileName(with extension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let random = Int.random(in: 1000...9999)
        return "IMG_\(timestamp)_\(random).\(`extension`)"
    }
    
    private func processWebContent(_ inputItems: [NSExtensionItem], completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var overallSuccess = false
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // 处理URL类型
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                        guard let self = self, let url = data as? URL else { 
                            group.leave()
                            return 
                        }
                        
                        // 尝试下载网页中的图片
                        self.downloadImageFromURL(url) { success in
                            if success { overallSuccess = true }
                            print("📄 URL处理完成，成功: \(success)")
                            group.leave()
                        }
                    }
                }
                
                // 处理网页数据
                if attachment.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] (data, error) in
                        guard let self = self else { 
                            group.leave()
                            return 
                        }
                        
                        if let dict = data as? [String: Any],
                           let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
                           let urlString = results["URL"] as? String,
                           let url = URL(string: urlString) {
                            
                            // 从网页URL下载图片
                            self.downloadImageFromURL(url) { success in
                                if success { overallSuccess = true }
                                print("📋 PropertyList处理完成，成功: \(success)")
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .global()) {
            completion(overallSuccess)
        }
    }
    
    private func downloadImageFromURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        print("🔗 开始处理URL: \(url)")
        
        // 检查URL是否指向图片
        let urlString = url.absoluteString.lowercased()
        let hasImageExtension = supportedImageTypes.contains { ext in
            urlString.hasSuffix(".\(ext)")
        }
        
        if hasImageExtension {
            print("📸 检测到图片URL，直接下载")
            // 直接下载图片
            downloadImage(from: url, completion: completion)
        } else {
            print("🌐 检测到可能的图片URL，先检查Content-Type")
            // 先发送HEAD请求检查Content-Type，避免不必要的完整下载
            checkContentType(for: url) { [weak self] isImage in
                if isImage {
                    print("✅ 确认是图片内容，直接下载")
                    self?.downloadImage(from: url, completion: completion)
                } else {
                    print("📄 不是图片内容，尝试提取网页图片")
                    self?.extractImageFromWebPage(url: url, completion: completion)
                }
            }
        }
    }
    
    private func checkContentType(for url: URL, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"  // 只获取头部信息，不下载内容
        request.timeoutInterval = 5.0  // 5秒超时
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") else {
                print("❌ HEAD请求失败，回退到完整请求")
                completion(false)
                return
            }
            
            let isImage = contentType.hasPrefix("image/")
            print("🔍 Content-Type检查结果: \(contentType), 是图片: \(isImage)")
            completion(isImage)
        }.resume()
    }
    
    private func downloadImage(from url: URL, completion: @escaping (Bool) -> Void) {
        print("⬇️ 开始下载图片: \(url)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0  // 10秒超时
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ 下载失败: error=\(error?.localizedDescription ?? "unknown"), status=\((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
                return
            }
            
            print("✅ 下载成功，数据大小: \(data.count) bytes")
            
            // 优先使用Content-Type确定格式，回退到数据检测
            var format = "jpg"  // 默认格式
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                format = self.formatFromContentType(contentType) ?? self.detectImageFormat(from: data)
                print("🎯 使用Content-Type确定格式: \(contentType) -> \(format)")
            } else {
                format = self.detectImageFormat(from: data)
                print("🔍 通过数据检测确定格式: \(format)")
            }
            
            let success = self.saveImageData(data, withFormat: format)
            print("💾 保存结果: \(success)")
            completion(success)
        }.resume()
    }
    
    private func formatFromContentType(_ contentType: String) -> String? {
        let lowerContentType = contentType.lowercased()
        
        if lowerContentType.contains("image/jpeg") || lowerContentType.contains("image/jpg") {
            return "jpg"
        } else if lowerContentType.contains("image/png") {
            return "png"
        } else if lowerContentType.contains("image/gif") {
            return "gif"
        } else if lowerContentType.contains("image/webp") {
            return "webp"
        } else if lowerContentType.contains("image/heic") {
            return "heic"
        } else if lowerContentType.contains("image/bmp") {
            return "bmp"
        } else if lowerContentType.contains("image/tiff") {
            return "tiff"
        }
        
        return nil  // 未识别的格式
    }
    
    private func saveImageData(_ data: Data, withFormat format: String) -> Bool {
        guard let sharedURL = getSharedImagesURL() else {
            print("❌ 无法获取共享目录")
            return false
        }
        
        let fileName = generateFileName(with: format)
        let fileURL = sharedURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL, options: [.atomic])
            // 排除备份（URL 是值类型，需要可变副本）
            var mutableURL = fileURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? mutableURL.setResourceValues(resourceValues)
            print("✅ 图片保存成功: \(fileName) @ \(fileURL.path)")
            return true
        } catch {
            print("❌ 保存图片失败: \(error)")
            return false
        }
    }
    
    private func extractImageFromWebPage(url: URL, completion: @escaping (Bool) -> Void) {
        print("🕷️ 开始提取网页图片: \(url)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0  // 8秒超时
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("❌ 网页加载失败: \(error?.localizedDescription ?? "unknown")")
                completion(false)
                return
            }
            
            // 检查返回的内容是否是图片
            if let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") {
                print("📄 Content-Type: \(contentType)")
                
                if contentType.hasPrefix("image/") {
                    print("🖼️ 发现直接的图片内容")
                    
                    // 使用Content-Type确定格式
                    let format = self.formatFromContentType(contentType) ?? self.detectImageFormat(from: data)
                    let success = self.saveImageData(data, withFormat: format)
                    completion(success)
                    return
                }
            }
            
            // 如果不是直接的图片，尝试解析HTML找到图片
            if let htmlString = String(data: data, encoding: .utf8) {
                print("📋 开始解析HTML，长度: \(htmlString.count)")
                self.extractImageURLsFromHTML(htmlString, baseURL: url) { imageURLs in
                    print("🔍 找到 \(imageURLs.count) 个图片URL")
                    guard let firstImageURL = imageURLs.first else {
                        print("❌ 未找到可用的图片URL")
                        completion(false)
                        return
                    }
                    
                    print("📸 尝试下载第一个图片: \(firstImageURL)")
                    self.downloadImage(from: firstImageURL) { success in
                        completion(success)
                    }
                }
            } else {
                print("❌ 无法解析HTML内容")
                completion(false)
            }
        }.resume()
    }
    
    private func extractImageURLsFromHTML(_ html: String, baseURL: URL, completion: @escaping ([URL]) -> Void) {
        // 简单的HTML图片提取（使用正则表达式）
        let pattern = #"<img[^>]+src\s*=\s*["\']([^"\']+)["\'][^>]*>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.count))
            
            var imageURLs: [URL] = []
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let urlString = String(html[range])
                    
                    // 处理相对URL
                    if let imageURL = URL(string: urlString, relativeTo: baseURL)?.absoluteURL {
                        // 检查是否是支持的图片格式
                        let urlStr = imageURL.absoluteString.lowercased()
                        if supportedImageTypes.contains(where: { ext in urlStr.contains(".\(ext)") }) {
                            imageURLs.append(imageURL)
                        }
                    }
                }
            }
            
            completion(imageURLs)
        } catch {
            print("❌ HTML解析失败: \(error)")
            completion([])
        }
    }
}
