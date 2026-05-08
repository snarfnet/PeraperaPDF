import SwiftUI
import PhotosUI
import WebKit

struct PDFCreatorView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("文章").tag(0)
                Text("写真").tag(1)
                Text("Web").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(16)

            TabView(selection: $selectedTab) {
                TextToPDFView().tag(0)
                PhotosToPDFView().tag(1)
                WebToPDFView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            BannerAdView()
                .frame(height: 50)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("PDFを作る")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TextToPDFView: View {
    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var pdfURL: URL? = nil
    @State private var showShare = false

    private var canCreatePDF: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "1. タイトル", subtitle: "空欄でも作れます")
                TextField("例：旅行のメモ", text: $titleText)
                    .font(.system(size: 21, weight: .bold))
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                SectionHeader(title: "2. 本文", subtitle: "ここに文章を入れてください")
                TextEditor(text: $bodyText)
                    .font(.system(size: 20))
                    .lineSpacing(5)
                    .frame(minHeight: 260)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    generatePDF()
                } label: {
                    Label("PDFを作成して共有", systemImage: "doc.badge.plus")
                        .font(.system(size: 21, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canCreatePDF ? .indigo : .gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canCreatePDF)
            }
            .padding(18)
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(url: url)
            }
        }
    }

    private func generatePDF() {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let margin: CGFloat = 48
        let bodyChunks = chunked(bodyText, maxLength: 1800)

        let data = renderer.pdfData { ctx in
            if bodyChunks.isEmpty {
                drawPage(ctx: ctx, pageRect: pageRect, margin: margin, title: titleText, body: "")
            } else {
                for (index, chunk) in bodyChunks.enumerated() {
                    drawPage(
                        ctx: ctx,
                        pageRect: pageRect,
                        margin: margin,
                        title: index == 0 ? titleText : "",
                        body: chunk
                    )
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("text_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        pdfURL = url
        showShare = true
    }

    private func drawPage(
        ctx: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        margin: CGFloat,
        title: String,
        body: String
    ) {
        ctx.beginPage()
        var y = margin

        if !title.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            NSAttributedString(string: title, attributes: attrs)
                .draw(in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 60))
            y += 64

            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: y))
            line.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.systemGray3.setStroke()
            line.lineWidth = 0.7
            line.stroke()
            y += 18
        }

        guard !body.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: body, attributes: attrs)
            .draw(in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: pageRect.height - y - margin))
    }

    private func chunked(_ text: String, maxLength: Int) -> [String] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return [] }

        var chunks: [String] = []
        var start = cleanText.startIndex
        while start < cleanText.endIndex {
            let end = cleanText.index(start, offsetBy: maxLength, limitedBy: cleanText.endIndex) ?? cleanText.endIndex
            chunks.append(String(cleanText[start..<end]))
            start = end
        }
        return chunks
    }
}

struct PhotosToPDFView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isLoading = false
    @State private var pdfURL: URL? = nil
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.indigo)

                        Text(images.isEmpty ? "写真を選ぶ" : "写真を選び直す")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.indigo)

                        Text("最大30枚まで。選んだ順番でPDFにします。")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if isLoading {
                    ProgressView("写真を読み込み中")
                        .font(.system(size: 18, weight: .semibold))
                        .padding()
                }

                if !images.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 6
                    ) {
                        ForEach(images.indices, id: \.self) { i in
                            Image(uiImage: images[i])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 118)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    Button {
                        generatePDF()
                    } label: {
                        Label("PDFを作成して共有（\(images.count)枚）", systemImage: "doc.badge.plus")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isLoading ? .gray : .indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isLoading)
                }
            }
            .padding(18)
        }
        .onChange(of: selectedItems) { _, items in
            loadImages(from: items)
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(url: url)
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        images = []
        isLoading = true
        Task {
            var loaded: [(Int, UIImage)] = []
            for (index, item) in items.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append((index, image))
                }
            }
            await MainActor.run {
                images = loaded.sorted { $0.0 < $1.0 }.map { $0.1 }
                isLoading = false
            }
        }
    }

    private func generatePDF() {
        isLoading = true
        let sourceImages = images
        DispatchQueue.global(qos: .userInitiated).async {
            let pageSize = CGSize(width: 595, height: 842)
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
            let data = renderer.pdfData { ctx in
                for image in sourceImages {
                    ctx.beginPage()
                    let imgRatio = image.size.width / image.size.height
                    let pageRatio = pageSize.width / pageSize.height
                    let drawRect: CGRect
                    if imgRatio > pageRatio {
                        let height = pageSize.width / imgRatio
                        drawRect = CGRect(x: 0, y: (pageSize.height - height) / 2, width: pageSize.width, height: height)
                    } else {
                        let width = pageSize.height * imgRatio
                        drawRect = CGRect(x: (pageSize.width - width) / 2, y: 0, width: width, height: pageSize.height)
                    }
                    image.draw(in: drawRect)
                }
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("photos_\(Int(Date().timeIntervalSince1970)).pdf")
            try? data.write(to: url)
            DispatchQueue.main.async {
                pdfURL = url
                isLoading = false
                showShare = true
            }
        }
    }
}

struct WebToPDFView: View {
    @State private var urlString = ""
    @State private var isPageLoading = false
    @State private var isExporting = false
    @State private var showWebView = false
    @State private var pdfURL: URL? = nil
    @State private var showShare = false
    @State private var webView: WKWebView? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("例：https://example.com", text: $urlString)
                    .font(.system(size: 19))
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    loadPage()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                }
                .accessibilityLabel("Webページを開く")
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if showWebView, let url = normalizedURL {
                ZStack(alignment: .top) {
                    WebViewRepresentable(
                        url: url,
                        isLoading: $isPageLoading,
                        onWebViewCreated: { webView = $0 }
                    )

                    if isPageLoading {
                        ProgressView("読み込み中")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(10)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 10)
                    }
                }

                Button {
                    exportToPDF()
                } label: {
                    Label(isExporting ? "PDFに変換中" : "このページをPDFにする", systemImage: "doc.badge.plus")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(isPageLoading || isExporting ? .gray : .indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                }
                .disabled(isPageLoading || isExporting)
            } else {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "safari")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.45))

                    Text("URLを入れて、右の矢印を押してください。")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(url: url)
            }
        }
    }

    private var normalizedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
    }

    private func loadPage() {
        guard normalizedURL != nil else { return }
        showWebView = true
    }

    private func exportToPDF() {
        guard let webView else { return }
        isExporting = true
        webView.createPDF { result in
            DispatchQueue.main.async {
                isExporting = false
                if case .success(let data) = result {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("web_\(Int(Date().timeIntervalSince1970)).pdf")
                    try? data.write(to: url)
                    pdfURL = url
                    showShare = true
                }
            }
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let onWebViewCreated: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        onWebViewCreated(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold))

            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
