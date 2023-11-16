import XCTest
@testable import QueryEditor

class DB: QueryDB {
    var bos:[BO] = []
    
//    init(bos: [BO]) {
//        self.bos = bos
//    }
}

class BO: NSObject, QueryBO {

    weak var db: DB!
    var type: QueryBOType
    var name: String
    var fields: [Field] = []
    var searchableFields: [Field] { fields }
    var orderFields: [Field] = []
    var links: [Link] = []
    var queryable = true

    let alias: String
    var displayName: String { NSLocalizedString(name, comment: name) }
    
    init(in db: DB, name: String, alias: String, type: QueryBOType) {
        self.db = db
        self.alias = alias.isEmpty ? name : alias
        self.name = name
        self.type = type
        
        super.init()
        db.bos.append(self)
    }
    
    @discardableResult func createField(name: String, type: QueryFieldType) -> Field {
        let field = Field(name: name, type: type, bo: self)
        fields.append(field)
        return field
    }
    
    func field(forName name: String) -> Field? {
        searchableFields.first { $0.name == name }
    }
}

class Field: NSObject, QueryField {
    var presetValues: [AnyHashable]?
    
    var formatter: Formatter?
    
    var allowedOperators: [QueryOperator]?
    
//    typealias BO = QueryBO
    let bo: BO
    let name: String
    let fieldType: QueryFieldType
    var label: String { name }
    var queryable = true
    
    fileprivate init(name: String, type: QueryFieldType, bo: BO) {
        self.name = name
        self.fieldType = type
        self.bo = bo
    }
}

class PointerField: Field, QueryPointerField {
    let target: BO
    
    init(name: String, bo: BO, target: BO) {
        self.target = target
        super.init(name: name, type: .link, bo: bo)
    }
}

class BOLinker: BO, QueryBOLinker  {
    var aPtr: PointerField
    var bPtr: PointerField

    init(inBO1: BO, inBO2: BO) {
        guard let db = inBO1.db,
            db === inBO2.db
            else { fatalError("invalid BOs DB") }
        
        let linker = "Linker"
        let alias = "\(inBO1.alias)\(inBO2.alias)k"
        let leftLinkStr = inBO1.name.prefix(3)
        let rightLinkStr = inBO2.name.prefix(3)
        let name: String = {
            let string = "\(leftLinkStr)_\(rightLinkStr)_\(linker)"
            var name = string
            var i = 0
            while db.linkNames.contains(name) {
                i += 1
                name = "\(string)\(i)"
            }
            return name
        }()
        
        
        let leftPtrName = "\(leftLinkStr)_ptr"
        aPtr = PointerField(name: leftPtrName,
                            bo: inBO1,
                            target: inBO2)
        let rightPtrName = "\(rightLinkStr)_ptr"
        bPtr = PointerField(name: rightPtrName,
                            bo: inBO2,
                            target: inBO2)

        super.init(in: db, name: name, alias: alias, type: .linker)
    }
}

class Link: NSObject, QueryLink {
    typealias Linker = BOLinker
    
    let name: String
    let branches: [BO]
    
    init(name: String, branches: [BO]) {
        self.name = name
        self.branches = branches
    }
    
    func isBetween(_ aBO: BO, anotherBO: BO) -> Bool {
        branches.contains(aBO) && branches.contains(anotherBO)
    }
}

class Artists: BO {
    lazy var nameField = createField(name: "name", type: .string)
    lazy var birthdayField = createField(name: "birthday", type: .date)
    lazy var maleField = createField(name: "male", type: .boolean)
    lazy var opusField = createField(name: "opus", type: .number)

    init(in db: DB, addAlias: Bool = false) {
        let alias = addAlias ? "a" : ""
        super.init(in: db, name: "Artists", alias: alias, type: .table)

        [nameField, birthdayField, maleField, opusField].forEach { let _ = $0 }
        
//        let _ = createField(name: "name", type: .string)
//        self.birthdayField = createField(name: "birthday", type: .date)
//        self.maleField = createField(name: "male", type: .boolean)
//        self.opusField = createField(name: "opus", type: .number)
    }
    
}

class MyQueryEditorRow: QueryEditorRow<DB> {}

class MyQuery: Query<DB> {
    func setup(bo: BO, selectField: Field, whereField: Field, value: AnyHashable, op: QueryOperator) {
        
        selectFields.append(QuerySelect(fieldExpression: selectField.name, bo: bo))
        
        whereExpressions.append(QueryWhere(fieldExpression: whereField.name,
                                           value: value,
                                           operator: op,
                                           bo: bo,
                                           fieldAlias: nil))
    }
}

