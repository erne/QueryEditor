//
//  QueryEditorRow.swift
//  Draggable Grid View
//
//  Created by Erne on 12-12-22.
//  Copyright © 2022 Apimac. All rights reserved.
//

import Cocoa

final class QueryFieldsMenu<DB: QueryDB>: NSMenu {
    
    init(title: String = "", db: DB) { //}, action: Selector?) {
        super.init(title: title)
        configure(db: db) //, action: action)
    }
    
    private func configure(db: DB) { //}, action: Selector?) {
        autoenablesItems = false
        
        db.bos.forEach { bo in
            let icon = bo.type.icon
            icon?.size = NSSize(width: 16, height: 16)
            let item = NSMenuItem(title: bo.displayName,
                                  action: nil,
                                  keyEquivalent: "")
            item.image = icon
            item.isEnabled = false
            addItem(item)
            bo.searchableFields.forEach {
                let item = NSMenuItem(title: $0.label,
                                      action: nil,
                                      keyEquivalent: "")
                item.representedObject = $0
                item.image = icon
                addItem(item)
            }
        }
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
}

struct QueryFieldsPopupManager<D: QueryDB, B: QueryBO, F: QueryField> {
    let popUp: QueryFieldsPopup
        
    var selectedField: F? {
        get { popUp.selectedItem?.representedObject as? F }
        set {
            let index = popUp.indexOfItem(withRepresentedObject: newValue)
            popUp.selectItem(at: index)
        }
    }
    
    func firstItem(for bo: B) -> NSMenuItem? {
        popUp.itemArray.first(where: { ($0.representedObject as? F)?.bo === bo })
    }
    
    func item(for field: F) -> NSMenuItem? {
        popUp.itemArray.first(where: { ($0.representedObject as? F) === field })
    }
    
    func configure(for db: D, in row: QueryEditorRow<D, B, F>, action: Selector?) {
        popUp.menu = QueryFieldsMenu(db: db)
        //                               action: action)
        popUp.target = row
        popUp.action = action
    }
    
    var nextField: F? {
        let currentIndex = popUp.indexOfSelectedItem
        var newIndex = currentIndex + 1
        var field: F?
        while field == nil,
            newIndex < popUp.itemArray.count {
                field = popUp.item(at: newIndex)?.representedObject as? F
                newIndex += 1
        }
        if field == nil {
            newIndex = 0
            while field == nil,
                newIndex < currentIndex {
                    field = popUp.item(at: newIndex)?.representedObject as? F
                    newIndex += 1
            }
        }
        return field
    }

}

final class QueryFieldsPopup: NSPopUpButton {}

//    var selectedField: F? {
//        get { selectedItem?.representedObject as? F }
//        set {
//            let index = indexOfItem(withRepresentedObject: newValue)
//            selectItem(at: index)
//        }
//    }
//
//    func firstItem(for bo: B) -> NSMenuItem? {
//        itemArray.first(where: { ($0.representedObject as? F)?.bo === bo })
//    }
//
//    func item(for field: F) -> NSMenuItem? {
//        itemArray.first(where: { ($0.representedObject as? F) === field })
//    }
//
//    func configure(for db: D, in row: QueryEditorRow, action: Selector?) {
//        menu = QueryFieldsMenu(db: db)
////                               action: action)
//        target = row
//        self.action = action
//    }
//
//    var nextField: F? {
//        let currentIndex = indexOfSelectedItem
//        var newIndex = currentIndex + 1
//        var field: F?
//        while field == nil,
//            newIndex < itemArray.count {
//                field = item(at: newIndex)?.representedObject as? F
//                newIndex += 1
//        }
//        if field == nil {
//            newIndex = 0
//            while field == nil,
//                newIndex < currentIndex {
//                    field = item(at: newIndex)?.representedObject as? F
//                    newIndex += 1
//            }
//        }
//        return field
//    }
//
//}

struct QueryOperatorsPopupManager<F: QueryField> {
    let popUp: QueryOperatorsPopup
    
    var selectedOperator: SqlOperator? {
        popUp.selectedItem?.representedObject as? SqlOperator
    }
    
    func configure(for field: F) {
        let menu = NSMenu()
        
        operators(for: field.fieldType).forEach { op in
            let item = NSMenuItem(title: op.asString, action: nil, keyEquivalent: "")
            item.representedObject = op
            menu.addItem(item)
        }
        
        popUp.menu = menu
    }
    
