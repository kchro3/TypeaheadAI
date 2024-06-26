//
//  String+XMLMarkdown.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//  Copied from https://github.com/caching-guru/SwiftHtmlMarkdown
//

import Foundation
import SwiftSoup

public enum XMLMarkdownError: Error {
    case invalidElement(String)
}

public struct HtmlMarkdownConfig {
    public enum UnknownElementConfig {
        case throwError
        case render
        case ignore
    }

    public var throwUnknownElement: UnknownElementConfig

    public init(throwUnknownElement: UnknownElementConfig) {
        self.throwUnknownElement = throwUnknownElement
    }

    public static var defaultConfig = HtmlMarkdownConfig(throwUnknownElement: .ignore)
}

public extension String {

    func renderXMLToMarkdown(_ config: HtmlMarkdownConfig = HtmlMarkdownConfig.defaultConfig) -> String {
        do {
            let doc: SwiftSoup.Document = try SwiftSoup.parse(self)
            var markdown = ""
            let els =  doc.getChildNodes()
            for e in els {
                markdown = markdown + (try self.renderChildNode(e, config))
            }
            return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("error: ", error)
        }

        return ""
    }

    func renderTableColumn(_ node: Node, index: Int, columnWidths:[Int]) throws -> String {
        let name = node.nodeName()
        if name != "td" {
            throw XMLMarkdownError.invalidElement("expected td but got \(name)")
        }
        var r = ""
        for n in node.getChildNodes() {
            r = r + (try self.renderChildNode(n, HtmlMarkdownConfig.defaultConfig))
        }
        let desiredLength = columnWidths[index]
        while r.count < desiredLength {
            r = r + " "
        }
        return " " + r + " |"
    }
    
    func renderTableSeperatorRow(columnWidths:[Int]) throws -> String {
        var r = "|";
        for index in 0..<columnWidths.count {
            var filler = ""
            for _ in 0..<columnWidths[index] {
                filler = filler + "-"
            }
            r = r + " \(filler) |"

        }
        return r + "\n"
    }

    func renderTableRow(_ node: Node, columnWidths:[Int]) throws -> String {
        let name = node.nodeName()
        if name != "tr" {
            throw XMLMarkdownError.invalidElement("expected tr but got \(name)")
        }
        var r = "|";
        var index = 0
        for n in node.getChildNodes() {
            if n.nodeName() == "td" {
                r = r + (try self.renderTableColumn(n, index: index, columnWidths:columnWidths))
                index = index + 1
            }
        }
        return r + "\n"
    }

    func renderTableHead(_ node: Node?, columnWidths:[Int]) throws -> String {
        var r = ""

        if let node = node {
            for e in node.getChildNodes() {
                if e.nodeName() == "tr" {
                    r = r + (try self.renderTableRow(e, columnWidths: columnWidths))
                }
            }
        } else {
            // Add an empty header row
            r += "|";
            for index in 0..<columnWidths.count {
                var filler = ""
                for _ in 0..<columnWidths[index] {
                    filler = filler + " "
                }
                r = r + " \(filler) |"

            }
            r = r + "\n"
        }

        r = r + (try self.renderTableSeperatorRow(columnWidths: columnWidths))
        return r
    }

    func renderTableFood(_ node: Node, columnWidths:[Int]) throws -> String {
        var r = try self.renderTableSeperatorRow(columnWidths: columnWidths)
        for e in node.getChildNodes() {
            if e.nodeName() == "tr" {
                r = r + (try self.renderTableRow(e, columnWidths: columnWidths))
            }
        }
        return r
    }

    func renderTable(_ node: Node) throws -> String {
        var r = ""
        var columnWidths:[Int] = []
        var rows:[Node] = []
        for n in node.getChildNodes() {
            if n.nodeName() == "thead" {
                for n2 in n.getChildNodes() {
                    if n2.nodeName() == "tr" {
                        rows.append(n2)
                    }
                }
            } else if n.nodeName() == "colgroup" {
                for n2 in n.getChildNodes() {
                    if n2.nodeName() == "col",
                       let widthString = n2.getAttributes()?.get(key: "width"),
                       let width = Int(widthString) {
                        columnWidths.append(width)
                    }
                }
            } else if n.nodeName() == "tbody" {
                for n2 in n.getChildNodes() {
                    if n2.nodeName() == "tr" {
                        rows.append(n2)
                    }
                }
            } else if n.nodeName() == "tfood", let _ = n.getChildNodes().first {
                for n2 in n.getChildNodes() {
                    if n2.nodeName() == "tr" {
                        rows.append(n2)
                    }
                }
            } else if n.nodeName() == "tr" {
                rows.append(n)
            }
        }
        for row in rows {
            var i = 0
            for td in row.getChildNodes() {
                if td.nodeName() == "td" {
                    let l = (try self.renderChildNode(td, HtmlMarkdownConfig.defaultConfig)).count
                    if columnWidths.count <= i {
                        columnWidths.append(0)
                    }
                    if l > columnWidths[i] {
                        columnWidths[i] = l
                    }
                    i = i + 1
                }
            }
        }

        var isHeaderMissing = true
        for n in node.getChildNodes() {
            if n.nodeName() == "thead" {
                isHeaderMissing = false
                r = r + (try self.renderTableHead(n, columnWidths: columnWidths))
            } else if n.nodeName() == "tbody" {
                for n2 in n.getChildNodes() {
                    if n2.nodeName() == "tr" {
                        r = r + (try self.renderTableRow(n2, columnWidths: columnWidths))
                    }
                }
            } else if n.nodeName() == "tfood" {


                r = r + (try self.renderTableFood(n, columnWidths: columnWidths))
            } else if n.nodeName() == "tr" {
                r = r + (try self.renderTableRow(n, columnWidths: columnWidths))

            }
        }

        if isHeaderMissing {
            r = (try self.renderTableHead(nil, columnWidths: columnWidths)) + r
        }

        return r
    }

