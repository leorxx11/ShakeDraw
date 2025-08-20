import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var folderManager: FolderManager
    @State private var showImporter = false

    var body: some View {
        List {
            Section(header:
                        Label("已导入的文件夹", systemImage: "folder.fill").font(.headline)
            , footer:
                        Text("左划删除文件夹 · 开关控制是否参与抽签")
                        .font(.footnote)
                        .foregroundColor(.secondary)
            ) {
                if folderManager.folders.isEmpty {
                    VStack(spacing: 8) {
                        Text("尚未添加任何文件夹")
                            .foregroundColor(.secondary)
                        Text("点击右上角“+”导入")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else {
                    ForEach(folderManager.folders) { folder in
                        HStack(spacing: 12) {
                            Image(systemName: folder.includeInDraw ? "folder.fill" : "folder")
                                .foregroundColor(folder.includeInDraw ? .blue : .secondary)
                                .font(.system(size: 18, weight: .semibold))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.displayName ?? (URL(fileURLWithPath: folder.lastResolvedPath).lastPathComponent))
                                    .font(.body)
                                HStack(spacing: 6) {
                                    Image(systemName: folder.includeInDraw ? "checkmark.circle.fill" : "slash.circle")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(folder.includeInDraw ? "参与抽签" : "已排除")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(folder.includeInDraw ? Color.green : Color.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill((folder.includeInDraw ? Color.green.opacity(0.12) : Color.secondary.opacity(0.10)))
                                )
                            }
                            Spacer()
                            Toggle("加入抽签", isOn: includeBinding(for: folder.id))
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        folderManager.removeFolders(at: offsets)
                    }
                }
            }
            
            if !folderManager.folders.isEmpty {
                Section {
                    Button(role: .destructive, action: { folderManager.clearAllFolders() }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("清空所有文件夹")
                                Text("仅移除访问配置，不会删除磁盘上的文件")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showImporter = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
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
        .listStyle(.insetGrouped)
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
