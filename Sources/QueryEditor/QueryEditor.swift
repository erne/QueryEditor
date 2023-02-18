//
//  QueryEditor.swift
//  Draggable Grid View
//
//  Created by Erne on 12-12-22.
//  Copyright © 2022 Apimac. All rights reserved.
//

import Cocoa

struct QueryDataSourcesPopupManager<D: QueryDB> {
    let popUp: QueryDataSourcesPopup
    
    func configure(for db: D) {
        popUp.removeAllItems()
        
        db.bos.forEach { bo in
            let icon = bo.type.icon
            icon?.size = NSSize(width: 16, height: 16)
            let item = NSMenuItem(title: bo.displayName,
                                  action: nil,
                                  keyEquivalent: "")
            item.image = icon
            item.representedObject = bo
            popUp.menu?.addItem(item)
        }
        
//        self.menu = menu
    }
}

final class QueryDataSourcesPopup: NSPopUpButton { }
//
//    func configure(for db: QueryDB) {
//        removeAllItems()
//
//        db.bos.forEach { bo in
//            let icon = bo.type.icon
//            icon?.size = NSSize(width: 16, height: 16)
//            let item = NSMenuItem(title: bo.displayName,
//                                  action: nil,
//                                  keyEquivalent: "")
//            item.image = icon
//            item.representedObject = bo
//            menu?.addItem(item)
//        }
//
//        self.menu = menu
//    }
//
//}

public class QueryEditor: NSViewController {
    @IBOutlet weak var bosPopup: QueryDataSourcesPopup!
    @IBOutlet weak var queryEditorTableView: NSTableView! {
        didSet {
            // allow reorder of items
            queryEditorTableView.registerForDraggedTypes([rowIndexDataType])
            queryEditorTableView.draggingDestinationFeedbackStyle = .sourceList //gap
        }
    }
    
    var query: Query? {
        didSet {
            if let db = query?.db {
                QueryDataSourcesPopupManager(popUp: bosPopup).configure(for: db)
            } else {
                bosPopup.removeAllItems()
            }
            queryEditorTableView.reloadData()
        }
    }
    
    let queryEditorRowIdentifier = NSUserInterfaceItemIdentifier("QueryEditorRow")
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do view setup here.
//        let bos = [BO(name: "Artist", alias: "a", type: .table),
//                   BO(name: "Album", alias: "b", type: .table)]
//        bos[0].createField(name: "name", type: .string)
//        bos[1].createField(name: "title", type: .string)
//        bos[1].createField(name: "year", type: .number)
//        let db = DB(bos: bos)
//        let query = Query(db: db)
//        query.fromExpressions.append(QueryFrom(bo: bos[0]))
//        query.whereExpressions.append(QueryWhere(fieldExpression: bos[0].fields[0].name,
//                                                 value: "",
//                                                 operator: .equal,
//                                                 logical: .and(assertive: true),
//                                                 bo: bos[0],
//                                                 alias: nil))
//
//        self.query = query
//
////        queryEditorTableView.register(NSNib(nibNamed: queryEditorRowIdentifier.rawValue, bundle: nil),
////                                      forIdentifier: queryEditorRowIdentifier)
//    }
    
}

extension QueryEditor: DragReorderTableViewDataSource, NSTableViewDelegate {
    
    @objc var objects: [Any] {
        get{
            query?.whereExpressions.contents ?? []
        }
        set {
            guard let newValue = newValue as? [QueryWhere<BO>] else { return }
            query?.whereExpressions = OrderedSet(newValue)
        }
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        return writeRows(of: tableView, at: rowIndexes, to: pboard)
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
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
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        return acceptDrop(on: tableView, info: info, row: row, dropOperation: dropOperation)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let query = query else { return 0 }
        return query.whereExpressions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let whereExpression = query?.whereExpressions[row],
            let identifier = tableColumn?.identifier,
            let editorRow = tableView.makeView(withIdentifier: identifier, owner: self) as? MyQueryEditorRow
            else { return nil }
        
        editorRow.configure(for: query!.db)
        editorRow.objectValue = whereExpression
        editorRow.removeRowButton.isHidden = (tableView.numberOfRows == 1)
        
        editorRow.addRow = {
            if let field = editorRow.fieldsPopupManager.nextField {
                let whereExpression = QueryWhere(fieldExpression: field.name,
                                                 value: nil,
                                                 operator: .contains,
                                                 logical: .and(assertive: true),
                                                 bo: field.bo,
                                                 alias: nil)
                self.query?.whereExpressions.insert(whereExpression, at: row + 1)
                tableView.insertRows(at: IndexSet(integer: row + 1),
                                     withAnimation: .effectGap)
                if tableView.numberOfRows == 2,
                    let rowView = tableView.view(atColumn: 0,
                                                 row: 0,
                                                 makeIfNecessary: false) as? QueryEditorRow<DB, BO, Field> {
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
                                             makeIfNecessary: false) as? QueryEditorRow<DB, BO, Field> {
                rowView.removeRowButton.isHidden = true
            }
        }
        
        return editorRow
    }
}
