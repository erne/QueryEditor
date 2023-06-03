//
//  QueryEditor.swift
//  Draggable Grid View
//
//  Created by Erne on 12-12-22.
//  Copyright © 2022 Apimac. All rights reserved.
//

import Cocoa
import DragReorderTableView
import Collections
/**
 
 */
//struct QueryDataSourcesPopupManager<D: QueryDB> {
//    let popUp: QueryDataSourcesPopup
//
//    func configure(for db: D) {
//        popUp.removeAllItems()
//
//        db.bos.forEach { bo in
//            let icon = bo.type.icon
//            icon?.size = NSSize(width: 16, height: 16)
//            let item = NSMenuItem(title: bo.displayName,
//                                  action: nil,
//                                  keyEquivalent: "")
//            item.image = icon
//            item.representedObject = bo
//            popUp.menu?.addItem(item)
//        }
//    }
//}

//final class QueryDataSourcesPopup: NSPopUpButton { }

public protocol QueryEditorDelegate: class {
    func queryEditorBoAction<T>(_ queryEditor: QueryEditor<T>, newBO: T.BO) -> Bool
    func queryEditorSearchAction<T>(_ queryEditor: QueryEditor<T>)
}

open class QueryEditor<DB: QueryDB>: NSViewController, DragReorderTableViewDataSource, DragReorderTableViewDelegate {
    typealias BO = DB.BO
    
    public weak var delegate: QueryEditorDelegate?
    
    public var action: ((Query<DB>?) -> ())?
    public var liveSearch = false {
        didSet {
            searchButton.isHidden = liveSearch
        }
    }

    @IBOutlet var searchButton: NSButton!
    @IBAction func searchAction(_ sender: Any) {
        doAction()
    }
    func doAction() {
        objects = queryEditorWhereExpressions
        delegate?.queryEditorSearchAction(self)
        action?(query)
    }
    
    @IBOutlet weak var bosPopup: NSPopUpButton! //QueryDataSourcesPopup!
    @IBAction func bosPopupAction(_ sender: NSPopUpButton) {
        guard let bo = sender.selectedItem?.representedObject as? BO,
            let query = query
            else { return }
        
        if !(delegate?.queryEditorBoAction(self, newBO: bo) ?? false) {
            query.mainBos = [bo]
            query.selectFields = [QuerySelect(fieldExpression: "*", bo: bo)]
        }
        if liveSearch {
            doAction()
        }
    }
    @IBOutlet weak var queryEditorTableView: NSTableView! {
        didSet {
            // allow reorder of items
            queryEditorTableView.registerForDraggedTypes([rowIndexDataType])
            queryEditorTableView.draggingDestinationFeedbackStyle = .sourceList //gap
        }
    }
    var queryEditorRows: [QueryEditorRow<DB>] {
        (0..<queryEditorTableView.numberOfRows).compactMap {
            queryEditorTableView.rowView(atRow: $0, makeIfNecessary: true)?
                .subviews.first as? QueryEditorRow
        }
    }
    var queryEditorWhereExpressions: [QueryWhere<BO>] {
        queryEditorRows.compactMap { $0.queryWhere }
    }
    
    public var query: Query<DB>? {
        didSet {
            guard isViewLoaded else { return }
            if query != nil {
                configureBosPopoup()
            } else {
                bosPopup.removeAllItems()
            }
            queryEditorTableView.reloadData()
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        if query != nil {
            configureBosPopoup()
            queryEditorTableView.reloadData()
        }
    }
    
    public var db: DB? {
        query?.db
    }
    
    let queryEditorRowIdentifier = NSUserInterfaceItemIdentifier("QueryEditorRow")
    
    func configureBosPopoup() {
        bosPopup.removeAllItems()
        
        db?.bos.forEach { bo in
            let icon = bo.type.icon
            icon?.size = NSSize(width: 16, height: 16)
            let item = NSMenuItem(title: bo.displayName,
                                  action: nil,
                                  keyEquivalent: "")
            item.image = icon
            item.representedObject = bo
            bosPopup.menu?.addItem(item)
        }
        
        let index = bosPopup.indexOfItem(withRepresentedObject: query?.mainBos.first)
        bosPopup.selectItem(at: index)

    }

    //extension QueryEditor: DragReorderTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - DragReorder TableView

    /**
     The objects represented by the query editor tableview are QueryWhere expressions.
     */
    @objc public var objects: [Any] {
        get{
            query?.whereExpressions.contents ?? []
        }
        set {
            guard let newValue = newValue as? [QueryWhere<BO>] else { return }
            query?.whereExpressions = OrderedSet(newValue)
        }
    }

    // MARK: - TableView Datasource
    
    var disableAction = false
    
    public func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        return writeRows(of: tableView, at: rowIndexes, to: pboard)
    }