    func operators(for type: FieldType) -> [SqlOperator] {
        switch type {
        case .string:
            return [.beginsWith,
                    .contains,
                    .equal,
                    .endsWith,
                    .notEqual]
        case .number:
            return [.equal,
                    .greater,
                    .greaterOrEqual,
                    .less,
                    .lessOrEqual,
                    .notEqual]
        case .boolean:
            return [.equal, .notEqual]
        case .date, .time:
            return [.equal,
                    .greater,
                    .greaterOrEqual,
                    .less,
                    .lessOrEqual,
                    .notEqual]
        default:
            return []
        }
    }
}

final class QueryOperatorsPopup: NSPopUpButton {}
//    var selectedOperator: SqlOperator? {
//        selectedItem?.representedObject as? SqlOperator
//    }
//
//    func configure(for field: F) {
//        let menu = NSMenu()
//
//        operators(for: field.fieldType).forEach { op in
//            let item = NSMenuItem(title: op.asString, action: nil, keyEquivalent: "")
//            item.representedObject = op
//            menu.addItem(item)
//        }
//
//        self.menu = menu
//    }
//
//    func operators(for type: FieldType) -> [SqlOperator] {
//        switch type {
//        case .string:
//            return [.beginsWith,
//                    .contains,
//                    .equal,
//                    .endsWith,
//                    .notEqual]
//        case .number:
//            return [.equal,
//                    .greater,
//                    .greaterOrEqual,
//                    .less,
//                    .lessOrEqual,
//                    .notEqual]
//        case .boolean:
//            return [.equal, .notEqual]
//        case .date, .time:
//            return [.equal,
//                    .greater,
//                    .greaterOrEqual,
//                    .less,
//                    .lessOrEqual,
//                    .notEqual]
//        default:
//            return []
//        }
//    }
//
//}

//struct QueryEditorRowManager<D: QueryDB, B: QueryBO, F: QueryField> {
//    let row: QueryEditorRow
//    let db: D
//    let bo: B
//    let field: F
//
//    var queryWhere: QueryWhere<B>? {
//        row.objectValue as? QueryWhere
//    }
//
//}

public class QueryEditorRow<D: QueryDB, B: QueryBO, F: QueryField>: NSTableCellView {

    @IBOutlet weak var controlsStackView: NSStackView!
    @IBOutlet weak var queryFieldsPopup: QueryFieldsPopup!
    @IBOutlet weak var queryOperatorsPopup: QueryOperatorsPopup!
    @IBOutlet weak var queryValuesPopup: NSPopUpButton!
    @IBOutlet weak var queryValueTextField: NSTextField!
    @IBOutlet weak var queryValueDatePicker: NSDatePicker!
    @IBOutlet weak var removeRowButton: NSButton!
    
    lazy var fieldsPopupManager = QueryFieldsPopupManager<D, B, F>(popUp: queryFieldsPopup)
    lazy var operatorsPopupManager = QueryOperatorsPopupManager<F>(popUp: queryOperatorsPopup)

    var removeRow: (() -> ())?
    var addRow: (() -> ())?
    @IBAction func removeRowAction(_ sender: Any) {
        removeRow?()
    }
    @IBAction func addRowAction(_ sender: Any) {
        addRow?()
    }
    
//    var rowManager: QueryEditorRowManager?
//       guard let queryWhere = objectValue as? QueryWhere
//        else { fatalError("invalid query where") }
//
//        return QueryEditorRowManager<queryWhere.bo.db>(row: self)
//
//    }()
//
//    var queryWhere: QueryWhere<B>? {
//        objectValue as? QueryWhere
//    }
    
    override var objectValue: Any? {
        didSet {
            guard let queryWhere = objectValue as? QueryWhere<B>
                else { return }
            if let bo = queryWhere.bo {
                let fieldName = queryWhere.fieldExpression
                if let field = bo.field(forName: fieldName) as? F,
//                    let item = queryFieldsPopup.item(for: field) {
                    let item = fieldsPopupManager.item(for: field) {
                    queryFieldsPopup.select(item)
                    updateRow(for: field)
                } else {
                    queryFieldsPopup.select(fieldsPopupManager.firstItem(for: bo))
                    if let field = queryFieldsPopup.selectedItem?.representedObject as? F {
                        updateRow(for: field)
                    }
                }
            }
        }
    }
    
    fileprivate func updateRow(for field: F) {
        operatorsPopupManager.configure(for: field)
        
        switch field.fieldType {
        case .string:
            controlsStackView.setVisibilityPriority(.mustHold, for: queryValueTextField)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValuesPopup)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueDatePicker)
        case .number:
            controlsStackView.setVisibilityPriority(.mustHold, for: queryValueTextField)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValuesPopup)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueDatePicker)
        case .boolean:
            queryValuesPopup.removeAllItems()
            queryValuesPopup.addItem(withTitle: "true")
            queryValuesPopup.addItem(withTitle: "false")
            controlsStackView.setVisibilityPriority(.mustHold, for: queryValuesPopup)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueTextField)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueDatePicker)
        case .date, .time:
            controlsStackView.setVisibilityPriority(.mustHold, for: queryValueDatePicker)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueTextField)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValuesPopup)
        default:
            break
        }
    }
    
    @IBAction func fieldAction(_ sender: NSPopUpButton) {
//        guard let field = sender.representedObject as? QueryField
        guard let field = sender.selectedItem?.representedObject as? F
                else { return }
        
        updateRow(for: field)
    }
    
    func configure(for db: D) {
        fieldsPopupManager.configure(for: db, in: self, action: #selector(fieldAction(_:)))
    }
    
}
//
//class MyQueryEditorRow: QueryEditorRow<DB, BO, Field> {}
