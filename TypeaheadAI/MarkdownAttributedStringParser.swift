//
//  MarkdownAttributedStringParser.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/12/23.
//

import Foundation
import AppKit
import Markdown
import Highlighter

/// Based on the source code from Christian Selig
/// https://github.com/christianselig/Markdownosaur/blob/main/Sources/Markdownosaur/Markdownosaur.swift
public struct MarkdownAttributedStringParser: MarkupVisitor {
    let baseFontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    var highlighter: Highlighter = Highlighter()!

    let newLineFontSize: CGFloat = 12

    public init(isDarkMode: Bool) {
        if isDarkMode {
            self.highlighter.setTheme(HighlighterConstants.darkTheme)
        } else {
            self.highlighter.setTheme(HighlighterConstants.lightTheme)
        }
    }

    public mutating func attributedString(from document: Document) -> NSAttributedString {
        return visit(document)
    }

    mutating func parserResults(from document: Document) -> [ParserResult] {
        var results = [ParserResult]()
        var currentAttrString = NSMutableAttributedString()

        func appendCurrentAttrString() {
            if !currentAttrString.string.isEmpty {
                let currentAttrStringToAppend = (try? AttributedString(currentAttrString, including: \.appKit)) ?? AttributedString(stringLiteral: currentAttrString.string)
                results.append(.init(id: UUID(), attributedString: currentAttrStringToAppend, parsedType: .plaintext))
            }
        }

        document.children.forEach { markup in
            let attrString = visit(markup)
            if let codeBlock = markup as? CodeBlock {
                appendCurrentAttrString()
                let attrStringToAppend = (try? AttributedString(attrString, including: \.appKit)) ?? AttributedString(stringLiteral: attrString.string)
                results.append(.init(id: UUID(), attributedString: attrStringToAppend, parsedType: .codeBlock(language: codeBlock.language)))
                currentAttrString = NSMutableAttributedString()
            } else if let _ = markup as? Table {
                appendCurrentAttrString()
                let attrStringToAppend = (try? AttributedString(attrString, including: \.appKit)) ?? AttributedString(stringLiteral: attrString.string)
                results.append(.init(id: UUID(), attributedString: attrStringToAppend, parsedType: .table))
                currentAttrString = NSMutableAttributedString()
            } else {
                currentAttrString.append(attrString)
            }
        }

        appendCurrentAttrString()
        return results
    }

    mutating public func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in markup.children {
            result.append(visit(child))
        }

        return result
    }

    mutating public func visitText(_ text: Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [.font: NSFont.systemFont(ofSize: baseFontSize, weight: .regular)])
    }

    mutating public func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in emphasis.children {
            result.append(visit(child))
        }

        result.applyEmphasis()

        return result
    }

    mutating public func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in strong.children {
            result.append(visit(child))
        }

        result.applyStrong()

        return result
    }

    mutating public func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in paragraph.children {
            result.append(visit(child))
        }

        if paragraph.hasSuccessor {
            result.append(paragraph.isContainedInList ? .singleNewline(withFontSize: newLineFontSize) : .doubleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    /// Save the table as a TSV in the NSAttributedString
    mutating public func visitTable(_ table: Table) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Headers
        let headers = table.head.cells.map { $0.plainText }
        let headerString = headers.joined(separator: "\t") + "\n"
        let headerAttributedString = NSAttributedString(
            string: headerString,
            attributes: [NSAttributedString.Key.font: baseFontSize]
        )
        result.append(headerAttributedString)

        // Rows
        for row in table.body.rows {
            let cells = row.cells.map { $0.plainText }
            let rowString = cells.joined(separator: "\t") + "\n"
            let rowAttributedString = NSAttributedString(string: rowString)
            result.append(rowAttributedString)
        }

        if table.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }

        return result
    }

    mutating public func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in heading.children {
            result.append(visit(child))
        }

        result.applyHeading(withLevel: heading.level)

        if heading.hasSuccessor {
            result.append(.doubleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    mutating public func visitLink(_ link: Link) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in link.children {
            result.append(visit(child))
        }

        let url = link.destination != nil ? URL(string: link.destination!) : nil

        result.applyLink(withURL: url)

        return result
    }

    mutating public func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        return NSAttributedString(string: inlineCode.code, attributes: [.font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular), .foregroundColor: NSColor.systemPink])
    }

    public func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: highlighter.highlight(codeBlock.code, as: codeBlock.language) ?? NSAttributedString(string: codeBlock.code))

        if codeBlock.hasSuccessor {
            result.append(.singleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    mutating public func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in strikethrough.children {
            result.append(visit(child))
        }

        result.applyStrikethrough()

        return result
    }

    mutating public func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let font = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)

        for listItem in unorderedList.listItems {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]

            let listItemParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(unorderedList.listDepth))
            let spacingFromIndex: CGFloat = 8.0
            let bulletWidth = ceil(NSAttributedString(string: "•", attributes: [.font: font]).size().width)
            let firstTabLocation = leftMarginOffset + bulletWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]

            listItemParagraphStyle.headIndent = secondTabLocation

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
            listItemAttributes[.listDepth] = unorderedList.listDepth

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString
            listItemAttributedString.insert(NSAttributedString(string: "\t•\t", attributes: listItemAttributes), at: 0)

            result.append(listItemAttributedString)
        }

        if unorderedList.hasSuccessor {
            result.append(.doubleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    mutating public func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in listItem.children {
            result.append(visit(child))
        }

        if listItem.hasSuccessor {
            result.append(.singleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    mutating public func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, listItem) in orderedList.listItems.enumerated() {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]

            let font = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
            let numeralFont = NSFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)

            let listItemParagraphStyle = NSMutableParagraphStyle()

            // Implement a base amount to be spaced from the left side at all times to better visually differentiate it as a list
            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(orderedList.listDepth))

            // Grab the highest number to be displayed and measure its width (yes normally some digits are wider than others but since we're using the numeral mono font all will be the same width in this case)
            let highestNumberInList = orderedList.childCount
            let numeralColumnWidth = ceil(NSAttributedString(string: "\(highestNumberInList).", attributes: [.font: numeralFont]).size().width)

            let spacingFromIndex: CGFloat = 8.0
            let firstTabLocation = leftMarginOffset + numeralColumnWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]

            listItemParagraphStyle.headIndent = secondTabLocation

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.listDepth] = orderedList.listDepth

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString

            // Same as the normal list attributes, but for prettiness in formatting we want to use the cool monospaced numeral font
            var numberAttributes = listItemAttributes
            numberAttributes[.font] = numeralFont

            let numberAttributedString = NSAttributedString(string: "\t\(index + 1).\t", attributes: numberAttributes)
            listItemAttributedString.insert(numberAttributedString, at: 0)

            result.append(listItemAttributedString)
        }

        if orderedList.hasSuccessor {
            result.append(orderedList.isContainedInList ? .singleNewline(withFontSize: newLineFontSize) : .doubleNewline(withFontSize: newLineFontSize))
        }

        return result
    }

    mutating public func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in blockQuote.children {
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]

            let quoteParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(blockQuote.quoteDepth))

            quoteParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: leftMarginOffset)]

            quoteParagraphStyle.headIndent = leftMarginOffset

            quoteAttributes[.paragraphStyle] = quoteParagraphStyle
            quoteAttributes[.font] = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
            quoteAttributes[.listDepth] = blockQuote.quoteDepth

            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString
            quoteAttributedString.insert(NSAttributedString(string: "\t", attributes: quoteAttributes), at: 0)

            quoteAttributedString.addAttribute(.foregroundColor, value: NSColor.systemGray)

            result.append(quoteAttributedString)
        }

        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(withFontSize: newLineFontSize))
        }

        return result
    }
}

