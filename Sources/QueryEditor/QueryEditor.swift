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

final class QueryDataSourcesPopup: NSPopUpButton { }

public class QueryEditor<DB: QueryDB>: NSViewController, DragReorderTableViewDataSource, NSTableViewDelegate {
    typealias BO = DB.BO

    @IBOutlet weak var bosPopup: NSPopUpButton! //QueryDataSourcesPopup!
    @IBOutlet weak var queryEditorTableView: NSTableView! {
        didSet {
            // allow reorder of items
            queryEditorTableView.registerForDraggedTypes([rowIndexDataType])
            queryEditorTableView.draggingDestinationFeedbackStyle = .sourceList //gap
        }
    }
    
    public var query: Query<DB>? {
        didSet {
            if query != nil {
                configureBosPopoup()
//                QueryDataSourcesPopupManager(popUp: bosPopup).configure(for: query.db)
            } else {
                bosPopup.removeAllItems()
            }
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
    }

    //extension QueryEditor: DragReorderTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - DragReorder TableView

    /**
     The objects represented by the query editor tableview are QueryWhere espressions.
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

        editorRow.configure(for: query!.db)
        editorRow.objectValue = whereExpression
        editorRow.removeRowButton.isHidden = (tableView.numberOfRows == 1)

        editorRow.addRow = {
            if let field = editorRow.fieldsPopupManager.nextField,
                let bo = field.bo as? BO {
                let whereExpression = QueryWhere<BO>(fieldExpression: field.name,
                                                     value: nil,
                                                     operator: .contains,
                                                     logical: .and(assertive: true),
                                                     bo: bo)
                self.query?.whereExpressions.insert(whereExpression, at: row + 1)
                tableView.insertRows(at: IndexSet(integer: row + 1),
                                     withAnimation: .effectGap)
                if tableView.numberOfRows == 2,
                    let rowView = tableView.view(atColumn: 0,
                                                 row: 0,
                                                 makeIfNecessary: false) as? QueryEditorRow<DB> {
                    rowView.removeRowButton.isHidden = false
                }
            }
        }
        editorRow.removeRow = {
            self.query?.whereExpressions.remove(at: row)
            tableView.removeRows(at: IndexSet(integer: row),
                                 withAnimation: .effectFade)
            if tableView.numberOfRows == 1,
                let rowView = tableView.view(atColumn: 0,
                                             row: 0,
                                             makeIfNecessary: false) as? QueryEditorRow<DB> {
                rowView.removeRowButton.isHidden = true
            }
        }

        return editorRow
    }
}
