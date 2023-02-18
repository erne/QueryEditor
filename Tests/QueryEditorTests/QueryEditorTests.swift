import XCTest
@testable import QueryEditor

class DB: QueryDB {
    let bos: [BO]
    
    init(bos: [BO]) {
        self.bos = bos
    }
}

class BO: NSObject, QueryBO {

    var type: BOType
    var name: String
    var fields: [Field] = []
    var searchableFields: [Field] { fields }
    var orderFields: [Field] = []
    
    let alias: String
    var displayName: String { NSLocalizedString(name, comment: name) }
    
    init(name: String, alias: String, type: BOType) {
        self.alias = alias.isEmpty ? name : alias
        self.name = name
        self.type = type
    }
    
    @discardableResult func createField(name: String, type: FieldType) -> Field {
        let field = Field(name: name, type: type, bo: self)
        fields.append(field)
        return field
    }
    
    func field(forName name: String) -> Field? {
        searchableFields.first { $0.name == name }
    }
}

class Artists: BO {
    lazy var nameField = createField(name: "name", type: .string)
    lazy var birthdayField = createField(name: "birthday", type: .date)
    lazy var maleField = createField(name: "male", type: .boolean)
    lazy var opusField = createField(name: "opus", type: .number)

    init(addAlias: Bool = false) {
        let alias = addAlias ? "a" : ""
        super.init(name: "Artists", alias: alias, type: .table)

        [nameField, birthdayField, maleField, opusField].forEach { let _ = $0 }
        
//        let _ = createField(name: "name", type: .string)
//        self.birthdayField = createField(name: "birthday", type: .date)
//        self.maleField = createField(name: "male", type: .boolean)
//        self.opusField = createField(name: "opus", type: .number)
    }
    
}

class QueryLink: BO {
    
}

class Field: NSObject, QueryField {
//    typealias BO = QueryBO
    let bo: BO
    let name: String
    let fieldType: FieldType
    var label: String { name }
    
    fileprivate init(name: String, type: FieldType, bo: BO) {
        self.name = name
        self.fieldType = type
        self.bo = bo
    }
}

class MyQueryEditorRow: QueryEditorRow<DB, BO, Field> {}

final class QueryEditorTests: XCTestCase {
    func testCreateDB(addAlias: Bool = false) -> DB {
        let db: DB = DB(bos: [Artists(addAlias: addAlias)])
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
        XCTAssertEqual(QuerySelect(select: bo.fields.first?.name ?? "",
                                   bo: bo,
                                   alias: addFieldAlias ? "artist name" : nil).expression,
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
        XCTAssertEqual(QueryFrom(bo: bo).expression, addAlias ? "[Artists] a" : "[Artists]")
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

    func queryWhere(type: FieldType = .string, addBOAlias: Bool = false, operator: SqlOperator = .equal, addFieldAlias: Bool = false) {
//        let db = testCreateDB(addAlias: addBOAlias)
        
        switch type {
        case .string:
            let operators: [SqlOperator] = [.equal, .beginsWith, .endsWith, .contains]
            operators.forEach { queryWhereString(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .number:
            let operators: [SqlOperator] = [.equal, .lessOrEqual, .less, .greaterOrEqual, .greater]
            operators.forEach { queryWhereNumber(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .date:
            let operators: [SqlOperator] = [.equal, .lessOrEqual, .less, .greaterOrEqual, .greater]
            operators.forEach { queryWhereDate(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        case .boolean:
            let operators: [SqlOperator] = [.equal, .notEqual]
            operators.forEach { queryWhereBool(addBOAlias: addBOAlias, operator: $0, addFieldAlias: addFieldAlias) }
        default:
            break
        }
        
    }
    
    func queryWhereString(addBOAlias: Bool = false, operator: SqlOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.nameField else { fatalError("test failed") }
        
        let expected: String = {
            let leftArgument = (addFieldAlias ? "[string field]" : (addBOAlias ? "a.name" : "Artists.name"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = 'Dylan'"
            case .beginsWith:
                return "LEFT(\(leftArgument), 5) = 'Dylan'"
            case .endsWith:
                return "RIGHT(\(leftArgument), 5) = 'Dylan'"
            case .contains:
                return "\(leftArgument) LIKE '%Dylan%'"
            default:
                return ""
            }
        }()
        
        let expression = QueryWhere(fieldExpression: field.name,
                                    value: "Dylan",
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "string field" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)

    }
    
    func queryWhereDate(addBOAlias: Bool = false, operator: SqlOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.birthdayField else { fatalError("test failed") }
        
        let sep = Locale.current.dateSeparator

        let expected: String = {
            let leftArgument = (addFieldAlias ? "[date field]" : (addBOAlias ? "a.birthday" : "Artists.birthday"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = '08\(sep)05\(sep)1959'"
            case .less:
                return "\(leftArgument) < '08\(sep)05\(sep)1959'"
            case .lessOrEqual:
                return "\(leftArgument) <= '08\(sep)05\(sep)1959'"
            case .greater:
                return "\(leftArgument) > '08\(sep)05\(sep)1959'"
            case .greaterOrEqual:
                return "\(leftArgument) >= '08\(sep)05\(sep)1959'"
            default:
                return ""
            }
        }()
        
        let expression = QueryWhere(fieldExpression: field.name,
                                    value: dateValue("08-05-1959"),
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "date field" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func queryWhereNumber(addBOAlias: Bool = false, operator: SqlOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.opusField else { fatalError("test failed") }

        let expected: String = {
            let leftArgument = (addFieldAlias ? "[number field]" : (addBOAlias ? "a.opus" : "Artists.opus"))
            switch `operator` {
            case .equal:
                return "\(leftArgument) = 7"
            case .less:
                return "\(leftArgument) < 7"
            case .lessOrEqual:
                return "\(leftArgument) <= 7"
            case .greater:
                return "\(leftArgument) > 7"
            case .greaterOrEqual:
                return "\(leftArgument) >= 7"
            default:
                return ""
            }
        }()
        
        let expression = QueryWhere(fieldExpression: field.name,
                                    value: 7,
                                    operator: `operator`,
                                    bo: bo,
                                    fieldAlias: addFieldAlias ? "number field" : nil).expression
        
        print(expression)

        XCTAssertEqual(expression,
                       expected)
    }
    
    func queryWhereBool(addBOAlias: Bool = false, operator: SqlOperator = .equal, addFieldAlias: Bool = false) {
        let db = testCreateDB(addAlias: addBOAlias)
        guard let bo = db.bos.first,
            let field = (bo as? Artists)?.maleField else { fatalError("test failed") }

        let expected: String = {
            let leftArgument = (addFieldAlias ? "[bool field]" : (addBOAlias ? "a.male" : "Artists.male"))
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
        FieldType.allCases.forEach {
            queryWhere(type: $0)
            queryWhere(type: $0, addBOAlias: true)
            queryWhere(type: $0, addBOAlias: true, addFieldAlias: true)
        }
    }
    
    static var allTests = [
        ("testCreateDB", testCreateDB),
        ("testQueryBO", testQueryBO),
        ("testQuerySelect", testQuerySelect),
        ("testQueryFrom", testQueryFrom ),
        ("testQueryGroup", testQueryGroup ),
        ("testQueryOrder", testQueryOrder ),
        ("testQueryWhere", testQueryWhere )
        ] as [Any]
}