// MARK: - Extensions Land

extension NSMutableAttributedString {
    func applyEmphasis() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? NSFont else { return }

            if let newFont = font.apply(newTraits: .italic) {
                addAttribute(.font, value: newFont, range: range)
            }
        }
    }

    func applyStrong() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? NSFont else { return }

            if let newFont = font.apply(newTraits: .bold) {
                addAttribute(.font, value: newFont, range: range)
            }
        }
    }

    func applyLink(withURL url: URL?) {
        addAttribute(.foregroundColor, value: NSColor.systemBlue)

        if let url = url {
            addAttribute(.link, value: url)
        }
    }

    func applyBlockquote() {
        addAttribute(.foregroundColor, value: NSColor.systemGray)
    }

    func applyHeading(withLevel headingLevel: Int) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, stop in
            guard let font = value as? NSFont else { return }

            if let newFont = font.apply(newTraits: .bold, newPointSize: 28.0 - CGFloat(headingLevel * 2)) {
                addAttribute(.font, value: newFont, range: range)
            }
        }
    }

    func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }
}

extension NSFont {
    func apply(newTraits: NSFontDescriptor.SymbolicTraits, newPointSize: CGFloat? = nil) -> NSFont? {
        var existingTraits = fontDescriptor.symbolicTraits
        existingTraits.insert(newTraits)

        let newFontDescriptor = fontDescriptor.withSymbolicTraits(existingTraits)
        return NSFont(descriptor: newFontDescriptor, size: newPointSize ?? pointSize)
    }
}

extension ListItemContainer {
    /// Depth of the list if nested within others. Index starts at 0.
    var listDepth: Int {
        var index = 0

        var currentElement = parent

        while currentElement != nil {
            if currentElement is ListItemContainer {
                index += 1
            }

            currentElement = currentElement?.parent
        }

        return index
    }
}

extension BlockQuote {
    /// Depth of the quote if nested within others. Index starts at 0.
    var quoteDepth: Int {
        var index = 0

        var currentElement = parent

        while currentElement != nil {
            if currentElement is BlockQuote {
                index += 1
            }

            currentElement = currentElement?.parent
        }

        return index
    }
}

extension NSAttributedString.Key {
    static let listDepth = NSAttributedString.Key("ListDepth")
    static let quoteDepth = NSAttributedString.Key("QuoteDepth")
}

extension NSMutableAttributedString {
    func addAttribute(_ name: NSAttributedString.Key, value: Any) {
        addAttribute(name, value: value, range: NSRange(location: 0, length: length))
    }

    func addAttributes(_ attrs: [NSAttributedString.Key : Any]) {
        addAttributes(attrs, range: NSRange(location: 0, length: length))
    }
}

extension Markup {
    /// Returns true if this element has sibling elements after it.
    var hasSuccessor: Bool {
        guard let childCount = parent?.childCount else { return false }
        return indexInParent < childCount - 1
    }

    var isContainedInList: Bool {
        var currentElement = parent

        while currentElement != nil {
            if currentElement is ListItemContainer {
                return true
            }

            currentElement = currentElement?.parent
        }

        return false
    }
}

extension NSAttributedString {
    static func singleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .regular)])
    }

    static func doubleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
}
