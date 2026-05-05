import SwiftUI
import PhotosUI
import WebKit

// MARK: - メイン作成画面

struct PDFCreatorView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("テキスト").tag(0)
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
        .navigationTitle("PDFを作成")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - テキスト -> PDF

struct TextToPDFView: View {
    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var pdfURL: URL? = nil
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("タイトル")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("タイトルを入力", text: $titleText)
                    .font(.system(size: 18, weight: .bold))
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                Text("本文")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                TextEditor(text: $bodyText)
                    .font(.system(size: 16))
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                Button {
                    generatePDF()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.arrow.up")
                        Text("PDFを生成")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(titleText.isEmpty && bodyText.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(titleText.isEmpty && bodyText.isEmpty)
            }
            .padding(16)
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
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let margin: CGFloat = 48
            var y = margin

            if !titleText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 22),
                    .foregroundColor: UIColor.black
                ]
                NSAttributedString(string: titleText, attributes: attrs)
                    .draw(in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 50))
                y += 56
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y))
                line.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                UIColor.lightGray.setStroke()
                line.lineWidth = 0.5
                line.stroke()
                y += 16
            }

            if !bodyText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]
                NSAttributedString(string: bodyText, attributes: attrs)
                    .draw(in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: pageRect.height - y - margin))
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("text_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        pdfURL = url
        showShare = true
    }
}

// MARK: - 写真 -> PDF

struct PhotosToPDFView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isLoading = false
    @State private var pdfURL: URL? = nil
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text(images.isEmpty ? "写真を選ぶ" : "写真を変更する")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("最大30枚")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                if !images.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 4
                    ) {
                        ForEach(images.indices, id: \.self) { i in
                            Image(uiImage: images[i])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 110)
                                .clipped()
                                .cornerRadius(6)
                        }
                    }

                    Button {
                        generatePDF()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "doc.badge.arrow.up")
                            }
                            Text(isLoading ? "生成中..." : "PDFを生成（\(images.count)枚）")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(16)
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
        var loaded: [(Int, UIImage)] = []
        let group = DispatchGroup()
        for (i, item) in items.enumerated() {
            group.enter()
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let img = UIImage(data: data) {
                    loaded.append((i, img))
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            images = loaded.sorted { $0.0 < $1.0 }.map { $0.1 }
            isLoading = false
        }
    }

    private func generatePDF() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let pageSize = CGSize(width: 595, height: 842)
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
            let data = renderer.pdfData { ctx in
                for image in images {
                    ctx.beginPage()
                    let imgRatio = image.size.width / image.size.height
                    let pageRatio = pageSize.width / pageSize.height
                    let drawRect: CGRect
                    if imgRatio > pageRatio {
                        let h = pageSize.width / imgRatio
                        drawRect = CGRect(x: 0, y: (pageSize.height - h) / 2, width: pageSize.width, height: h)
                    } else {
                        let w = pageSize.height * imgRatio
                        drawRect = CGRect(x: (pageSize.width - w) / 2, y: 0, width: w, height: pageSize.height)
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

// MARK: - Web -> PDF

struct WebToPDFView: View {
    @State private var urlString = "https://"
    @State private var isPageLoading = false
    @State private var isExporting = false
    @State private var showWebView = false
    @State private var pdfURL: URL? = nil
    @State private var showShare = false
    @State private var webView: WKWebView? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
                TextField("URLを入力", text: $urlString)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button {
                    loadPage()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            if showWebView, let url = URL(string: urlString) {
                ZStack(alignment: .top) {
                    WebViewRepresentable(
                        url: url,
                        isLoading: $isPageLoading,
                        onWebViewCreated: { wv in webView = wv }
                    )
                    if isPageLoading {
                        ProgressView()
                            .padding(8)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                            .padding(.top, 8)
                    }
                }

                Button {
                    exportToPDF()
                } label: {
                    HStack(spacing: 8) {
                        if isExporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "doc.badge.arrow.up")
                        }
                        Text(isExporting ? "変換中..." : "このページをPDFに変換")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isPageLoading || isExporting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
                .disabled(isPageLoading || isExporting)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "safari")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("URLを入力して矢印を押してください")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.top, 16)
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(url: url)
            }
        }
    }

    private func loadPage() {
        guard URL(string: urlString) != nil else { return }
        showWebView = true
    }

    private func exportToPDF() {
        guard let wv = webView else { return }
        isExporting = true
        wv.createPDF { result in
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
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        onWebViewCreated(wv)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ parent: WebViewRepresentable) { self.parent = parent }
        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) { parent.isLoading = true }
        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) { parent.isLoading = false }
        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError _: Error) { parent.isLoading = false }
    }
}

// MARK: - 共有シート

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