final class QueryEditorTests: XCTestCase {
    func testCreateDB(addAlias: Bool = false) -> DB {
        let db: DB = DB() //bos: [Artists(addAlias: addAlias)])
        db.bos.append(Artists(in: db, addAlias: addAlias))
        let bo = db.bos.first
        XCTAssertEqual(bo?.name, "Artists")
        return db
    }
    
    func queryBO(addAlias: Bool = false) {
        let db = testCreateDB(addAlias: addAlias)
        XCTAssertEqual(db.bos.first?.recIdAlias, addAlias ? "a_recId" : "Artists_recId")
        XCTAssertEqual(db.bos.first?.displayName, "Artists")
        XCTAssertEqual(db.bos.first?.field(forName: "name")?.fieldType, .string)
    }
    
    func testQueryBO() {
        queryBO()
        queryBO(addAlias: true)
    }
    
    func querySelect(addBOAlias: Bool = false, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first else { fatalError("test failed") }
        XCTAssertEqual(QuerySelect(fieldExpression: bo.fields.first?.name ?? "",
                                   bo: bo,
                                   fieldAlias: addFieldAlias ? "artist name" : nil).expression,
                       (addBOAlias ?
                        (addFieldAlias ? "a.name as [artist name]" : "a.name")  :
                        (addFieldAlias ? "Artists.name as [artist name]" : "Artists.name")))
    }

    func testQuerySelect() {
        querySelect()
        querySelect(addBOAlias: true, addFieldAlias: true)
    }
    
    func queryFrom(addAlias: Bool = false) {
        let db = testCreateDB(addAlias: addAlias)
        guard let bo = db.bos.first else { fatalError("test failed") }
        XCTAssertEqual(QueryFrom(fromBos: [bo]).expression, addAlias ? "[Artists] a" : "[Artists]")
    }
    
    func testQueryFrom() {
        queryFrom()
        queryFrom(addAlias: true)
    }
    
