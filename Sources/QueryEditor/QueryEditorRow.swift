//
//  QueryEditorRow.swift
//  Draggable Grid View
//
//  Created by Erne on 12-12-22.
//  Copyright © 2022 Apimac. All rights reserved.
//

import Cocoa

/**
 A menu to represent the searchable fields of a database.
 */
final class QueryFieldsMenu<DB: QueryDB>: NSMenu {
    
    init(title: String = "", db: DB) { //}, action: Selector?) {
        super.init(title: title)
        configure(db: db) //, action: action)
    }
    
    private func configure(db: DB) { //}, action: Selector?) {
        autoenablesItems = false
        
        db.bos.filter { $0.queryable }
            .forEach { bo in
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
/**
 Manager for a popup button representing the searchable fields of a database.
 */
struct QueryFieldsPopupManager<DB: QueryDB> {
    typealias BO = DB.BO
    typealias Field = BO.Field
    let popUp: QueryFieldsPopup
        
    var selectedField: Field? {
        get { popUp.selectedItem?.representedObject as? Field }
        set {
            let index = popUp.indexOfItem(withRepresentedObject: newValue)
            popUp.selectItem(at: index)
        }
    }
    
    func firstItem(for bo: BO) -> NSMenuItem? {
        popUp.itemArray.first(where: { ($0.representedObject as? Field)?.bo === bo })
    }
    
    func item(for field: Field) -> NSMenuItem? {
        popUp.itemArray.first(where: { ($0.representedObject as? Field) === field })
    }
    
    func configure(for db: DB, in row: QueryEditorRow<DB>, action: Selector?) {
        popUp.menu = QueryFieldsMenu(db: db)
        //                               action: action)
        popUp.target = row
        popUp.action = action
    }
    
    var nextField: Field? {
        let currentIndex = popUp.indexOfSelectedItem
        var newIndex = currentIndex + 1
        var field: Field?
        while field == nil,
            newIndex < popUp.itemArray.count {
                field = popUp.item(at: newIndex)?.representedObject as? Field
                newIndex += 1
        }
        if field == nil {
            newIndex = 0
            while field == nil,
                newIndex < currentIndex {
                    field = popUp.item(at: newIndex)?.representedObject as? Field
                    newIndex += 1
            }
        }
        return field
    }

}

final class QueryFieldsPopup: NSPopUpButton {}

/**
 Manager for the query operators popup.
 */
struct QueryOperatorsPopupManager<F: QueryField> {
    let popUp: QueryOperatorsPopup
    
    var selectedOperator: QueryOperator? {
        get {
            popUp.selectedItem?.representedObject as? QueryOperator
        }
        set {
            let item = popUp.itemArray.first(where: { ($0.representedObject as? QueryOperator) == newValue }) ?? popUp.itemArray.first
            popUp.select(item)
        }
    }
    
    func configure(for field: F) {
        let menu = NSMenu()
        
        operators(for: field).forEach { op in
            let item = NSMenuItem(title: op.asString, action: nil, keyEquivalent: "")
            item.representedObject = op
            menu.addItem(item)
        }
        
        popUp.menu = menu
    }
    
    func operators(for field: F) -> [QueryOperator] {
        field.allowedOperators ?? field.fieldType.allowedOperators
    }
}

final class QueryOperatorsPopup: NSPopUpButton {}

final class QueryValuesPopup: NSPopUpButton {
    weak var delegate: NSControlTextEditingDelegate?
    
    override var objectValue: Any? {
        get {
            selectedItem?.representedObject
        }
        set {
            super.objectValue = indexOfItem(withRepresentedObject: newValue)
        }
    }
}

enum QueryEditorRowElement {
    case field
    case `operator`
    case value
}

/**
 The row of a query editor tableview representing a SQL WHERE clause.
 */
open class QueryEditorRow<DB: QueryDB>: NSTableCellView, NSTextFieldDelegate, NSDatePickerCellDelegate {
    /**
     The concrete table holding the data.
     */
    typealias BO = DB.BO
    /**
     The concrete field holding data.
     */
    typealias Field = BO.Field
    
    var index = 0
    
    var internalAction = false
    
    @IBOutlet weak var controlsStackView: NSStackView!
    @IBOutlet weak var queryFieldsPopup: QueryFieldsPopup!
    @IBOutlet weak var queryOperatorsPopup: QueryOperatorsPopup!
    @IBOutlet weak var queryValuesPopup: QueryValuesPopup! {
        didSet { queryValuesPopup.delegate = self }
    }
    @IBOutlet weak var queryValueTextField: NSTextField! {
        didSet { queryValueTextField.delegate = self }
    }
    public func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        guard let value = obj as? AnyHashable else { return false }
        return validateValue(value)
    }
//    private var oldQueryWhere: QueryWhere<BO>?
//    public func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
//        oldQueryWhere = queryWhere
//        return true
//    }
    @IBOutlet weak var queryValueDatePicker: NSDatePicker! {
        didSet { queryValueDatePicker.delegate = self }
    }
    public func datePickerCell(_ datePickerCell: NSDatePickerCell,
                        validateProposedDateValue proposedDateValue: AutoreleasingUnsafeMutablePointer<NSDate>,
                        timeInterval proposedTimeInterval: UnsafeMutablePointer<TimeInterval>?) {
        if !validateValue(proposedDateValue.pointee) {
            proposedDateValue.pointee = datePickerCell.dateValue as NSDate
        }
    }
    @IBOutlet weak var removeRowButton: NSButton!

    lazy var fieldsPopupManager = QueryFieldsPopupManager<DB>(popUp: queryFieldsPopup)
    lazy var operatorsPopupManager = QueryOperatorsPopupManager<Field>(popUp: queryOperatorsPopup)
        
    /**
     The remove row function.
     */
    var removeRow: ((Int) -> ())?
    /**
     The add row function.
     */
    var addRow: ((Int) -> ())?
    
    var action: ((Int, QueryWhere<BO>) -> ())?
    
    var validate: ((QueryWhere<BO>) -> (Bool))?

    func validateValue(_ value: AnyHashable?) -> Bool {
        guard let validate = validate,
            let queryWhere = queryWhere(with: value),
            !validate(queryWhere)
        else { return true }
        return false
    }
    
    private var computedQueryWhere: QueryWhere<BO>? {
        queryWhere(with: value)
    }
    
    private func queryWhere(with value: AnyHashable?) -> QueryWhere<BO>? {
        guard let field = fieldsPopupManager.selectedField,
            let bo = field.bo as? BO,
            let op = operatorsPopupManager.selectedOperator
            else { return nil }
        
        return QueryWhere(fieldExpression: field.name,
                          value: value,
                          operator: op,
                          bo: bo)
    }
    
    public var queryWhere: QueryWhere<DB.BO>? {
        objectValue = computedQueryWhere
        return objectValue as? QueryWhere<BO>
    }
    
    var value: AnyHashable? {
        get {
            [queryValueTextField, queryValuesPopup, queryValueDatePicker].first { !($0?.isHidden ?? true) }?
                .objectValue as? AnyHashable
        }
        set {
            [queryValueTextField, queryValuesPopup, queryValueDatePicker].first { !($0?.isHidden ?? true) }?
                .objectValue = newValue
        }
    }
    
    @IBAction func action(_ sender: Any) {
        guard
            (objectValue as? QueryWhere<BO>) != queryWhere
            else { return }
        internalAction = true
        defer { internalAction = false }
        guard let queryWhere = queryWhere
            else { return }
        print(queryWhere.expression)
        switch sender {
        case is QueryFieldsPopup:
            updateRow(for: fieldsPopupManager.selectedField!)
        default:
            break
        }
        action?(index, queryWhere)
    }
    
    @IBAction func removeRowAction(_ sender: Any) {
        removeRow?(index)
    }
    @IBAction func addRowAction(_ sender: Any) {
        addRow?(index)
    }
    
    override public var objectValue: Any? {
        didSet {
            guard !internalAction,
                let queryWhere = objectValue as? QueryWhere<BO>
                else { return }
            if let bo = queryWhere.bo {
                // configure the popups for the query bo
                let fieldName = queryWhere.fieldExpression
                if let field = bo.searchableField(forName: fieldName),
                    let item = fieldsPopupManager.item(for: field) {
                    // we got a item in the fields popup matching the Where field, let's select it
                    queryFieldsPopup.select(item)
                    // update the row as appropriate for the selected field
                    updateRow(for: field)
                    // update operator
                    operatorsPopupManager.selectedOperator = queryWhere.operator
                    // update value
                    value = queryWhere.value
                } else {
                    // no match found, just select the first item in the fields popup matching the query bo
                    queryFieldsPopup.select(fieldsPopupManager.firstItem(for: bo))
                    if let field = queryFieldsPopup.selectedItem?.representedObject as? Field {
                        // update the row as appropriate for the selected field
                        updateRow(for: field)
                    }
                }
            }
        }
    }
    /**
     Update the row as appropriate for the passed field.
     */
    fileprivate func updateRow(for field: Field) {
        let currentValue = field.fieldType.properValue(from: value)
        let currentOperator = operatorsPopupManager.selectedOperator
        operatorsPopupManager.configure(for: field)
        operatorsPopupManager.selectedOperator = currentOperator
        
        if let values = field.presetValues {
            queryValuesPopup.removeAllItems()
            values.forEach {
                let item = NSMenuItem(title: $0.description, action: nil, keyEquivalent: "")
                item.representedObject = $0
                queryValuesPopup.menu?.addItem(item)
            }
            controlsStackView.setVisibilityPriority(.mustHold, for: queryValuesPopup)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueTextField)
            controlsStackView.setVisibilityPriority(.notVisible, for: queryValueDatePicker)
        } else {
            queryValueTextField.formatter = field.formatter
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

        value = currentValue
        
    }
    
//    @IBAction func fieldAction(_ sender: NSPopUpButton) {
////        guard let field = sender.representedObject as? QueryField
//        guard let field = sender.selectedItem?.representedObject as? Field
//                else { return }
//        
//        updateRow(for: field)
//        action(sender)
//    }
    /**
     Configure the interface for the passed DB.
     */
    func configure(for db: DB) {
        fieldsPopupManager.configure(for: db, in: self, action: #selector(action(_:))) //fieldAction(_:)))
    }
    
}
