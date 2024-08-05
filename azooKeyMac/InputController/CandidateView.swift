import SwiftUI
import Cocoa

private struct CandidatesView: View {
    init(candidatesViewState: CandidatesViewState, delegate: (any CandidatesViewControllerDelegate)? = nil) {
        self.candidatesViewState = candidatesViewState
        self.delegate = delegate
    }
    
    @ObservedObject private var candidatesViewState: CandidatesViewState
    private var delegate: CandidatesViewControllerDelegate?

    var body: some View {
        VStack {
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(0 ..< candidatesViewState.candidates.count, id: \.self) { index in
                            CandidateRow(
                                index: index,
                                candidate: candidatesViewState.candidates[index],
                                isSelected: index == candidatesViewState.currentSelectedRow
                            )
                                .onTapGesture {
                                    selectCandidate(at: index)
                                }
                                .tag(index)
                            Divider()
                        }
                    }
                    .onChange(of: candidatesViewState.currentSelectedRow) { newValue in
                        proxy.scrollTo(newValue)
                    }
                }
            }
        }
        .cornerRadius(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        }
        .onAppear {
            selectFirstCandidate()
        }
    }

    private func selectCandidate(at index: Int) {
        candidatesViewState.currentSelectedRow = index
        if candidatesViewState.candidates.indices.contains(index) {
            delegate?.candidateSelectionChanged(candidatesViewState.candidates[index])
        }
    }

    private func selectFirstCandidate() {
        guard !candidatesViewState.candidates.isEmpty else { return }
        candidatesViewState.currentSelectedRow = 0
        delegate?.candidateSelectionChanged(candidatesViewState.candidates[0])
    }
}

private struct CandidateRow: View {
    let index: Int
    let candidate: String
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.blue.opacity(0.9) : Color.clear)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .overlay {
                HStack {
                    Text(candidate)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .white : Color.primary)
                    Spacer()
                }
            }
    }
}

private class CandidatesViewState: ObservableObject {
    @Published var candidates: [String] = []
    @Published var currentSelectedRow: Int = -1
}

class CandidatesViewController: NSViewController {
    private var candidatesViewState = CandidatesViewState()
    weak var delegate: (any CandidatesViewControllerDelegate)?

    private var hostingController: NSHostingController<CandidatesView>!

    override func loadView() {
        hostingController = NSHostingController(
            rootView: CandidatesView(
                candidatesViewState: candidatesViewState,
                delegate: self.delegate
            )
        )
        self.view = hostingController.view
    }

    func updateCandidates(_ candidates: [String], cursorLocation: CGPoint) {
        self.candidatesViewState.candidates = candidates
        self.candidatesViewState.currentSelectedRow = -1
        self.hostingController.rootView = CandidatesView(
            candidatesViewState: candidatesViewState,
            delegate: self.delegate
        )
        // ウィンドウのベースを透明にする
        self.hostingController.view.window?.backgroundColor = .clear
        resizeWindowToFitContent(cursorLocation: cursorLocation)
    }

    func clearCandidates() {
        self.candidatesViewState.candidates = []
    }

    private func resizeWindowToFitContent(cursorLocation: CGPoint) {
        // ウィンドウサイズの変更ロジック
        guard let window = self.view.window, let screen = window.screen else { return }

        let numberOfRows = min(9, candidatesViewState.candidates.count)
        let rowHeight: CGFloat = 24 // 適切な行の高さ
        let totalHeight = rowHeight * CGFloat(numberOfRows) + 20 // パディングを含む

        let maxWidth = candidatesViewState.candidates.reduce(0) { maxWidth, candidate in
            let width = NSAttributedString(string: candidate, attributes: [.font: NSFont.systemFont(ofSize: 16)]).size().width
            return max(maxWidth, width)
        }

        let windowWidth = min(max(maxWidth + 50, 200), 400)

        var newWindowFrame = window.frame
        newWindowFrame.size = CGSize(width: windowWidth, height: totalHeight)

        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y
        let cursorHeight: CGFloat = 16

        if cursorY - totalHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - totalHeight - cursorHeight)
        }

        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }

        window.setFrame(newWindowFrame, display: true, animate: false)
    }

    func selectCandidate(offset: Int) {
        let selectedRow = self.candidatesViewState.currentSelectedRow
        if selectedRow + offset < 0 {
            return
        }
        let nextRow = (selectedRow + offset + self.candidatesViewState.candidates.count) % self.candidatesViewState.candidates.count
        self.candidatesViewState.currentSelectedRow = nextRow
        self.delegate?.candidateSelectionChanged(self.candidatesViewState.candidates[nextRow])
    }

    func selectFirstCandidate() {
        guard !self.candidatesViewState.candidates.isEmpty else { return }
        self.candidatesViewState.currentSelectedRow = 0
        self.delegate?.candidateSelectionChanged(self.candidatesViewState.candidates[0])
    }

    func confirmCandidateSelection() {
        let selectedRow = self.candidatesViewState.currentSelectedRow
        if selectedRow >= 0 && selectedRow < self.candidatesViewState.candidates.count {
            let selectedCandidate = self.candidatesViewState.candidates[selectedRow]
            delegate?.candidateSelected(selectedCandidate)
        }
    }
}

protocol CandidatesViewControllerDelegate: AnyObject {
    func candidateSelected(_ candidate: String)
    func candidateSelectionChanged(_ candidateString: String)
}
