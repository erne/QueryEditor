//
//  Query.swift
//  Draggable Grid View
//
//  Created by Erne on 04-01-23.
//  Copyright © 2023 Apimac. All rights reserved.
//


import Cocoa
import Collections
import StringExtensions
import DateExtensions

// MARK: - Values handling

public func stringValue(_ value: Any?) -> String? {
    guard let value = value else { return nil }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }

    return nil
}
public func boolValue(_ value: Any?) -> Bool? {
    guard let value = value else { return nil }
    if let bool = value as? Bool { return bool }
    if let string = value as? String { return NSString(string: string).boolValue }
    if let number = value as? NSNumber { return number.boolValue }

    return nil
}
public func numberValue(_ value: Any?) -> NSNumber? {
    guard let value = value else { return nil }
    if let number = value as? NSNumber { return number }
    if let string = value as? String { return NumberFormatter().number(from: string) }

    return nil
}
public func dateValue(_ value: Any?) -> Date? {
    guard let value = value else { return nil }
    if let date = value as? Date { return date }
    if let string = value as? String { return string.dateValue } // DateFormatter().date(from: string) }

    return nil
}

/**
 Protocol defining the database to be queried.
 */
public protocol QueryDB {
    associatedtype BO: QueryBO
    
    var bos: [BO] { get }
}

public extension QueryDB {
    typealias Linker = BO.Link.Linker
    var linkers: [Linker] { bos.compactMap { $0 as? Linker } }
    var linkNames: [String] { linkers.map { $0.name } }
}
/**
 Protocol defining the base object (BO aka table) of database.
 */
public protocol QueryBO: NSObject {
    associatedtype DB: QueryDB
    associatedtype Field: QueryField
    associatedtype Link: QueryLink
    
    var db: DB! { get }
    var name: String { get }
    var type: QueryBOType { get }
    var alias: String { get }
    var fields: [Field] { get }
    var searchableFields: [Field] { get }
    var orderFields: [Field] { get }
    var links: [Link] { get }
}

extension QueryBO {
    var recIdAlias: String { "\(alias)_\(QueryBOKey.recId)" }
    var displayName: String { NSLocalizedString(name, comment: name) }
    func field(forName name: String) -> Field? {
        searchableFields.first { $0.name == name }
    }
}
/**
 Protocol defining the BO used to establish a many to many link between BOs.
 */
public protocol QueryBOLinker: QueryBO {
    associatedtype PointerField: QueryPointerField
    
    var aPtr: PointerField { get }
    var bPtr: PointerField { get }
}

extension QueryBOLinker {
    func isPointerTo(_ bo: Self) -> Bool {
        aPtr.target == bo ||
        bPtr.target == bo
    }
    
    func otherTarget(knownTarget: Self) -> Self {
        if aPtr.target == knownTarget {
            return bPtr.target as! Self
        }
        return aPtr.target as! Self
    }

    func ptrField(pointingAt bo: Self) -> PointerField? {
        if aPtr.target == bo {
            return aPtr
        } else if bPtr.target == bo {
            return bPtr
        }
        return nil
    }

}
/**
 Protocol defining a link between BOs.
 */
public protocol QueryLink: NSObject {
    associatedtype BO: QueryBO
    associatedtype Linker: QueryBOLinker

    var name: String { get }
    /**
     The linked BOs.
     */
    var branches: [BO] { get }
    /**
     Whether the link joins the passed BOs.
     */
    func isBetween(_ aBO: BO, anotherBO: BO) -> Bool
}

extension QueryLink {
    /**
     Get the BOLinker pointed by this link, if any.
     */
    var boLinker: Linker? {
        branches.compactMap { $0 as? Linker }.first
    }
    /**
     The table pointed by a 2 branches link that is not the passed one.
     */
    func otherBO(knownBO: BO) -> BO? {
        precondition(branches.count == 2, "wrong number of branches in link")
        return branches.first { $0 != knownBO }
    }
    func isBetween(_ aBO: BO, anotherBO: BO) -> Bool {
        branches.contains(aBO) && branches.contains(anotherBO)
    }
}
/**
 Protocol defining the field holding data in the BO.
 */
