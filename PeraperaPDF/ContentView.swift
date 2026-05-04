import SwiftUI

struct ContentView: View {
    @State private var pdfURL: URL?
    @State private var showFilePicker = false
    @State private var recentFiles: [URL] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)
                            Text("ぺらぺらPDF")
                                .font(.system(size: 32, weight: .bold))
                            Text("PDFを開いて、かんたん翻訳")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)

                        // ファイルを開くボタン
                        Button {
                            showFilePicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 24))
                                Text("PDFを開く")
                                    .font(.system(size: 22, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                        }

                        // 最近開いたファイル
                        if !recentFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("最近開いたファイル")
                                    .font(.system(size: 20, weight: .bold))
                                    .padding(.horizontal, 24)

                                ForEach(recentFiles, id: \.self) { url in
                                    NavigationLink(destination: PDFReaderView(url: url)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "doc.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                            Text(url.lastPathComponent)
                                                .font(.system(size: 18))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(16)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                }

                BannerAdView()
                    .frame(height: 50)
            }
            .navigationBarHidden(true)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                addRecentFile(url)
                pdfURL = url
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { pdfURL != nil },
            set: { if !$0 { pdfURL = nil } }
        )) {
            if let url = pdfURL {
                PDFReaderView(url: url)
            }
        }
        .onAppear {
            loadRecentFiles()
        }
    }

    private func addRecentFile(_ url: URL) {
        var saved = UserDefaults.standard.stringArray(forKey: "recentFiles") ?? []
        let path = url.absoluteString
        saved.removeAll { $0 == path }
        saved.insert(path, at: 0)
        if saved.count > 5 { saved = Array(saved.prefix(5)) }
        UserDefaults.standard.set(saved, forKey: "recentFiles")
        loadRecentFiles()
    }

    private func loadRecentFiles() {
        let saved = UserDefaults.standard.stringArray(forKey: "recentFiles") ?? []
        recentFiles = saved.compactMap { URL(string: $0) }
    }
}
