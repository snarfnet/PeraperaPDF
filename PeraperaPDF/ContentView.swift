import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OpenPDFView()
                .tabItem {
                    Label("読む", systemImage: "doc.text.magnifyingglass")
                }
                .tag(0)

            NavigationStack {
                PDFCreatorView()
            }
            .tabItem {
                Label("作る", systemImage: "doc.badge.plus")
            }
            .tag(1)
        }
        .tint(.indigo)
    }
}

struct OpenPDFView: View {
    @State private var pdfURL: URL?
    @State private var showFilePicker = false
    @State private var recentFiles: [URL] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero

                        Button {
                            showFilePicker = true
                        } label: {
                            Label("PDFを開く", systemImage: "folder.badge.plus")
                                .font(.system(size: 20, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(.indigo)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityHint("ファイルアプリからPDFを選びます")

                        featureStrip

                        GuideCard()

                        if !recentFiles.isEmpty {
                            recentSection
                        }
                    }
                    .padding(20)
                }

                BannerAdView()
                    .frame(height: 50)
            }
            .background(Color(.systemGroupedBackground))
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
        .onAppear(perform: loadRecentFiles)
    }

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.16), Color.green.opacity(0.12), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 118, weight: .light))
                .foregroundStyle(.indigo.opacity(0.12))
                .padding(.trailing, 8)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("ぺらぺらPDF")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("PDFを開く、読む、作る。必要な文章は日本語に翻訳できます。")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
    }

    private var featureStrip: some View {
        HStack(spacing: 10) {
            FeaturePill(icon: "text.viewfinder", text: "選んで翻訳")
            FeaturePill(icon: "rectangle.stack.badge.plus", text: "PDF作成")
            FeaturePill(icon: "square.and.arrow.up", text: "すぐ共有")
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近開いたPDF")
                .font(.system(size: 20, weight: .bold))

            ForEach(recentFiles, id: \.self) { url in
                NavigationLink(destination: PDFReaderView(url: url)) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.red)
                            .frame(width: 34)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text("タップして再開")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
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

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.indigo)

            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct GuideCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("はじめての方へ", systemImage: "hand.point.up.left.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                GuideRow(number: "1", text: "PDFを開く")
                GuideRow(number: "2", text: "ページをめくる")
                GuideRow(number: "3", text: "必要な文章を翻訳")
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct GuideRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.green)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}
