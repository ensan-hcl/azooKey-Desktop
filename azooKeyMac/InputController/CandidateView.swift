//
//  CandidateView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/08/03.
//

import Cocoa

class CandidatesViewController: NSViewController {
    private var candidates: [String] = []
    private var tableView: NSTableView!
    weak var delegate: (any CandidatesViewControllerDelegate)?
    private var currentSelectedRow: Int = -1
    private var showedRows: ClosedRange = 0 ... 8
    private let rowHeight: CGFloat = 20
    private let maxRows: Int = 9

    override func loadView() {
        let scrollView = NSScrollView()
        tableView = NonClickableTableView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        // グリッドスタイルを設定してセル間に水平線を表示
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.style = .plain

        let stackView = NSStackView(views: [scrollView])
        stackView.orientation = .vertical
        stackView.spacing = 1 // ここを0にすると落ちる

        view = stackView // 直接scrollViewを指定すると落ちる
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        tableView.headerView = nil
        tableView.addTableColumn(column)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = rowHeight
        tableView.style = NSTableView.Style.plain

        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 角丸のためのウィンドウ設定
        configureWindowForRoundedCorners()
    }

    private func configureWindowForRoundedCorners() {
        guard let window = view.window else { return }

        // ウィンドウとそのコンテンツビューがレイヤーバックされるように設定
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.masksToBounds = true

        // ウィンドウをボーダーレスに設定
        window.styleMask = [.borderless, .resizable]
        window.isMovable = true
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // 角丸を適用
        window.contentView?.layer?.cornerRadius = 10
        window.backgroundColor = .clear

        // 重要：黒い背景が角に見えないようにする
        window.isOpaque = false
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowForRoundedCorners()
    }

    func updateCandidates(_ candidates: [String], cursorLocation: CGPoint) {
        showedRows = 0 ... (maxRows - 1)
        self.candidates = candidates
        currentSelectedRow = -1 // 選択をリセット
        tableView.reloadData()
        resizeWindowToFitContent(cursorLocation: cursorLocation)
        selectFirstCandidate() // 最初の候補を選択
    }

    private func updateVisibleRows() {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        for row in visibleRows.lowerBound ..< visibleRows.upperBound {
            if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? CandidateTableCellView {
                updateCellView(cellView, forRow: row)
            }
        }
    }

    private func updateCellView(_ cellView: CandidateTableCellView, forRow row: Int) {
        let isWithinShowedRows = showedRows.contains(row)
        let displayIndex = row - showedRows.lowerBound + 1 // showedRowsの下限からの相対的な位置
        let displayText: String

        if isWithinShowedRows {
            if displayIndex > maxRows {
                displayText = " \(candidates[row])" // 行番号が10以上の場合、インデントを調整
            } else {
                displayText = "\(displayIndex). \(candidates[row])"
            }
        } else {
            displayText = candidates[row] // showedRowsの範囲外では番号を付けない
        }

        // 数字部分と候補部分を別々に設定
        let attributedString = NSMutableAttributedString(string: displayText)
        let numberRange = (displayText as NSString).range(of: "\(displayIndex).")

        if numberRange.location != NSNotFound {
            attributedString.addAttributes([
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: currentSelectedRow == row ? NSColor.white : NSColor.gray,
            ], range: numberRange)
        }

        cellView.candidateTextField.attributedStringValue = attributedString
    }

    func clearCandidates() {
        candidates = []
        tableView.reloadData()
    }

    private func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = view.window, let screen = window.screen else { return }

        let numberOfRows = min(maxRows, tableView.numberOfRows)
        let totalHeight = rowHeight * 9

        // 候補の最大幅を計算
        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(string: candidate, attributes: [.font: NSFont.systemFont(ofSize: 16)])
            let width = attributedString.size().width
            return max(maxWidth, width)
        }

        // ウィンドウの幅を設定（番号とパディングのための追加幅を考慮）
        let windowWidth = max(maxWidth + 50, 400) // 最小400px

        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = totalHeight

        // 画面のサイズを取得
        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y

        // カーソルの高さを考慮してウィンドウ位置を調整
        let cursorHeight: CGFloat = 16 // カーソルの高さを16ピクセルと仮定

        // ウィンドウをカーソルの下に表示
        if cursorY - totalHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - totalHeight - cursorHeight)
        }

        // 右端でウィンドウが画面外に出る場合は左にシフト
        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }

        window.setFrame(newWindowFrame, display: true, animate: false)
    }

    // 選択行の移動
    func updateSelection(to row: Int) {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        let selectedCandidate = candidates[row]
        delegate?.candidateSelectionChanged(selectedCandidate)

        // 新しい選択行を設定
        currentSelectedRow = row

        // 表示範囲
        if !showedRows.contains(row) {
            if row < showedRows.lowerBound {
                showedRows = row ... (row + (maxRows - 1))
            } else {
                showedRows = (row - (maxRows - 1)) ... row
            }
        }

        // 表示を更新
        updateVisibleRows()
    }

    // offsetで移動
    func selectCandidate(offset: Int) {
        let selectedRow = tableView.selectedRow
        if selectedRow + offset < 0 || selectedRow + offset >= candidates.count {
            return
        }
        let nextRow = (selectedRow + offset + candidates.count) % candidates.count
        updateSelection(to: nextRow)
    }

    // 表示されているナンバリング出の移動
    func selectNumberCandidate(num: Int) {
        let nextRow = showedRows.lowerBound + num - 1
        updateSelection(to: nextRow)
    }

    func selectFirstCandidate() {
        guard !candidates.isEmpty else {
            return
        }
        let nextRow = 0
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        let selectedCandidate = candidates[nextRow]
        delegate?.candidateSelectionChanged(selectedCandidate)

        // 新しい選択行を設定
        currentSelectedRow = nextRow

        // 表示を更新
        updateVisibleRows()
    }

    func confirmCandidateSelection() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < candidates.count {
            let selectedCandidate = candidates[selectedRow]
            delegate?.candidateSelected(selectedCandidate)
        }
    }
}

extension CandidatesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("CandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? CandidateTableCellView
        if cell == nil {
            cell = CandidateTableCellView()
            cell?.identifier = cellIdentifier
        }

        if let cell = cell {
            updateCellView(cell, forRow: row)
        }

        return cell
    }
}

class NonClickableTableView: NSTableView {
    override func rightMouseDown(with _: NSEvent) {
        // 右クリックイベントを無視
    }

    override func mouseDown(with _: NSEvent) {
        // 左クリックイベントも無視する場合はこのメソッド内を空に
    }

    override func otherMouseDown(with _: NSEvent) {
        // 中クリックなどその他のマウスボタンのクリックも無視
    }
}

class CandidateTableCellView: NSTableCellView {
    let candidateTextField: NSTextField

    override init(frame frameRect: NSRect) {
        candidateTextField = NSTextField(labelWithString: "")
        // font size
        candidateTextField.font = NSFont.systemFont(ofSize: 16)
        super.init(frame: frameRect)
        addSubview(candidateTextField)

        candidateTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            candidateTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            candidateTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            candidateTextField.centerYAnchor.constraint(equalTo: centerYAnchor), // 縦方向の中央配置
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol CandidatesViewControllerDelegate: AnyObject {
    func candidateSelected(_ candidate: String)
    func candidateSelectionChanged(_ candidateString: String)
}
