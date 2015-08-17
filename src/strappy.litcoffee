Configuration Variables
=======================

    wskey = '''<%= wskey %>'''
    thisLibrary =
      oclcSymbol: '''<%= thisLibrary.oclcSymbol %>'''
      name: '''<%= thisLibrary.name %>'''
    crossDomainProxy = '''<%= crossDomainProxy %>'''

strapTemplate
=============

    strapTemplate = '''<%= strapTemplate %>'''

loadScripts()
=============
This function iterates over a list of script urls, loads them asynchronously,
and calls our callback when all are loaded.

    loadScripts = (scripts, callback) ->

Only try to load the script if the corresponding value in the passed object is
true.

      urls = Object.keys(scripts).filter((s) ->
        scripts[s]
      )

      callback() if not urls.length

Load the remaining urls.

      for url in urls
        do (url) ->
          script = document.createElement('script')

          script.addEventListener('load', () ->
            urls = urls.filter((s) ->
              s isnt url
            )

If there aren't any unloaded scripts left, call the callback.

            callback() if not urls.length
          )

          script.setAttribute('src', url)
          script.setAttribute('async', 'async')

          document.body.appendChild(script)

worldcatNamespaceResolver()
===========================
This function allows us to use `document.evaluate()` with the heavily-namespaced
xml documents the ILL policies directory API returns.

    worldcatNamespaceResolver = (() ->
      namespacePrefixes =
        'ns10': 'http://worldcat.org/servicePolicyAggregateFees'

      (namespacePrefix) ->
        namespacePrefixes[namespacePrefix] || null
    )()

strap()
=======
This function holds all the logic for what we want to do, so that we can run it
after jQuery loads, if that was necessary.

    strap = () ->

Since, by this point, we have jQuery and lodash. Relinquish control of `$` and
`_` and then get them back as local variables.

First, save lodash as a property of `window` so that we don't keep reloading it.

      window._lodash = _.noConflict() if not window._lodash

      (($, _) ->

Get the currently active transaction panel.

        transactionPanel = $('.yui3-viewpanel:not(.yui3-viewpanel-hidden):not(.sidebar-accordion)')

Figure out whether this is a loan or a borrow.

        isBorrow = _.any(transactionPanel.attr('class').split(/\s+/), (_class) ->
          _class.indexOf('nd:borrowing') isnt -1
        )

Collect transaction metadata.

        transaction =
          id: transactionPanel.find('.accordionRequestDetailsRequestId').text()
          canRenew: isBorrow and false # Temporary
          item:
            title: transactionPanel.find('[data="resource.title"]').text()
            author: transactionPanel.find('[data="resource.author"]').text()
          patron:
            name: transactionPanel.find('.yui-field-name').val()

For some reason, loans don't use the `.yui-field-originalDueDate` syntax for the
due date, so we have to search for the data field, which is consistent.

          dueDate: transactionPanel.find('[data="returning.originalDueToSupplier"]').text()

The ILL interface doesn't give us a consistently straightforward way to get a
clean string with the other library's name. It is particularly difficult for
loans, which are the transactions in which it is more important for us to print
the borrowing library's name on the bookstrap!

The best option seems to be pulling out the OCLC symbol and using the
ILL policies directory API to request an XML file which will include a useful
string, especially since we can also try to get renewal information.

---

First, get the OCLC symbol.

          otherLibrary =
            oclcSymbol: transactionPanel.find('.nd-pdlink').attr('href')?.match(/instSymbol=(.{3})/)[1]

          if not otherLibrary.oclcSymbol?
            otherLibrary = { oclcSymbol: '', name: '' }
          else

Make an API request to the ILL policies directory.

The wskey is sent as a url parameter so that the proxy doesn't need to be
configured to accept an additional header on the 'OPTIONS' request.

            $.ajax(crossDomainProxy,
              data:
                csurl: 'https://ill.sd00.worldcat.org/illpolicies/servicePolicy/servicePolicyAggregateFees'
                inst: library.oclcSymbol
                wskey: wskey
              dataType: 'xml'
            )
            .done((data) ->
              alias = document.evaluate('//ns10:institutionAlias', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent
              name = document.evaluate('//ns10:name', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent

              name = "#{alias}, #{name}" if alias?
              name = '' if not name?

              otherLibrary.name = name
            )
            .fail(() ->
              otherLibrary.name = ''
            )
            .always(() ->

            )

          return library
        )()

        if isBorrow
          transaction.lender = otherLibrary
          transaction.borrower = thisLibrary
        else
          transaction.lender = thisLibrary
          transaction.borrower = otherLibrary

getRenewalInformation()
-----------------------
If this is a loan, we don't allow renewals.

If this is a borrow, check the ILL policies directory. If renewals information
is listed and is non-zero, renewals are possible. If renewals information is
listed and is zero, renewals are not possible. If renewals information isn't
listed, we're in am ambiguous state.

        # "https://ill.sd00.worldcat.org/illpolicies/servicePolicy/#{inst_id}?wskey=#{wskey}"
        # May not be there... in which case need something indicating ambiguity.
        # transaction.canRenew

renderBookstrap()
-----------------
This function handles the actual rendering of the bookstrap from the mustache
template in an iframe. It is called once the information-gathering AJAX calls to
the ILL policies directory API have completed.

        renderBookstrap = (transaction) ->
          frame = $('#strappy-iframe')

          frame = $(document.createElement('iframe')) if not frame[0]

          frame.attr('id', 'strappy-iframe')
          frame.attr('srcdoc', Mustache.render(strapTemplate, transaction))
          frame.attr('sandbox', 'allow-same-origin allow-scripts allow-modal')

          frame.css(
            top: 0
            left: 0
            width: '100%'
            height: '100%'
            position: 'fixed'
            'z-index': 10000
          )

          frame.show()

On frame load, make the barcode.

          frame.one('load', () ->
            window['_strappyBarcode'] = new Barcode({
              height: '0.5in',
              maxWidth: '2.5in',
              thicknessFactor: 3
            }) if not window['_strappyBarcode']?

            _strappyBarcode.get(transaction.id, (barcode) ->
              $(frame[0].contentDocument).find('.barcode').prepend(barcode)
            , (error) ->
              console.log(error)
            )
          )

Add the iframe to the document.

          $(document.body).append(frame)

      )(jQuery.noConflict(), window._lodash)

Startup
=======
Conditionally load the various scripts that will make this much easier. Don't
load them if their products already exist, if, for instance, the page hasn't
been reloaded since the bookmarklet was last used.

---

May want to add [wicked-good-xpath](https://github.com/google/wicked-good-xpath)
to this, so that `document.evaluate()` works in IE. (Would this bookmarklet work
in IE?)

    loadScripts({
      'https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js': not window.jQuery?
      'https://cdnjs.cloudflare.com/ajax/libs/lodash.js/3.10.1/lodash.min.js': not window._lodash?
      'https://cdnjs.cloudflare.com/ajax/libs/mustache.js/2.1.3/mustache.min.js': not window.Mustache?
    }, strap)
