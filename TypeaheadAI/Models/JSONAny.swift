//
//  JSONAny.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/2/24.
//

import Foundation

// Custom type to handle various JSON value types
enum JSONAny: Codable, Equatable {
    case string(String)
    case double(Double)
    case integer(Int)
    case boolean(Bool)
    case array([JSONAny])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .integer(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .boolean(boolVal)
        } else if let arrayVal = try? container.decode([JSONAny].self) {
            self = .array(arrayVal)
        } else {
            throw DecodingError.typeMismatch(JSONAny.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Value is not JSON compatible"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .double(let num):
            try container.encode(num)
        case .integer(let int):
            try container.encode(int)
        case .boolean(let bool):
            try container.encode(bool)
        case .array(let arrayVal):
            try container.encode(arrayVal)
        }
    }
}
