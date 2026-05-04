import SwiftUI
import PDFKit
import Translation

struct PDFReaderView: View {
    let url: URL
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var fontSize: CGFloat = 16
    @State private var selectedText = ""
    @State private var showTranslation = false
    @State private var showPageTranslation = false
    @State private var pageText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // ツールバー
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }

                Spacer()

                // 文字サイズ調整
                HStack(spacing: 8) {
                    Button {
                        if fontSize > 12 { fontSize -= 2 }
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 20))
                    }
                    Button {
                        if fontSize < 28 { fontSize += 2 }
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 20))
                    }
                }

                // ページ翻訳ボタン
                Button {
                    extractPageText()
                    showPageTranslation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("翻訳")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            // PDFビュー
            PDFKitView(url: url, fontSize: fontSize, currentPage: $currentPage, totalPages: $totalPages, onTextSelected: { text in
                selectedText = text
                if !text.isEmpty {
                    showTranslation = true
                }
            })
            .ignoresSafeArea(edges: .horizontal)

            // ページナビゲーション
            if totalPages > 0 {
                HStack(spacing: 20) {
                    Button {
                        if currentPage > 0 { currentPage -= 1 }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(currentPage > 0 ? .blue : .gray)
                    }
                    .disabled(currentPage == 0)

                    Text("\(currentPage + 1) / \(totalPages)")
                        .font(.system(size: 18, weight: .bold))

                    Button {
                        if currentPage < totalPages - 1 { currentPage += 1 }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(currentPage < totalPages - 1 ? .blue : .gray)
                    }
                    .disabled(currentPage == totalPages - 1)
                }
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }

            BannerAdView()
                .frame(height: 50)
        }
        .navigationBarHidden(true)
        // 選択テキスト翻訳
        .sheet(isPresented: $showTranslation) {
            TranslationSheet(text: selectedText, title: "選択した文を翻訳")
        }
        // ページ全体翻訳
        .sheet(isPresented: $showPageTranslation) {
            TranslationSheet(text: pageText, title: "このページを翻訳")
        }
    }

    private func extractPageText() {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: currentPage) else { return }
        pageText = page.string ?? ""
    }
}

// MARK: - PDFKit UIViewRepresentable
struct PDFKitView: UIViewRepresentable {
    let url: URL
    let fontSize: CGFloat
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    let onTextSelected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = UIColor.systemBackground

        if let document = PDFDocument(url: url) {
            pdfView.document = document
            DispatchQueue.main.async {
                totalPages = document.pageCount
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // 長押しで翻訳メニュー
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        pdfView.addGestureRecognizer(longPress)

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }
        if let page = document.page(at: currentPage), pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: page)
            DispatchQueue.main.async {
                self.parent.currentPage = index
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let pdfView = gesture.view as? PDFView else { return }
            if let selection = pdfView.currentSelection, let text = selection.string, !text.isEmpty {
                DispatchQueue.main.async {
                    self.parent.onTextSelected(text)
                }
            }
        }
    }
}

// MARK: - 翻訳シート
struct TranslationSheet: View {
    let text: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var showTranslation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if text.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("テキストが見つかりませんでした")
                            .font(.system(size: 20))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("原文")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)

                            Text(text)
                                .font(.system(size: 18))
                                .padding(16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        .padding(20)
                    }
                    .translationPresentation(isPresented: $showTranslation, text: text)

                    Button {
                        showTranslation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text("日本語に翻訳する")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(20)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 18))
                }
            }
        }
    }
}
