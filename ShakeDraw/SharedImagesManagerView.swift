import SwiftUI
import Photos

struct SharedImagesManagerView: View {
    @ObservedObject var folderManager: FolderManager
    @State private var sharedImages: [SharedImageItem] = []
    @State private var selectedImages: Set<UUID> = []
    @State private var isLoading = true
    @State private var showingDeleteAlert = false
    @State private var showingExportAlert = false
    @State private var isSelectionMode = false
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if sharedImages.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("共享图片")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !sharedImages.isEmpty {
                        Button(isSelectionMode ? "取消" : "选择") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedImages.removeAll()
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadSharedImages()
            }
            .alert("导出成功", isPresented: $showingExportAlert) {
                Button("确定") { }
            } message: {
                Text("选中的图片已成功保存到相册")
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载共享图片...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            Text("还没有共享图片")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("从相册或其他应用分享图片到 ShakeDraw\n即可在这里管理")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(40)
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // 统计信息
            if !isSelectionMode {
                statisticsBar
            }
            
            // 选择模式工具栏
            if isSelectionMode {
                selectionToolbar
            }
            
            // 图片网格
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sharedImages) { image in
                        SharedImageCell(
                            image: image,
                            isSelected: selectedImages.contains(image.id),
                            isSelectionMode: isSelectionMode
                        ) {
                            if isSelectionMode {
                                toggleSelection(for: image.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var statisticsBar: some View {
        HStack {
            Label("\(sharedImages.count) 张图片", systemImage: "photo.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(formatFileSize(totalFileSize))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private var selectionToolbar: some View {
        HStack {
            Button("全选") {
                if selectedImages.count == sharedImages.count {
                    selectedImages.removeAll()
                } else {
                    selectedImages = Set(sharedImages.map { $0.id })
                }
            }
            .disabled(sharedImages.isEmpty)
            
            Spacer()
            
            Text("\(selectedImages.count) 已选择")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: exportSelectedImages) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(selectedImages.isEmpty)
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(selectedImages.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .alert("删除图片", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteSelectedImages()
            }
        } message: {
            Text("确定要删除选中的 \(selectedImages.count) 张图片吗？此操作无法撤销。")
        }
    }
    
    private var totalFileSize: Int64 {
        sharedImages.reduce(0) { $0 + $1.fileSize }
    }
    
    // MARK: - 功能方法
    
    private func loadSharedImages() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sharedURL = getSharedImagesURL() else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: sharedURL,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                let supportedExtensions = Set(["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"])
                let imageURLs = fileURLs.filter { url in
                    supportedExtensions.contains(url.pathExtension.lowercased())
                }
                
                var imageItems: [SharedImageItem] = []
                
                for url in imageURLs {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let item = SharedImageItem(
                        id: UUID(),
                        url: url,
                        filename: url.lastPathComponent,
                        fileSize: Int64(fileSize),
                        creationDate: creationDate
                    )
                    imageItems.append(item)
                }
                
                // 按创建时间倒序排列
                imageItems.sort { $0.creationDate > $1.creationDate }
                
                DispatchQueue.main.async {
                    self.sharedImages = imageItems
                    self.isLoading = false
                }
                
            } catch {
                print("❌ 加载共享图片失败: \(error)")
                DispatchQueue.main.async {
                    self.sharedImages = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedImages.contains(id) {
            selectedImages.remove(id)
        } else {
            selectedImages.insert(id)
        }
    }
    
    private func deleteSelectedImages() {
        let imagesToDelete = sharedImages.filter { selectedImages.contains($0.id) }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for image in imagesToDelete {
                try? FileManager.default.removeItem(at: image.url)
            }
            
            DispatchQueue.main.async {
                self.loadSharedImages()
                self.selectedImages.removeAll()
                self.isSelectionMode = false
                self.folderManager.refreshFolderCounts()
            }
        }
    }
    
    private func exportSelectedImages() {
        requestPhotoLibraryPermission { granted in
            if granted {
                let imagesToExport = sharedImages.filter { selectedImages.contains($0.id) }
                exportImagesToPhotoLibrary(imagesToExport)
            }
        }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    private func exportImagesToPhotoLibrary(_ images: [SharedImageItem]) {
        PHPhotoLibrary.shared().performChanges({
            for image in images {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: image.url)
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showingExportAlert = true
                    self.selectedImages.removeAll()
                    self.isSelectionMode = false
                } else {
                    print("❌ 导出图片到相册失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    private func getSharedImagesURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.leorxx.ShakeDraw") else {
            return nil
        }
        return containerURL.appendingPathComponent("SharedImages", isDirectory: true)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SharedImageItem: Identifiable {
    let id: UUID
    let url: URL
    let filename: String
    let fileSize: Int64
    let creationDate: Date
}

struct SharedImageCell: View {
    let image: SharedImageItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Group {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 选择状态覆盖层
            if isSelectionMode {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isSelected ? .blue : .white)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.white : Color.black.opacity(0.3))
                                    .frame(width: 24, height: 24)
                            )
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageData = try? Data(contentsOf: image.url),
                  let uiImage = UIImage(data: imageData) else {
                return
            }
            
            // 生成缩略图
            let targetSize = CGSize(width: 150, height: 150)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let thumbnailImage = renderer.image { _ in
                uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
            DispatchQueue.main.async {
                self.thumbnail = thumbnailImage
            }
        }
    }
}

#Preview {
    SharedImagesManagerView(folderManager: FolderManager())
}