    public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        // get necessary info to handle reorder
        guard let data = info.draggingPasteboard.data(forType: rowIndexDataType),
            let rowIndexes = (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSIndexSet.self,
                                                                      from: data))
        else { return [] }
        let firstDraggedRow = rowIndexes.firstIndex
        // allow only above drops
        guard row != firstDraggedRow,
            dropOperation == .above else { return [] }

        return validateDrop(on: tableView, info: info, proposedRow: row, proposedDropOperation: dropOperation)
    }

    public func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        return acceptDrop(on: tableView, info: info, row: row, dropOperation: dropOperation)
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        guard let query = query else { return 0 }
        return query.whereExpressions.count
    }
    
    // MARK: - TableView Delegate

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let whereExpression = query?.whereExpressions[row],
            let identifier = tableColumn?.identifier,
            let editorRow = tableView.makeView(withIdentifier: identifier, owner: self) as? QueryEditorRow<DB>
            else { return nil }

        editorRow.index = row
        editorRow.configure(for: query!.db)
        editorRow.objectValue = whereExpression
        editorRow.removeRowButton.isHidden = (tableView.numberOfRows == 1)
        // the actions methods
        editorRow.addRow = { row in
            if let field = editorRow.fieldsPopupManager.nextField,
                let bo = field.bo as? BO {
                let op: QueryOperator = {
                    switch field.fieldType {
                    case .string:
                        return .contains
                    default:
                        return .equal
                    }
                }()
                let value: AnyHashable? = {
                    switch field.fieldType {
                    case .date:
                        return Date()
                    default:
                        return nil
                    }
                }()
                let whereExpression = QueryWhere<BO>(fieldExpression: field.name,
                                                     value: value,
                                                     operator: op,
                                                     logical: .and(assertive: true),
                                                     bo: bo)
                if self.query?.whereExpressions.insert(whereExpression, at: row + 1) ?? false {
                    tableView.insertRows(at: IndexSet(integer: row + 1),
                                         withAnimation: .effectGap)
                    if tableView.numberOfRows == 2,
                        let rowView = tableView.view(atColumn: 0,
                                                     row: 0,
                                                     makeIfNecessary: false) as? QueryEditorRow<DB> {
                        rowView.removeRowButton.isHidden = false
                    }
                    self.updateRowIndexes(in: tableView, startingAt: row + 1)
                    if self.liveSearch {
                        self.doAction()
                    }
                }
            }
        }
        editorRow.removeRow = { [weak self] row in
            guard let self = self
                else { return } //fatalError("invalid where expression") }
            
            self.disableAction = true
            defer { self.disableAction = false }
            
            self.query?.whereExpressions.remove(at: row)
            tableView.removeRows(at: IndexSet(integer: row),
                                 withAnimation: .effectFade)
            self.updateRowIndexes(in: tableView, startingAt: row)
            if tableView.numberOfRows == 1,
                let rowView = tableView.view(atColumn: 0,
                                             row: 0,
                                             makeIfNecessary: false) as? QueryEditorRow<DB> {
                rowView.removeRowButton.isHidden = true
            }
            if self.liveSearch {
                self.doAction()
            }
        }
        editorRow.action = { [weak self] row, queryWhere in
            guard let self = self,
                !self.disableAction,
                let query = self.query
                else { return } //fatalError("invalid where expression") }
            
//            print(queryWhere.expression)
//            print(query.whereExpressions.count)
//            if query.whereExpressions[row] == queryWhere,
//            !(query.whereExpressions[row].expression == queryWhere.expression) {
//                print("\(query.whereExpressions[row].expression) should be equal to \(queryWhere.expression)")
//            }
            query.whereExpressions[row] = queryWhere
//            print(query.whereExpressions[row].expression)
            if self.liveSearch {
                self.doAction()
            }
        }

        return editorRow
    }
    
    func updateRowIndexes(in tableView: NSTableView, startingAt startIndex: Int, endingAt endIndex: Int? = nil) {
        let endIndex = endIndex ?? tableView.numberOfRows - 1
        
        guard startIndex < endIndex else { return }
        
        (startIndex...endIndex).enumerated().forEach { (_, index) in
            guard let editorRow = tableView.rowView(atRow: index, makeIfNecessary: true)?.subviews.first as? QueryEditorRow<DB>
                else { return }
            editorRow.index = index
        }
    }
    
//    public func tableView(_ tableView: NSTableView, shouldMoveRow oldIndex: Int, to newIndex: Int) -> Bool {
////        guard let editorRow = tableView.rowView(atRow: oldIndex, makeIfNecessary: true)?.subviews.first as? QueryEditorRow<DB>
////            else { return false }
//        if newIndex > oldIndex {
//            updateRowIndexes(in: tableView, startingAt: oldIndex)
//        } else {
//            updateRowIndexes(in: tableView, startingAt: 0, endingAt: newIndex)
//        }
//
////        editorRow.index = newIndex
////
////        updateRowIndexes(in: tableView, startingAt: index + 1)
//        return true
//    }
    
    public func tableView(_ tableView: NSTableView, didMoveRow oldIndex: Int, to newIndex: Int) {
        if newIndex > oldIndex {
            updateRowIndexes(in: tableView, startingAt: oldIndex)
        } else {
            updateRowIndexes(in: tableView, startingAt: newIndex, endingAt: oldIndex)
        }
        if liveSearch {
            doAction()
        }
    }
}
