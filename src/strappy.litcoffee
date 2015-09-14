Configuration Variables
=======================

    wskey = '''<%= wskey %>'''
    thisLibrary =
      oclcSymbol: '''<%= thisLibrary.oclcSymbol %>'''
      name: '''<%= thisLibrary.name %>'''
      host: '''<%= thisLibrary.host %>'''
      logo: '''<%= thisLibrary.logo %>'''
    crossDomainProxy = '''<%= crossDomainProxy %>'''
    renewal =
      link: '''<%= renewal.link %>'''
      daysBeforeDueDate: <%= renewal.daysBeforeDueDate %>

strapTemplate
=============

    strapDocument = '''<%= strapDocument %>'''
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
        'ns8': 'http://worldcat.org/servicePolicyPolicy'
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

Compile the Handlebars template.

        bookstrapHandlebarsTemplate = Handlebars.compile(strapTemplate)

Get the currently active transaction panel.

        transactionPanel = $('.yui3-viewpanel:not(.yui3-viewpanel-hidden):not(.sidebar-accordion)')

Figure out whether this is a loan or a borrow.

        isBorrow = transactionPanel.children('.requestView').attr('class').indexOf('nd-borrowing') isnt -1

Collect transaction metadata.

        transaction =
          id: transactionPanel.find('.accordionRequestDetailsRequestId').text()
          us: thisLibrary
          item:
            title: transactionPanel.find('[data="resource.title"]').first().text()
            author: transactionPanel.find('[data="resource.author"]').text()
          patron:
            name: transactionPanel.find('.yui-field-name').val()
          canRenew: false
          renewal:
            link: renewal.link

For some reason, loans don't use the `.yui-field-originalDueDate` syntax for the
due date, so we have to search for the data field, which is consistent. N.B. It
may be either a static element or a form input, depending on the transaction
status.

        dueDateElement = transactionPanel.find('[data="returning.originalDueToSupplier"]')

        transaction.dueDate = if dueDateElement.text() then dueDateElement.text() else dueDateElement.val()

Calculate the renewal deadline.

        transaction.renewal.dueDate = moment(transaction.dueDate).subtract(renewal.daysBeforeDueDate, 'days').format('MM/DD/YYYY')

The ILL interface doesn't give us a consistently straightforward way to get a
clean string with the other library's name. It is particularly difficult for
loans, which are the transactions in which it is more important for us to print
the borrowing library's name on the bookstrap!

The best option seems to be pulling out the OCLC symbol and using the
ILL policies directory API to request an XML file which will include a useful
string, especially since we can also try to get renewal information.

---

In order to do this, we need to make an asynchronous call, and, if it gives us
enough information, make a second.

First, define the wrappers/processors of the asynchronous calls.

getOtherLibraryInformation()
----------------------------
This function grabs the OCLC symbol from the ILL interface and uses the ILL
policies directory API to get more information.

        getOtherLibraryInformation = () ->
          deferred = $.Deferred()

Get the OCLC symbol.

          otherLibrary =
            id: ''
            oclcSymbol: transactionPanel.find('.nd-pdlink').attr('href')?.match(/instSymbol=([^&]+)/)[1]
            name: ''
            host: ''

          if not otherLibrary.oclcSymbol?
            otherLibrary.oclcSymbol = ''

            deferred.resolve(otherLibrary)
          else

Make an API request to the ILL policies directory.