    func queryGroup(addBOAlias: Bool = false, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = bo.fields.first?.name else { fatalError("test failed") }
        
        let expected = addFieldAlias ? "[artist name]" :
            (addBOAlias ? "a.name" : "Artists.name")
        
        let expression = QueryGroup(fieldExpression: field,
                                    bo: bo,
                                    alias: addFieldAlias ? "artist name" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func testQueryGroup() {
        queryGroup()
        queryGroup(addBOAlias: true, addFieldAlias: true)
        queryGroup(addBOAlias: false, addFieldAlias: true)
        queryGroup(addBOAlias: true, addFieldAlias: false)
    }
    
    func queryOrder(addBOAlias: Bool = false, addFieldAlias: Bool = false, descending: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = bo.fields.first?.name else { fatalError("test failed") }
        
        let expected = addFieldAlias ? (descending ? "[artist name] DESC" : "[artist name]") :
            (addBOAlias ? (descending ? "a.name DESC" : "a.name") : (descending ? "Artists.name DESC" : "Artists.name"))
        
        let expression = QueryOrder(fieldExpression: field,
                                    bo: bo,
                                    alias: addFieldAlias ? "artist name" : nil,
                                    descending: descending).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func testQueryOrder() {
        queryOrder()
        queryOrder(addBOAlias: true, addFieldAlias: true, descending: true)
        queryOrder(addBOAlias: false, addFieldAlias: true, descending: true)
        queryOrder(addBOAlias: false, addFieldAlias: true, descending: false)
        queryOrder(addBOAlias: false, addFieldAlias: false, descending: true)
        queryOrder(addBOAlias: true, addFieldAlias: false, descending: false)
        queryOrder(addBOAlias: true, addFieldAlias: true, descending: false)
        queryOrder(addBOAlias: true, addFieldAlias: false, descending: false)
        queryOrder(addBOAlias: true, addFieldAlias: false, descending: true)
    }
    
    func queryWhere(type: QueryFieldType = .string, addBOAlias: Bool = false, operator: QueryOperator = .equal, addFieldAlias: Bool = false) {
//        let db = testCreateDB(addAlias: addBOAlias)
        
        switch type {
        case .string:
//            let operators: [QueryOperator] = [.equal, .beginsWith, .endsWith, .contains]
            type.allowedOperators.forEach { queryWhereString(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .number:
//            let operators: [QueryOperator] = [.equal, .lessOrEqual, .less, .greaterOrEqual, .greater]
            type.allowedOperators.forEach { queryWhereNumber(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .date:
//            let operators: [QueryOperator] = [.equal, .lessOrEqual, .less, .greaterOrEqual, .greater]
            type.allowedOperators.forEach { queryWhereDate(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .boolean:
//            let operators: [QueryOperator] = [.equal, .notEqual]
            type.allowedOperators.forEach { queryWhereBool(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        default:
            break
        }
        
    }
    
    func queryWhereString(addBOAlias: Bool = false, operator: QueryOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.nameField else { fatalError("test failed") }
        
        let expected: String = {
            let leftArgument = (addBOAlias ? "a.name" : "Artists.name") //(addFieldAlias ? "[string field]" : (addBOAlias ? "a.name" : "Artists.name"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = 'Dylan'"
            case .notEqual:
                return "\(leftArgument) <> 'Dylan'"
            case .like:
                return "\(leftArgument) LIKE 'Dylan'"
            case .notLike:
                return "\(leftArgument) NOT LIKE 'Dylan'"
            case .beginsWith:
                return "LEFT(\(leftArgument), 5) = 'Dylan'"
            case .endsWith:
                return "RIGHT(\(leftArgument), 5) = 'Dylan'"
            case .contains:
                return "\(leftArgument) LIKE '%Dylan%'"
            case .in:
                return "\(leftArgument) IN ('Dylan', 'Marley', 'Zappa')"
            case .notIn:
                return "\(leftArgument) NOT IN ('Dylan', 'Marley', 'Zappa')"
            default:
                return ""
            }
        }()
        
        let value: AnyHashable = {
            switch `operator` {
            case .in, .notIn:
                return ["Dylan", "Marley", "Zappa"]
            default:
                return "Dylan"
            }
        }()

        let queryWhere = QueryWhere(fieldExpression: field.name,
                                    value: value,
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "string field" : nil)
        
        let expression = queryWhere.expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
        
        let otherQueryWhere = QueryWhere(fieldExpression: field.name,
                                    value: "Rolling Stones",
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "string field" : nil)

        XCTAssertNotEqual(queryWhere,
                          otherQueryWhere)


    }
    
    func queryWhereDate(addBOAlias: Bool = false, operator: QueryOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.birthdayField else { fatalError("test failed") }
        
        let sep = Locale.current.dateSeparator

        let expected: String = {
            let leftArgument = (addBOAlias ? "a.birthday" : "Artists.birthday") //(addFieldAlias ? "[date field]" : (addBOAlias ? "a.birthday" : "Artists.birthday"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = '08\(sep)05\(sep)1959'"
            case .notEqual:
                return "\(leftArgument) <> '08\(sep)05\(sep)1959'"
            case .less:
                return "\(leftArgument) < '08\(sep)05\(sep)1959'"
            case .lessOrEqual:
                return "\(leftArgument) <= '08\(sep)05\(sep)1959'"
            case .greater:
                return "\(leftArgument) > '08\(sep)05\(sep)1959'"
            case .greaterOrEqual:
                return "\(leftArgument) >= '08\(sep)05\(sep)1959'"
            case .in:
                return "\(leftArgument) IN ('08\(sep)05\(sep)1959', '02\(sep)12\(sep)1957')"
            case .notIn:
                return "\(leftArgument) NOT IN ('08\(sep)05\(sep)1959', '02\(sep)12\(sep)1957')"
            default:
                return ""
            }
        }()
        
        let value: AnyHashable = {
            switch `operator` {
            case .in, .notIn:
                return [dateValue("08-05-1959"), dateValue("02-12-1957")]
            default:
                return dateValue("08-05-1959")
            }
        }()

        let expression = QueryWhere(fieldExpression: field.name,
                                    value: value,
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "date field" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func queryWhereNumber(addBOAlias: Bool = false, operator: QueryOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.opusField else { fatalError("test failed") }

        let expected: String = {
            let leftArgument = (addBOAlias ? "a.opus" : "Artists.opus") //(addFieldAlias ? "[number field]" : (addBOAlias ? "a.opus" : "Artists.opus"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = 7"
            case .notEqual:
                return "\(leftArgument) <> 7"
            case .like:
                return "\(leftArgument) LIKE 7"
            case .notLike:
                return "\(leftArgument) NOT LIKE 7"
            case .less:
                return "\(leftArgument) < 7"
            case .lessOrEqual:
                return "\(leftArgument) <= 7"
            case .greater:
                return "\(leftArgument) > 7"
            case .greaterOrEqual:
                return "\(leftArgument) >= 7"
            case .in:
                return "\(leftArgument) IN (8, 5, 1959)"
            case .notIn:
                return "\(leftArgument) NOT IN (8, 5, 1959)"
            default:
                return ""
            }
        }()
        
        let value: AnyHashable = {
            switch `operator` {
            case .in, .notIn:
                return [8, 5, 1959]
            default:
                return 7
            }
        }()
        
        let expression = QueryWhere(fieldExpression: field.name,
                                    value: value,
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "number field" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func queryWhereBool(addBOAlias: Bool = false, operator: QueryOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.maleField else { fatalError("test failed") }

        let expected: String = {
            let leftArgument = (addBOAlias ? "a.male" : "Artists.male") //(addFieldAlias ? "[bool field]" : (addBOAlias ? "a.male" : "Artists.male"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = TRUE"
            case .notEqual:
                return "\(leftArgument) <> TRUE"
            default:
                return ""
            }
        }()
        
        let expression = QueryWhere(fieldExpression: field.name,
                                    value: true,
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "bool field" : nil).expression
        
        print(expression)
        XCTAssertEqual(expression,
                       expected)
    }

    func testQueryWhere() {
        QueryFieldType.allCases.forEach {
            queryWhere(type: $0)
            queryWhere(type: $0, addBOAlias: true)
            queryWhere(type: $0, addBOAlias: true, addFieldAlias: true)
        }
    }
    
    func testMerge() {
        let db = testCreateDB(addAlias: true)
        guard let bo = db.bos.first,
            let numberField = (bo as? Artists)?.opusField,
            let stringField = (bo as? Artists)?.nameField else { fatalError("test failed") }

        let expression = QueryWhere(fieldExpression: numberField.name,
                                    value: 23,
                                    operator: .greater,
                                    bo: bo,
                                    fieldAlias: nil)
        
        let query = Query(db: db)
        query.selectFields.append(QuerySelect(fieldExpression: numberField.name, bo: bo))
        query.whereExpressions.append(expression)
        
        print(query.sqlString ?? "bad sql")

        let myQuery = MyQuery(db: db)
        myQuery.setup(bo: bo,
                      selectField: stringField,
                      whereField: stringField,
                      value: "Erne",
                      op: .beginsWith)
        
        print(myQuery.sqlString ?? "bad sql")
        
//        let expression2 = QueryWhere(fieldExpression: stringField.name,
//                                    value: "Erne",
//                                    operator: .beginsWith,
//                                    bo: bo,
//                                    fieldAlias: nil)
//
//        let query2 = Query(db: db)
//        query2.selectFields.append(QuerySelect(fieldExpression: stringField.name, bo: bo))
//        query2.whereExpressions.append(expression2)
//
//        print(query2.sqlString ?? "bad sql")

        query.merge(with: myQuery)

        print(query.sqlString ?? "bad sql")

        XCTAssertTrue(query.whereExpressions.count == 2)

    }
    
//    func testQueryEditor() {
//        let db = testCreateDB(addAlias: true)
//        guard let bo = db.bos.first,
//            let field = (bo as? Artists)?.nameField else { fatalError("test failed") }
//
////        let expected: String = {
////            let leftArgument = (addFieldAlias ? "[string field]" : (addBOAlias ? "a.name" : "Artists.name"))
////            switch `operator` {
////            case .equal:
////                return "\(leftArgument) = 'Dylan'"
////            case .beginsWith:
////                return "LEFT(\(leftArgument), 5) = 'Dylan'"
////            case .endsWith:
////                return "RIGHT(\(leftArgument), 5) = 'Dylan'"
////            case .contains:
////                return "\(leftArgument) LIKE '%Dylan%'"
////            default:
////                return ""
////            }
////        }()
//
//        let queryWhere = QueryWhere(fieldExpression: field.name,
//                                    value: "Dylan",
//                                    operator: .equal,
//                                    bo: bo,
//                                    fieldAlias: nil)
//
//        let query = Query(db: db)
//        query.whereExpressions = [queryWhere]
//        let editor = QueryEditor<DB>(nibName: "QueryEditor", bundle: nil)
//        let window = NSWindow(contentRect: editor.view.bounds, styleMask: [], backing: .buffered, defer: true)
//        window.contentViewController = editor
//        window.orderFront(nil)
//        XCTAssertTrue(editor.isViewLoaded)
//        editor.query = query
//        let bosPopup = editor.bosPopup
//        XCTAssertEqual(bosPopup?.item(at: 0)?.title, "Artists")
//    }
    
    static var allTests = [
        ("testCreateDB", testCreateDB),
        ("testQueryBO", testQueryBO),
        ("testQuerySelect", testQuerySelect),
        ("testQueryFrom", testQueryFrom ),
        ("testQueryGroup", testQueryGroup ),
        ("testQueryOrder", testQueryOrder ),
        ("testQueryWhere", testQueryWhere ),
        ("testMerge", testMerge)
        ] as [Any]
}
