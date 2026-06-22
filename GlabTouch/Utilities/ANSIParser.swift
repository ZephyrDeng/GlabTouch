import SwiftUI

struct ANSIParser {
    static func parse(_ input: String, colorScheme: ColorScheme) -> AttributedString {
        let palette = colorScheme == .dark ? ANSIColorPalette.dark : ANSIColorPalette.light
        var state = ANSIState()
        var output = AttributedString()
        var buffer = ""
        var index = input.startIndex

        func appendBuffer() {
            guard buffer.isEmpty == false else { return }
            output += AttributedString(buffer, attributes: state.attributes)
            buffer.removeAll(keepingCapacity: true)
        }

        while index < input.endIndex {
            guard input[index] == "\u{1B}" else {
                buffer.append(input[index])
                index = input.index(after: index)
                continue
            }

            appendBuffer()
            index = parseEscapeSequence(in: input, from: index, state: &state, palette: palette)
        }

        appendBuffer()
        return output
    }

    private struct ANSIState {
        var foreground: Color?
        var background: Color?
        var isBold = false

        var attributes: AttributeContainer {
            var attributes = AttributeContainer()
            if let foreground {
                attributes.foregroundColor = foreground
            }
            if let background {
                attributes.backgroundColor = background
            }
            if isBold {
                attributes.inlinePresentationIntent = .stronglyEmphasized
            }
            return attributes
        }
    }

    private static func parseEscapeSequence(
        in input: String,
        from escapeIndex: String.Index,
        state: inout ANSIState,
        palette: ANSIColorPalette.Palette
    ) -> String.Index {
        let nextIndex = input.index(after: escapeIndex)
        guard nextIndex < input.endIndex else { return nextIndex }

        switch input[nextIndex] {
        case "[":
            return parseCSISequence(
                in: input,
                from: input.index(after: nextIndex),
                state: &state,
                palette: palette
            )
        case "]":
            return indexAfterOSCSequence(in: input, from: input.index(after: nextIndex))
        default:
            return input.index(after: nextIndex)
        }
    }

    private static func parseCSISequence(
        in input: String,
        from parameterStart: String.Index,
        state: inout ANSIState,
        palette: ANSIColorPalette.Palette
    ) -> String.Index {
        var cursor = parameterStart

        while cursor < input.endIndex {
            let character = input[cursor]
            guard isCSISequenceFinal(character) == false else {
                if character == "m" {
                    applySGRParameters(input[parameterStart..<cursor], state: &state, palette: palette)
                }
                return input.index(after: cursor)
            }
            cursor = input.index(after: cursor)
        }

        return input.endIndex
    }

    private static func indexAfterOSCSequence(in input: String, from contentStart: String.Index) -> String.Index {
        var cursor = contentStart

        while cursor < input.endIndex {
            if input[cursor] == "\u{7}" {
                return input.index(after: cursor)
            }

            if input[cursor] == "\u{1B}" {
                let nextIndex = input.index(after: cursor)
                if nextIndex < input.endIndex, input[nextIndex] == "\\" {
                    return input.index(after: nextIndex)
                }
            }

            cursor = input.index(after: cursor)
        }

        return input.endIndex
    }

    private static func applySGRParameters(
        _ parameters: Substring,
        state: inout ANSIState,
        palette: ANSIColorPalette.Palette
    ) {
        let codes = sgrCodes(from: parameters)
        var index = 0

        while index < codes.count {
            switch codes[index] {
            case 0:
                state = ANSIState()
                index += 1
            case 1:
                state.isBold = true
                index += 1
            case 30...37:
                state.foreground = palette.colors[codes[index] - 30]
                index += 1
            case 40...47:
                state.background = palette.colors[codes[index] - 40]
                index += 1
            case 90...97:
                state.foreground = palette.colors[codes[index] - 90 + 8]
                index += 1
            case 100...107:
                state.background = palette.colors[codes[index] - 100 + 8]
                index += 1
            case 38:
                state.foreground = nil
                index += extendedColorParameterLength(in: codes, at: index)
            case 48:
                state.background = nil
                index += extendedColorParameterLength(in: codes, at: index)
            case 39:
                state.foreground = nil
                index += 1
            case 49:
                state.background = nil
                index += 1
            default:
                index += 1
            }
        }
    }

    private static func sgrCodes(from parameters: Substring) -> [Int] {
        guard parameters.isEmpty == false else { return [0] }

        return parameters
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { parameter in
                guard parameter.isEmpty == false else { return 0 }
                return Int(parameter) ?? -1
            }
    }

    private static func extendedColorParameterLength(in codes: [Int], at index: Int) -> Int {
        guard index + 1 < codes.count else { return 1 }

        switch codes[index + 1] {
        case 5:
            return 3
        case 2:
            return 5
        default:
            return 1
        }
    }

    private static func isCSISequenceFinal(_ character: Character) -> Bool {
        guard let value = character.unicodeScalars.first?.value,
              character.unicodeScalars.count == 1
        else { return false }

        return (0x40...0x7E).contains(value)
    }
}