The wskey is sent as a url parameter so that the proxy doesn't need to be
configured to accept an additional header on the 'OPTIONS' request.

            $.ajax(crossDomainProxy,
              data:
                csurl: 'https://ill.sd00.worldcat.org/illpolicies/servicePolicy/servicePolicyAggregateFees'
                inst: otherLibrary.oclcSymbol
                wskey: wskey
              dataType: 'xml'
            )
            .done((data) ->
              id = document.evaluate('//ns10:institutionId', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent

              otherLibrary.id = id if id?

              otherLibrary.name = document.evaluate('//ns10:institutionAlias', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent
              otherLibrary.host = document.evaluate('//ns10:name', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent

              otherLibrary.name = '' if not otherLibrary.name?
              otherLibrary.host = '' if not otherLibrary.host?
            )
            .always(() ->
              deferred.resolve(otherLibrary)
            )

          return deferred.promise()

getRenewalInformation()
-----------------------
If this is a loan, we don't allow renewals.

If this is a borrow, check the ILL policies directory. If renewals information
is listed and is non-zero, renewals are possible. If renewals information is
listed and is zero, renewals are not possible. If renewals information isn't
listed, we're in am ambiguous state.

        getRenewalInformation = (otherLibrary) ->
          deferred = $.Deferred()

          if not isBorrow

Since this is a borrow, there's nothing to do here.

            deferred.resolve()
          else
            if otherLibrary.id
              $.ajax(crossDomainProxy,
                data:
                  csurl: "https://ill.sd00.worldcat.org/illpolicies/servicePolicy/#{otherLibrary.id}"
                  wskey: wskey
                dataType: 'xml'
              )
              .done((data) ->

This is a little crude, since an institution can have multiple 'servicePolicy's,
each of which could have a different value set for `ns8:renewPeriod`.

                renewPeriod = document.evaluate('//ns8:renewPeriod', data, worldcatNamespaceResolver, XPathResult.FIRST_ORDERED_NODE_TYPE).singleNodeValue?.textContent

                if not renewPeriod?
                  transaction.canRenew = 'unknown'
                else if renewPeriod = parseInt(renewPeriod) and renewPeriod > 0
                  transaction.canRenew = true
              )
              .always(() ->
                deferred.resolve()
              )
            else

Can't do anything here, since we can't look anything up.

              deferred.resolve()


          return deferred.promise()

renderBookstrap()
-----------------
Interperate the template with all the information we've gathered, make the
barcode, and trigger the modal.

        renderBookstrap = () ->
          frameDocument = $(frame[0].contentDocument)

          bookstrap = $(bookstrapHandlebarsTemplate(transaction))

          window._strappyBarcode = new Barcode({
            height: '0.5in',
            maxWidth: '2.5in',
            thicknessFactor: 3
          }) if not window._strappyBarcode?

          _strappyBarcode.get(transaction.id)
          .done((barcode) ->
            bookstrap.find('.barcode').prepend(barcode)
            barcode.next('.id').addClass('text-center').css('display', 'block').appendTo(barcode)
          )
          .fail((error) ->
            console.log(error)
          )
          .always(() ->
            modalBookstrap = bookstrap.clone().removeClass('visible-print-block')

            frameDocument.find('body').append(bookstrap)
            frameDocument.find('.modal-body').append(modalBookstrap)

            hideFrame = () ->
              frame.hide()

            frameDocument.find('button.close, [data-dismiss="modal"]').click(hideFrame)
            frameDocument.find('#bookstrap-print').click(() ->
              frame[0].contentWindow.print()
              hideFrame()
            )

            frame.show()

            frame[0].contentWindow.$('#bookstrap-modal').modal('show')
          )

Now, start.

Make the frame.

        frame = $('#strappy-iframe')

        frame = $(document.createElement('iframe')) if not frame[0]

        frame.attr('id', 'strappy-iframe')
        frame.attr('srcdoc', strapDocument)
        frame.attr('sandbox', 'allow-same-origin allow-scripts allow-modal')

        frame.css(
          top: 0
          left: 0
          width: '100%'
          height: '100%'
          position: 'fixed'
          'z-index': 10000
        )

Listen for when the frame is ready.

        frameReadyDeferral = $.Deferred()

        frame.one('bookstrap:frameReady', () ->
          frameReadyDeferral.resolve()
        )

Add the iframe to the document.

        $(document.body).append(frame)

Ask for additional data and, when the data is received, render the bookstrap and
trigger the modal.

        getOtherLibraryInformation()
        .done((otherLibrary) ->
          if isBorrow
            transaction.lender = otherLibrary
            transaction.borrower = thisLibrary
          else
            transaction.lender = thisLibrary
            transaction.borrower = otherLibrary

          $.when(frameReadyDeferral, getRenewalInformation(otherLibrary))
          .done(renderBookstrap)
        )
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
      'https://cdnjs.cloudflare.com/ajax/libs/handlebars.js/3.0.3/handlebars.min.js': not window.Handlebars?
      'https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.10.6/moment.min.js': not window.moment?
    }, strap)
