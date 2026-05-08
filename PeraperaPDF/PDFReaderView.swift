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
            toolbar

            PDFKitView(
                url: url,
                fontSize: fontSize,
                currentPage: $currentPage,
                totalPages: $totalPages,
                onTextSelected: { text in
                    selectedText = text
                    showTranslation = !text.isEmpty
                }
            )
            .ignoresSafeArea(edges: .horizontal)

            if totalPages > 0 {
                pageControls
            }

            BannerAdView()
                .frame(height: 50)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showTranslation) {
            TranslationSheet(text: selectedText, title: "選択した文章を翻訳")
        }
        .sheet(isPresented: $showPageTranslation) {
            TranslationSheet(text: pageText, title: "このページを翻訳")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("戻る")

            VStack(alignment: .leading, spacing: 2) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)

                Text(totalPages > 0 ? "\(currentPage + 1) / \(totalPages) ページ" : "PDFを読み込み中")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if fontSize > 12 { fontSize -= 2 }
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("文字を小さく")

            Button {
                if fontSize < 28 { fontSize += 2 }
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("文字を大きく")

            Button {
                extractPageText()
                showPageTranslation = true
            } label: {
                Label("翻訳", systemImage: "globe")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var pageControls: some View {
        HStack(spacing: 18) {
            Button {
                if currentPage > 0 { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(currentPage > 0 ? .indigo : .gray.opacity(0.45))
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("前のページ")

            Text("\(currentPage + 1) / \(totalPages)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .frame(minWidth: 84)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())

            Button {
                if currentPage < totalPages - 1 { currentPage += 1 }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(currentPage < totalPages - 1 ? .indigo : .gray.opacity(0.45))
            }
            .disabled(currentPage == totalPages - 1)
            .accessibilityLabel("次のページ")
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private func extractPageText() {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: currentPage) else {
            pageText = ""
            return
        }
        pageText = page.string ?? ""
    }
}

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
        pdfView.backgroundColor = UIColor.systemGroupedBackground

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

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
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
                  let pdfView = gesture.view as? PDFView,
                  let selection = pdfView.currentSelection,
                  let text = selection.string,
                  !text.isEmpty else { return }
            DispatchQueue.main.async {
                self.parent.onTextSelected(text)
            }
        }
    }
}

struct TranslationSheet: View {
    let text: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var showTranslation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if text.isEmpty {
                    ContentUnavailableView(
                        "テキストが見つかりません",
                        systemImage: "exclamationmark.circle",
                        description: Text("画像だけのPDFでは、翻訳できる文章がない場合があります。")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("原文")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)

                            Text(text)
                                .font(.system(size: 17))
                                .lineSpacing(4)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(20)
                    }
                    .modifier(TranslationViewModifier(isPresented: $showTranslation, text: text))

                    Button {
                        showTranslation = true
                    } label: {
                        Label("日本語に翻訳", systemImage: "globe")
                            .font(.system(size: 19, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(20)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.4, *)
private struct TranslationViewModifierAvailable: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    func body(content: Content) -> some View {
        content.translationPresentation(isPresented: $isPresented, text: text)
    }
}

private struct TranslationViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content.modifier(TranslationViewModifierAvailable(isPresented: $isPresented, text: text))
        } else {
            content
        }
    }
}