    func renderChildNode(_ node: SwiftSoup.Node, _ config: HtmlMarkdownConfig, counter: Int = 0) throws -> String {
        let name = node.nodeName()

        var r = ""
        var counter1 = counter
        if ["html", "head", "body", "meta", "div", "span"].contains(name) {

        }
        else if name == "h1" {
            r = r + "# "
        } else if name == "h2" {
            r = r + "## "
        } else if name == "h3" {
            r = r + "### "
        } else if name == "h4" {
            r = r + "#### "
        } else if name == "h5" {
            r = r + "##### "
        } else if name == "h5" {
            r = r + "##### "
        } else if name == "h6" {
            r = r + "###### "
        } else if name == "i" {
            r = r + "_"
        } else if name == "s" {
            r = r + "~~"
        } else if name == "strong" {
            r = r + "**"
        } else if name == "p" {
            r = r + ""
        } else if name == "br" {
            r = r + "\n"
        } else if name == "code" {
            var language = ""
            var inline = false
            if let c = node.getAttributes()?.get(key: "class") {
                let classes = c.split(separator: " ")
                for cl in classes {
                    if cl.prefix(9) == "language-" {
                        let index = cl.index(cl.startIndex, offsetBy: 9)
                        language = String(cl[index...])
                    }
                    if cl == "inline" {
                        inline = true
                    }
                }
            }
            if language == "javascript" && inline {
                r = r + "`"
                let accum: StringBuilder = StringBuilder()
                for node in node.getChildNodes() {
                    try node.outerHtml(accum)
                }
                return r + accum.toString() + "`"
            } else {
                r = r + "```\(language)\n"
                let accum: StringBuilder = StringBuilder()
                for node in node.getChildNodes() {
                    try node.outerHtml(accum)
                }
                return r + accum.toString() + "```\n\n"
            }
        } else if name == "ol" {
            counter1 = 1
            for cn in node.getChildNodes() {
                if cn.nodeName() == "li" {
                    r = r + (try renderChildNode(cn, config, counter: counter1))
                    counter1 = counter1 + 1
                }
            }
            return r
        } else if name == "ul" {
            for cn in node.getChildNodes() {
                counter1 = 0
                if cn.nodeName() == "li" {
                    r = r + (try renderChildNode(cn, config, counter: counter1))
                }
            }
            return r
        } else if name == "table" {
            return r + (try self.renderTable(node))
        } else if name == "img" {
            if let src = node.getAttributes()?.get(key: "src") {
                let alt = node.getAttributes()?.get(key: "alt") ?? ""
                var title = node.getAttributes()?.get(key: "title") ?? ""
                if title != "" {
                    title = " \"\(title)\""
                }
                r = r + "![\(alt)](\(src)\(title))"
            }
            // img's don't have children :)
            return r

        } else if name == "a" {

            r = r + "["
        } else if name == "pre" {
            // now we expect "code" next, or at least prepare of it

        } else if name == "hr" {
            r = r + "\n---\n"
        } else if name == "blockquote" {
            var renderedBlock = ""
            for cn in node.getChildNodes() {
                renderedBlock = renderedBlock + (try renderChildNode(cn, config, counter: counter1))
            }
            renderedBlock = "> " + renderedBlock.replacingOccurrences(of: "\n", with: "\n> ")
            return renderedBlock
        } else if name == "htmltag" {
            for cn in node.getChildNodes() {
                r = r + (try renderChildNode(cn, HtmlMarkdownConfig(throwUnknownElement: .render), counter: counter1))
            }
            return r
        } else if name == "li" {
            if counter1 > 0 {
                r = r + "\(counter1). "
            }
            else {
                r = r + "* "
            }
        } else if let t = node as? TextNode {
            r = r + t.text()
        } else if name == "td" {
            // nothing special
        }
        else {
            if config.throwUnknownElement == .throwError {
                // we are throwing here to make sure we don't get messed up HTML
                // this will also allow us to deliberately ignore errors if so desired
                throw XMLMarkdownError.invalidElement("\(name) is not known")
            } else if config.throwUnknownElement == .ignore {
                print("unknown, rendering: ", name)
            } else if config.throwUnknownElement == .render {
                return try node.outerHtml()
            } else {
                print("unknown, rendering: ", name)
            }
        }

        for cn in node.getChildNodes() {
            r = r + (try renderChildNode(cn, config, counter: counter1))
        }

        if name == "p" {
            r = r + "\n\n"
        } else if name == "a" {
            if let href = node.getAttributes()?.get(key: "href") {
                r = r + "](\(href))"
            } else {
                r = r + "]"
            }
        } else if name == "h1" {
            r = r + "\n\n"
        } else if name == "h2" {
            r = r + "\n\n"
        } else if name == "h3" {
            r = r + "\n\n"
        } else if name == "h4" {
            r = r + "\n\n"
        } else if name == "h5" {
            r = r + "\n"
        } else if name == "h5" {
            r = r + "\n"
        } else if name == "h6" {
            r = r + "\n"
        } else if name == "i" {
            r = r + "_"
        } else if name == "strong" {
            r = r + "**"
        } else if name == "s" {
            r = r + "~~"
        }
        return r
    }
}
