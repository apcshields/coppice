    ###
    Code39 barcode-generating library

    Its chief distinguishing feature is the ability to specify the max width of
    the resulting barcode.
    ###

    class Barcode
      defaultConfig:
        height: '3em'
        maxWidth: '300px'
        color: '#000'
        backgroundColor: 'rgba(0, 0, 0, 0)' # This won't affect printed barcodes—browsers are reluctant to print background colors.
        thicknessFactor: 3
      translationTable:
        '0': '000110100'
        '1': '100100001'
        '2': '001100001'
        '3': '101100000'
        '4': '000110001'
        '5': '100110000'
        '6': '001110000'
        '7': '000100101'
        '8': '100100100'
        '9': '001100100'
        'A': '100001001'
        'B': '001001001'
        'C': '101001000'
        'D': '000011001'
        'E': '100011000'
        'F': '001011000'
        'G': '000001101'
        'H': '100001100'
        'I': '001001100'
        'J': '000011100'
        'K': '100000011'
        'L': '001000011'
        'M': '101000010'
        'N': '000010011'
        'O': '100010010'
        'P': '001010010'
        'Q': '000000111'
        'R': '100000110'
        'S': '001000110'
        'T': '000010110'
        'U': '110000001'
        'V': '011000001'
        'W': '111000000'
        'X': '010010001'
        'Y': '110010000'
        'Z': '011010000'
        '-': '010000101'
        '.': '110000100'
        ' ': '011000100'
        '*': '010010100'
        '+': '000100000'
        '/': '000001000'
        '$': '000000010'
        '%': '010000000'

      measuredCodes: {}

      constructor: (config) ->
        @config = {}

        jQuery.extend(@config, @defaultConfig, config)

        @config.maxWidth = @calculateWidth(@config.maxWidth)

        @last = null
        @thinWidth = 1

      get: (string) ->
        deferred = jQuery.Deferred()

        try

Get ready to store information about the last call and its products.

          @last =
            string: string
            cleanString: null
            codes: null
            barcode: null

Check for occurrences of character representation of the start/stop symbol in
the middle of the string. If found, stop and reject. Otherwise, add the
character representation to the beginning and the end.

          string = string[1..] if string[0] is '*'
          string = string[..-1] if string[-1..] is '*'

          if string.indexOf('*') isnt -1
            throw 'Error: The string may not contain "*" except as the first and last characters.'

          @last.cleanString = string

          string = '*' + string + '*'

Convert the string to uppercase.

          string = string.toUpperCase()

Get an array of the codes for the string characters.

          codes = jQuery.map(string.split(''), @getCharacterRepresentation)

          @last.codes = codes

Calculate the length of the full code.

Since each character contains five lines and four spaces, of which either two
lines and one space may be thick or no lines and three spaces may be thick, each
character is represented by six thin elements and three thick elements. In
addition to this, each pair of characters is separated by a thin space.

Therefore, the total length is the total number of thin elements in codes (6 ×
the number of codes) plus the total number of thick elements (3 × the number of
codes) times the `thicknessFactor` plus the number of spaces.

          codeLength = (7 * codes.length) + (3 * codes.length * @config.thicknessFactor) - 1

Calculate the thinWidth for the barcode.

          @thinWidth = @config.maxWidth / codeLength

If `@thinWidth` is less than 1, throw an error.

          if @thinWidth < 1
            throw 'Error: The calculated width of narrow bars and spaces is too small to render properly.'

Create the container element for the barcode.

          barcodeContainer = jQuery(document.createElement('div')).addClass('barcode')

Add the string to be encoded as a custom data attribute.

          barcodeContainer.attr('data-barcode', string)

Build the representative elements and add them to the barcode container one by one.

          jQuery.each(codes, (index, code) =>

Add the space between characters, unless this is the last character.

            code += '0' unless index is codes.length - 1

Create the container element for the character, add the character as a custom
data attribute, and append the element to the container element for the barcode.

            characterContainer = jQuery(document.createElement('span')).addClass('barcode-character')

            characterContainer.attr('data-barcode-character', string[index])

            barcodeContainer.append(characterContainer)

Step through the code, two elements at a time, creating an HTML element and
assigning it the appropriate values.

            for index in [0..(code.length - 1)] by 2
              do (index) =>
                element = @makeElement()

                @makeLine(element, code[index] is '0')

Only try to add the spacing to the element if a spacing instruction exists. The
length of `code` will be odd if this is the last pair of the last character,
and, in that case, `code[index + 1] is undefined`.

                @makeSpace(element, code[index + 1] is '0') if code[index + 1]?

Add the element to the container for the character.

                characterContainer.append(element)
          )

Resolve with the barcode container.

          @last.barcode = barcodeContainer

          deferred.resolve(barcodeContainer)
        catch error
          deferred.reject(error)

      getCharacterRepresentation: (character) =>
        return @translationTable[character]

      makeElement: () ->
        return jQuery(document.createElement('span'))
               .addClass('barcode-element')
               .css(
                 'display': 'inline-block'
                 'height': @config.height
                 'background': @config.backgroundColor
                 'border-left-color': @config.color
                 'border-left-style': 'solid'
               )

Lines use border.

      makeLine: (element, thin = true) ->
        jQuery(element)
        .css('border-left-width', @getElementWidth(thin) + 'px')
        .addClass('barcode-line-' + (if thin then 'thin' else 'thick'))

Spaces use padding.

      makeSpace: (element, thin = true) ->
        jQuery(element)
        .css('padding-left', @getElementWidth(thin) + 'px')
        .addClass('barcode-space-' + (if thin then 'thin' else 'thick'))

      calculateWidth: (width) ->
        return @calculateWidth(@defaultConfig.width) if typeof width isnt 'string' and typeof width isnt 'number'

        testElement = jQuery(document.createElement('span'))
        .css('display', 'block')
        .css('width', width)

        jQuery(document.body).append(testElement)

        calculatedWidth = testElement.width()

        testElement.remove()

        return calculatedWidth

      getElementWidth: (thin = true) ->

Calculate the width of a single thin element.

        return if thin then @thinWidth else @thinWidth * @config.thicknessFactor

    window.Barcode = Barcode