public protocol QueryField: NSObject {
    associatedtype BO: QueryBO
    
    var bo: BO { get }
    var name: String { get }
    var fieldType: QueryFieldType { get }
    var label: String { get }
    var presetValues: [AnyHashable]? { get }
    var formatter: Formatter? { get }
    var allowedOperators: [QueryOperator]? { get }
}
/**
 Protocol defining the field pointing to another BO.
 */
public protocol QueryPointerField: QueryField {
    var target: BO { get }
}
/**
 Useful keys to query a BO.
 */
public struct QueryBOKey {
    static let boName = "boName"
    static let recId = "recId"
    static let linked = "linked"
    static let deleted = "deleted"
}
/**
 Available BO types.
 */
public struct QueryBOType: Equatable, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static var table = QueryBOType(rawValue: "table")
    public static var linker = QueryBOType(rawValue: "linker")
    
    public var localizedStringRepresentation: String {
        return NSLocalizedString(rawValue, comment: rawValue).capitalized(with: Locale.current)
    }
}

extension QueryBOType {
    public var icon: NSImage? {
        return NSImage(named: NSImage.actionTemplateName)
    }
}
/**
 Types a field can represent.
 */
public enum QueryFieldType: String {
    case string
    case date
    case time
    case boolean
    case number
    case link
    case undefined
    /**
     Get a properly cast value from a generic Any.
     */
    func properValue(from value: AnyHashable?) -> AnyHashable? {
        switch self {
        case .string:
            return stringValue(value)
        case .date, .time:
            return dateValue(value)
        case .boolean:
            return boolValue(value)
        case .number:
            return numberValue(value)
        default:
            return value
        }
    }
    /**
     Get an array of operators fitting the type.
     */
    var allowedOperators: [QueryOperator] {
        switch self {
        case .string:
            return [.beginsWith,
                    .contains,
                    .equal,
                    .endsWith,
                    .notEqual,
                    .like,
                    .notLike]
        case .number:
            return [.equal,
                    .greater,
                    .greaterOrEqual,
                    .less,
                    .lessOrEqual,
                    .notEqual,
                    .like,
                    .notLike]
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

extension QueryFieldType: CaseIterable {}

/**
 All possible operators a query can handle.
 */
public enum QueryOperator: String {
    case beginsWith = "|="
    case equal = "="
    case contains = "|=|"
    case endsWith = "=|"
    case greater = ">"
    case greaterOrEqual = ">="
    case less = "<"
    case lessOrEqual = "<="
    case notEqual = "<>"
    case like = "LIKE"
    case notLike = "NOT LIKE"
    case regex = "REGEX"
    
}

extension QueryOperator: CaseIterable {
    var asString: String {
        switch self {
        case .beginsWith:
            return NSLocalizedString("begins with", comment: "begins with")
        case .equal:
            return NSLocalizedString("is", comment: "is") //("equals", comment: "equals")
        case .contains:
            return NSLocalizedString("contains", comment: "contains")
        case .endsWith:
            return NSLocalizedString("ends with", comment: "ends with")
        case .greater:
            return NSLocalizedString("is greater than", comment: "is greater than")
        case .greaterOrEqual:
            return NSLocalizedString("is greater or equal than", comment: "is greater or equal than")
        case .less:
            return NSLocalizedString("is lesser than", comment: "is lesser than")
        case .lessOrEqual:
            return NSLocalizedString("is lesser or equal than", comment: "is lesser or equal than")
        case .notEqual:
            return NSLocalizedString("is not", comment: "is not") //("is not equal to", comment: "is not equal to")
        case .like:
            return NSLocalizedString("like", comment: "like")
        case .notLike:
            return NSLocalizedString("not like", comment: "not like")
        case .regex:
            return NSLocalizedString("regex", comment: "regex")
        }
    }
    /**
     The list of operators as user readable strings.
     */
    static var operatorsAsString = allCases.map { $0.asString }

}

/**
 Protocol representing a query expression. At minimum it can have a BO.
 */
public protocol QueryExpression: Hashable {
    associatedtype BO: QueryBO
    /**
     The BO that the expression is related to.
     */
    var bo: BO? { get }
    /**
     The query expression, rendered as a string:
     */
    var expression: String { get }
}
/**
 Protocol for an expression that represents a BO field. It can have an alias to rename the output field.
 */
public protocol QueryFieldExpression: QueryExpression {
    var fieldExpression: String { get }
    var fieldAlias: String? { get }
}

extension QueryFieldExpression {
    /**
     Get a standard alias for the field BO.
     */
    var boAlias: String? {
        guard let bo = bo else { return nil }
        if !["RECID", "*", "**"].contains(fieldExpression.uppercased()) {
            // unless the field expression is Recid or a wildcard it must be a valid field name to be prefixed by a BO alias
            guard let _ = bo.field(forName: fieldExpression) else { return nil }
        }
        return bo.alias
    }
    /**
     Get the alias name for the select field.
     */
    var selectAlias: String? {
        return fieldAlias ?? {
            guard let bo = bo,
                fieldExpression.uppercased() == "RECID" else { return nil }
            return bo.recIdAlias // return a standard recid alias
        }()
    }
    /**
     Check two field expressions for equality, case insensitive.
     */
    static func areEqual(lhs: Self, rhs: Self) -> Bool {
        return lhs.bo == rhs.bo &&
            lhs.fieldExpression.uppercased() == rhs.fieldExpression.uppercased()
    }
    /**
     Equality operator support.
     */
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return areEqual(lhs: lhs, rhs: rhs)
    }
    /**
     Hashable support.
     */
    func hashMe(into hasher: inout Hasher) {
        hasher.combine(bo)
        hasher.combine(fieldExpression.uppercased())
    }
    /**
     Hashable support.
     */
    public func hash(into hasher: inout Hasher) {
        hashMe(into: &hasher)
    }
}
/**
 A concrete struct to represent a SQL SELECT expression.
 */
public struct QuerySelect<BO: QueryBO>: QueryFieldExpression {
    public let bo: BO?
    public let fieldExpression: String
    public let fieldAlias: String?
    /**
     Convenience initializer.
     - parameter fieldExpression: The select expression that will represent a field in the resulting query.
     - parameter bo: The required bo in the FROM sql clause, if any.
     - parameter fieldAlias: An alias name for the select field.
     */
    public init(fieldExpression: String, bo: BO? = nil, fieldAlias: String? = nil) {
        self.fieldExpression = fieldExpression
        self.bo = bo
        self.fieldAlias = fieldAlias
    }
    /**
     The string to be used in a SQL query to select a field.
     */
    public var expression: String {
        let boAliasString: String = {
            guard let alias = boAlias else { return "" }
            return "\(alias)."
        }()
        let selectAliasString: String = {
            guard let alias = selectAlias else { return "" }
            return " as [\(alias)]"
        }()
        return boAliasString + fieldExpression + selectAliasString
    }
}
/**
 A concrete struct to represent a SQL FROM expression taken from a list of BOs.
 */
public struct QueryFrom<BO: QueryBO>: QueryExpression {
    public var bo: BO? { fromBos.first }
    /**
     The BOs needed to satisfy joins and extract data.
     */
    public var fromBos = OrderedSet<BO>()
    /**
     Convenience initializer.
     - parameter bo: The required bo in the FROM sql clause, if any.
     - parameter otherFromBos: Other required BOs.
     */
    public init(fromBos: OrderedSet<BO>) {
        self.fromBos = fromBos
    }
    /**
     The string to be used in a SQL query to define which tables are to be searched.
     */
    public var expression: String {
        guard !fromBos.isEmpty else { return "" }
        return fromBos.map {
            let alias = ($0.name == $0.alias) ? "" : " \($0.alias)"
            return "[\($0.name)]\(alias)"
        }
        .joined(separator: ", ")
    }
}

/**
A concrete struct to represent a SQL from expression taken from a list of links.
*/
public struct QueryFromLinks<BO: QueryBO, Link: QueryLink>: QueryExpression {
    public let bo: BO?
    /**
     Static join type to avoid performance lag when trying to compute a more link-customized one.
     */
    let joinType: QueryJoinType
    /**
     Designated initializer
     */
    init(bo: BO? = nil, links: OrderedSet<Link>, joinType: QueryJoinType = .inner) {
        self.joinType = joinType
        self.bo = bo
        self.links = links
    }
    
    var links: OrderedSet<Link>
    /**
     The string to be used in a SQL query to define how BOs should be linked while searching.
     */
    public var expression: String {
        var processedBos = [BO]()
        var join = joinType.stringRepresentation

        func joinString(for link: Link, bo: BO) -> String? {
            guard !processedBos.contains(bo)
                else { return nil }

//            let startTime = Date()

            processedBos.append(bo)

//            let duration = Date().timeIntervalSince(startTime)
//            print("Join string processing duration: \(duration)")

            return "\(join) [\(bo.name)] \(bo.alias) ON \(link.name)"
        }

        var links = self.links
        guard !links.isEmpty
            else { return "" }
        
        let firstLink = links.removeFirst()
        var string = ""
        var strings: [String] = []

//        let startTime = Date()
        
        // root from expression in first branch of first link
        guard var branches = firstLink.branches as? [BO]
            else { fatalError("Invalid BO in link") }
        
//        guard let bo = firstLink.branches.first as? BO
//            else { fatalError("Invalid BO in link") }
        let bo = branches.removeFirst()
        
        string = "[\(bo.name)!)] \(bo.alias)"
        strings.append(string)
        processedBos.append(bo)
        // process all other branches
        branches.forEach { (branch) in
            guard let joinString = joinString(for: firstLink, bo: branch)
                else { return }
            strings.append(joinString )
        }
        
        links.forEach { (link) in
            guard let branches = link.branches as? [BO]
                else { fatalError("Invalid BO in link") }
            branches.forEach { (branch) in
                guard let joinString = joinString(for: link, bo: branch)
                    else { return }
                strings.append(joinString )
            }
        }

//        let duration = Date().timeIntervalSince(startTime)
//        print("Route links processing duration: \(duration)")

        return strings.joined(separator: "\n") //"FROM \(strings.joined(separator: "\n"))"
    }

    
}

/**
 A concrete struct to represent a SQL GROUP expression.
*/
public struct QueryGroup<BO: QueryBO>: QueryFieldExpression {
    public let bo: BO?
    public let fieldExpression: String
    public let fieldAlias: String?
    /**
     Convenience initializer.
     - parameter fieldExpression: The expression that will represent a group in the resulting query.
     - parameter bo: The required bo in the GROUP sql clause, if any.
     - parameter fieldAlias: An alias name for the group field.
     */
    public init(fieldExpression: String, bo: BO? = nil, alias: String? = nil) {
        self.bo = bo
        self.fieldExpression = fieldExpression
        self.fieldAlias = alias
    }
    /**
     The string to be used in a SQL query to determine how search results should be grouped.
     */
    public var expression: String {
        if let  alias = fieldAlias {
            return "[\(alias)]"
        } else if let boReference = boAlias ?? bo?.name {
            return "\(boReference).\(fieldExpression)"
        } else {
            return fieldExpression
        }
    }
    
}
/**
 A concrete struct to represent a SQL ORDER expression.
*/
public struct QueryOrder<BO: QueryBO>: QueryFieldExpression {
    public let bo: BO?
    public let fieldExpression: String
    public let fieldAlias: String?
    public var descending: Bool
    /**
     Convenience initializer.
     - parameter fieldExpression: The expression that will represent an order in the resulting query.
     - parameter bo: The required bo in the ORDER sql clause, if any.
     - parameter fieldAlias: An alias name for the order field.
     */
    public init(fieldExpression: String, bo: BO? = nil, alias: String? = nil, descending: Bool = false) {
        self.bo = bo
        self.fieldExpression = fieldExpression
        self.fieldAlias = alias
        self.descending = descending
    }
    /**
     The string to be used in a SQL query to determine how search results should be ordered.
     */
    public var expression: String {
        let orderString: String = {
            if let  alias = fieldAlias {
                return "[\(alias)]"
            } else {
                let boReference = boAlias ?? bo?.name ?? ""
                return "\(boReference).\(fieldExpression)"
            }
        }()
        let descendingString = descending ? " DESC" : ""
        return orderString + descendingString

    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return areEqual(lhs: lhs, rhs: rhs) &&
            lhs.descending == rhs.descending
    }
    
    public func hash(into hasher: inout Hasher) {
        hashMe(into: &hasher)
        hasher.combine(descending)
    }

}
/**
 Supported logical operators in query expressions, currently supported are 'AND', 'AND NOT', 'OR', 'OR NOT'.
 */
public enum QueryLogicalOperator {
    /**
     'AND' operator, 'AND NOT' if not assetive.
     */
    case and (assertive: Bool = true)
    /**
     'OR' operator, 'OR NOT' if not assetive.
     */
    case or (assertive: Bool = true)
    
    var asString: String {
        switch self {
        case .and:
            return "AND"
        case .or:
            return "OR"
        }
    }
    /**
     True if the operator does not involve a negation.
     */
    var assertive: Bool {
        switch self {
        case .and(let assertive):
            return assertive
        case .or(let assertive):
            return assertive
        }
    }
    /**
     The operator rendered as a string.
     - parameter atBeginning: When true the operator will be omitted.
     */
    func stringRepresentation(atBeginning: Bool = false) -> String {
        let logical = atBeginning ? "" : " \(asString) "
        let negation = (assertive ? "" : " NOT ")
        return "\(logical)\(negation)"
    }
}

extension QueryLogicalOperator: Hashable {}

extension NSComparisonPredicate.Operator {
    var sqlOperator: QueryOperator {
        switch self {
        case .beginsWith:
            return .beginsWith
        case .endsWith:
            return .endsWith
        case .contains:
            return .contains
        case .equalTo:
            return .equal
        case .greaterThan:
            return .greater
        case .greaterThanOrEqualTo:
            return .greaterOrEqual
        case .lessThan:
            return .less
        case .lessThanOrEqualTo:
            return .lessOrEqual
        case .notEqualTo:
            return .notEqual
        default:
            fatalError("unsupported oprator")
        }
    }
}

/**
A concrete struct to represent a SQL WHERE expression taken from a list of BOs.
*/
public struct QueryWhere<BO: QueryBO>: QueryFieldExpression {
    public let fieldExpression: String
    public let value: AnyHashable?
    public let `operator`: QueryOperator
    public let logical: QueryLogicalOperator
    public let bo: BO?
    public let fieldAlias: String?
    public let preferredType: QueryFieldType?
//    let exact: Bool
    
//    var nestedExpression: QueryWhere?
    
    /**
     Designated initializer for a where expression.
     - parameter fieldExpression: The string identifying a BO field or an expression that will be used as left argument in the WHERE expression.
     - parameter value: The value to be used as right argument in the WHERE expression.
     - parameter operator: The operator to be used to compare the left and right arguments of the WHERE predicate.
     - parameter exact: Whether a partial match will not suffice to satisfy the WHERE expression, significant only on string comparisons.
     - parameter logical: The logical operator to be used when chaining this WHERE expression to a previous one.
     - parameter bo: The BO whose data will be searched by the WHERE expression.
     - parameter alias: The alias string representing the field expression in the SQL query, if any.
     
     If fieldExpression is an empty string it will be assumed to represent a recID request.
     */
    public init(fieldExpression: String = "",
          value: AnyHashable?,
          `operator`: QueryOperator = .equal,
          logical: QueryLogicalOperator = .and(),
          bo: BO? = nil,
          fieldAlias: String? = nil,
          preferredType: QueryFieldType? = nil) {
         // assume an empty string as a recid request.
         self.fieldExpression = fieldExpression.isEmpty ? QueryBOKey.recId : fieldExpression
         self.value = value
         self.operator = `operator`
         self.logical = logical
         self.bo = bo
         self.fieldAlias = fieldAlias
         self.preferredType = preferredType
    }
    /**
     Convenience initializer converting an NSComparisonPredicate to a where expression.
     - parameter bo: The BO whose data will be searched by the WHERE expression.
     - parameter predicate: The NSPredicate to be converted in a WHERE expression.
     */
    public init(bo: BO? = nil, predicate: NSComparisonPredicate) {
        let fieldExpression = predicate.leftExpression.keyPath
        let value = predicate.rightExpression.constantValue as? AnyHashable
        let op = predicate.predicateOperatorType.sqlOperator

        self.init(fieldExpression: fieldExpression,
                  value: value,
                  operator: op,
                  bo: bo)
    }
    /**
     The SQL WHERE expression.
     */
    public var expression: String {
        // if we got a field alias use that as left argument
        var leftArgument = selectAlias ?? ""
        var type = preferredType ?? QueryFieldType.undefined
        
        if leftArgument.isEmpty {
            // no field alias, get the BO alias, if any
            let boAliasString: String = {
                guard let alias = boAlias else { return "" }
                return "\(alias)."
            }()
            if fieldExpression.isEmpty {
                // no field expression, assume we mean RecId
                leftArgument = selectAlias ?? boAliasString + QueryBOKey.recId
                if type == .undefined {
                    type = .number
                }
            } else {
                // try to get a field type using the expression as its name in the passed BO
                if let fieldType = bo?.field(forName: fieldExpression)?.fieldType {
                    leftArgument = selectAlias ?? boAliasString + fieldExpression
                    if type == .undefined {
                        type = fieldType
                    }
                } else {
                    // could be some combined expression, just use it as it is
                    leftArgument = fieldExpression
                    if type == .undefined {
                        // assume string type, better evaluation needed here
                        type = .string
                    }
                }
            }
        } else {
            leftArgument = "[\(leftArgument)]"
            if fieldExpression.isEmpty {
                type = .number
            } else {
                if let fieldType = bo?.field(forName: fieldExpression)?.fieldType {
                    type = fieldType
                } else {
                    type = .string
                }
            }
        }
        
        return expression(leftArgument: leftArgument, type: type)
    }
    /**
     Create the SQL WHERE expreesion.
     */
    private func expression(leftArgument: String, type: QueryFieldType) -> String {
        var leftArgument = leftArgument
        var rightArgument = ""
        var op = self.operator.rawValue
        switch type {
        case .string:
            let valueString = value as? String ?? ""
            rightArgument = "'\(escapeString(valueString))'"
            
            switch self.operator {
            case .beginsWith:
                leftArgument = "LEFT(\(leftArgument), \(valueString.count))"
                op = "="
            case .endsWith:
                leftArgument = "RIGHT(\(leftArgument), \(valueString.count))"
                op = "="
            case .contains:
                rightArgument = "'%\(escapeString(valueString))%'"
                op = "LIKE"
            default:
                break
            }

//            if !exact {
//                switch self.operator {
//                case .like:
//                    rightArgument = "%\(valueString)%"
//                case .regex:
//                    break
//                default:
//                    leftArgument = "LEFT(\(leftArgument), \(valueString.count))"
//                }
//            }
        case .date,
             .time:
            if let date = dateValue(value) {
                rightArgument = "'\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))'"
            } else {
                rightArgument = ""
            }
 
        case .boolean:
            rightArgument = (boolValue(value) ?? false) ? "TRUE" : "FALSE"
            
        case .number,
             .link:
            rightArgument = (numberValue(value) ?? 0).stringValue

        default:
            return "\(leftArgument) IS NULL"
        }
        
        return "\(leftArgument) \(op) \(rightArgument)"
        
    }
    
    func escapeString(_ string: String) -> String {
        switch self.operator {
        case .like:
            return string.escapedForLike
        case .regex:
            return string.escapedForRegex
        default:
            return string //vale.escape(string)
        }
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return areEqual(lhs: lhs, rhs: rhs) &&
            lhs.value == rhs.value &&
            lhs.operator == rhs.operator &&
            lhs.logical == rhs.logical
    }
    
    public func hash(into hasher: inout Hasher) {
        hashMe(into: &hasher)
        hasher.combine(value)
        hasher.combine(`operator`)
        hasher.combine(logical)
    }

}
/**
 Supported SQL JOIN types.
 */
public enum QueryJoinType: Int {
    case inner
    case leftOuter
    case rightOuter
    case fullOuter
    
    var stringRepresentation: String {
        switch self {
        case .inner:
            return "INNER JOIN"
        case .leftOuter:
            return "LEFT OUTER JOIN"
        case .rightOuter:
            return "RIGHT OUTER JOIN"
        case .fullOuter:
            return "FULL OUTER JOIN"
        }
    }
}
/**
 Query Errors
 */
public enum QueryError: Error {
    case badSql
    case valeFailure(message: String)
}
/**
 Protocol defining a SQL query.
 */
public protocol DBQuery: class {
    // The concrete database holding the data
    associatedtype DB: QueryDB
    // The concrete table holding the data
    associatedtype BO: QueryBO
    associatedtype Link: QueryLink
    /**
     The database managing the data.
     */
    var db: DB { get }
    /**
     The tables required to fulfill the query.
     */
    var requiredBos: OrderedSet<BO> { get }
    /**
     Whether only one route should be walked to fulfill the query.
     */
    var oneRouteOnly: Bool { get set }
    /**
     Whether duplicate results should be filtered out.
     */
    var distinct: Bool { get set }
    /**
     The join type for the query.
     */
    var joinType: QueryJoinType { get }

    /**
     The most significant BOs in the query.
     */
    var mainBos: OrderedSet<BO> { get set }
    /**
     The BOs referred in the SQL from clause.
     */
    var fromBos: OrderedSet<BO> { get set }
    /**
     The BOs needed to join the BOs referred by the query.
     */
    var linkerBos: OrderedSet<BO> { get set }
    /**
     The links directly joining the BOs referred by the query.
     */
    var directLinks: OrderedSet<Link> { get set }
    /**
     The expressions defining a SQL FROM clause.
     */
    var fromExpressions: OrderedSet<QueryFrom<BO>> { get set }
    /**
     The expressions defining a SQL FROM clause.
     */
    var fromLinksExpressions: OrderedSet<QueryFromLinks<BO, Link>> { get set }
    /**
     The expressions defining a SQL WHERE clause.
     */
    var whereExpressions: OrderedSet<QueryWhere<BO>> { get set }
    /**
     The expressions defining a SQL SELECT clause.
     */
    var selectFields: OrderedSet<QuerySelect<BO>> { get set }
    /**
     The expressions defining a SQL GROUP clause.
     */
    var groupFields: OrderedSet<QueryGroup<BO>> { get set }
    /**
     The expressions defining a SQL ORDER BY clause.
     */
    var orderBy: OrderedSet<QueryOrder<BO>> { get set }
    /**
     The whole SQL string.
     */
//    var sqlString: String? { get }
}

extension DBQuery {
    /**
     Add the order fields of the passed BO to the query ORDER expressions.
     */
    public func setOrderFields(bo: BO) {
        bo.orderFields.forEach { orderBy.append(QueryOrder(fieldExpression: $0.name, bo: bo)) }
    }
    /**
     All the BOs required to run the query.
     */
    public var requiredBos: OrderedSet<BO> {
        var allBos = mainBos
        allBos.append(contentsOf: fromBos)
        allBos.append(contentsOf: linkerBos)
        allBos.append(contentsOf: whereExpressions.allBos)
        allBos.append(contentsOf: selectFields.allBos)
        allBos.append(contentsOf: groupFields.allBos)
        allBos.append(contentsOf: orderBy.allBos)

        return allBos
    }
    /**
     Combine this query with the passed one.
     */
    public func merge(with query: Self) {
        whereExpressions += query.whereExpressions
        fromBos += query.fromBos
        linkerBos += query.linkerBos
        
        oneRouteOnly = oneRouteOnly || query.oneRouteOnly
        distinct = distinct || query.distinct
    }
    /**
     Set up the BOs needed to run the query.
     */
    private func setFromBos() -> Bool {
        let bos = requiredBos
        // make sure we got at least one BO
        guard let rootBo: BO = bos.first
            else { return false }

        return setFromBos(root: rootBo, required: bos)
    }
    /**
     Set up the BOs needed to run the query.
     - parameter root: The BO from where the search for required links is started.
     - parameter required: All the BOs needed to run the query.
     */
    private func setFromBos(root: BO, required: OrderedSet<BO>) -> Bool {
        if required.count == 1 {
            // 1 bo simple query
            fromExpressions.append(QueryFrom(fromBos: required + linkerBos))
        }

        return !(fromExpressions.isEmpty) // && fromLinksExpressions.isEmpty)
    }
    /**
     The SELECT clause.
     */
    var selectFieldsString: String? {
        let fields = (selectFields.compactMap { $0.expression } + orderBy.compactMap { $0.expression })
            .joined(separator: ", ")
        guard !fields.isEmpty else { return nil }
        return "SELECT \(distinct ? "DISTINCT " : "")\(fields)"
    }
    /**
     The WHERE clause.
     */
    var whereConditionsString: String {
        let conditions = whereExpressions.reduce(into: "") { (string, queryWhere) in
            let expression = queryWhere.expression
            guard !expression.isEmpty else { return }
            string.append("\(queryWhere.logical.stringRepresentation(atBeginning: (string.isEmpty)))\(expression)")
        }
        guard !conditions.isEmpty else { return "" }
        return "\nWHERE \(conditions)"
    }
    /**
     The GROUP BY clause.
     */
    var groupFieldsString: String {
        let fields = groupFields.compactMap { $0.expression }
            .joined(separator: ", ")
        guard !fields.isEmpty else { return "" }
        return "\nGROUP BY \(fields)"
    }
    /**
     The ORDER BY clause
     */
    var orderByString: String {
        let fields = orderBy.compactMap { $0.expression }
            .joined(separator: ", ")
        guard !fields.isEmpty else { return "" }
        return "\nORDER BY \(fields)"
    }
    /**
     The whole SQL string.
     */
    public var sqlString: String? {
        guard setFromBos(),
            let selectClause = selectFieldsString
            else { return nil }
        
        let whereClause = whereConditionsString
        
        let groupClause = groupFieldsString
        
        //        let startTime = Date()
        
        let from = fromExpressions.map { $0.expression } //+ fromLinksExpressions.map { $0.expression }
        
        //        let duration = Date().timeIntervalSince(startTime)
        //        print("From processing duration: \(duration)")
        
        let orderByClause = orderByString
        
        let string = from.enumerated().reduce(into: "") { (string, args) in
            let (index, expression) = args
            let fromString: String = {
                let string = "\(selectClause)\nFROM \(expression)\(whereClause)\(groupClause)"
                return (index == 0) ? string : "\nUNION\n(\(string))"
            }()
            string.append(fromString)
        }
        
        return "\(string)\(orderByClause)"
    }

}
/**
 Concrete generic Query class.
 */
open class Query<DB: QueryDB>: NSObject, DBQuery {
    public typealias BO = DB.BO
    public typealias Link = BO.Link
    
    public let db: DB
    /**
     Designated Query initializer.
     */
    public init(db: DB) {
        self.db = db
    }
    
//    deinit {
//        print("Query bye")
//    }
    
    open var oneRouteOnly = false
    open var distinct = false
    open var joinType = QueryJoinType.inner

    open var mainBos = OrderedSet<BO>()
    open var fromBos = OrderedSet<BO>()
    open var linkerBos = OrderedSet<BO>()
    open var directLinks = OrderedSet<Link>()
    open var fromExpressions = OrderedSet<QueryFrom<BO>>()
    open var fromLinksExpressions = OrderedSet<QueryFromLinks<BO, Link>>()
    open var whereExpressions = OrderedSet<QueryWhere<BO>>()
    open var selectFields = OrderedSet<QuerySelect<BO>>()
    open var groupFields = OrderedSet<QueryGroup<BO>>()
    open var orderBy = OrderedSet<QueryOrder<BO>>()
}

extension OrderedSet where Element: QueryExpression {
    typealias BO = E.BO
    /**
     Acquire all the bos contained in the QueryExpression set.
     */
    var allBos: OrderedSet<BO> {
        reduce(into: OrderedSet<BO>()) { (result, queryExpression) in
            guard let bo = queryExpression.bo else { return }
            result.append(bo)
        }
    }
}
