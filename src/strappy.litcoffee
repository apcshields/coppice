thisLibrary
-----------

    thisLibrary =
      oclcSymbol: 'IGC'
      name: 'Goshen College Library'

strapTemplate
-------------

    strapTemplate = '
      <!doctype html>
      <html class="no-js" lang="en">
        <head>
          <meta charset="utf-8">
          <meta http-equiv="x-ua-compatible" content="ie=edge">
        </head>
        <body>
          <div class="title">
            <span class="label">Title:</span>
            <span class="value">{{item.title}}</span>
          </div>

          <div class="author">
            <span class="label">Author:</span>
            <span class="value">{{item.author}}</span>
          </div>

          <div class="patron">
            <span class="label">Patron:</span>
            <span class="value">{{patron.name}}</span>
          </div>

          <div class="due_date">
            <span class="label">Due Date:</span>
            <span class="value">{{dueDate}}</span>
          </div>

          {{^canRenew}}
          <div class="renew">
            <span>No renewals</span>
          </div>
          {{/canRenew}}

          <div class="return_to">
            <span class="label">Patron, please return book to:</span>
            <span class="value">{{borrower.name}}</span>
          </div>

          <div class="loan_from">
            <span class="label">An Interlibrary Loan from:</span>
            <span class="value">{{lender.name}} {{lender.oclcSymbol}}</span>
          </div>
        </body>
      </html>
    '

loadScripts()
-------------
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

strap()
-------
This function holds everything we want to do, so that we can run it after jQuery
loads, if that was necessary.

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
          item:
            title: transactionPanel.find('.yui-field-title:not(.editable)').text()
            author: transactionPanel.find('.yui-field-author:not(.editable)').text()
          patron:
            name: transactionPanel.find('.yui-field-name').val()

For some reason, loans don't use the `.yui-field-originalDueDate` syntax for the
due date, so we have to search for the data field, which is consistent.

          dueDate: transactionPanel.find('[data="returning.originalDueToSupplier"]').text()

The ILL interface doesn't give us a consistently straightforward way to get a
clean string with the other library's name. It is particularly difficult for
loans, which are the transactions in which it is more important for us to print
the borrowing library's name on the bookstrap!

For borrows, we pull the string from the page.

(This turns out to be not a great string:

'Indiana University, South Bend, South Bend, US-IN' versus
'Franklin D Schurz Library
Indiana University, South Bend'

Maybe we should just do for borrows what we do for loans.)

For loans, the best option seems to be pulling out the OCLC symbol and using the
ILL policies directory API to request an XML file which will include a useful
string.

---

This is wrapped in an anonymous function to keep my variable workspace clean.
Meh.

        otherLibrary = (() ->
          library = {}

First, get the OCLC symbol.

          library.oclcSymbol = transactionPanel.find('.nd-pdlink').attr('href')?.match(/instSymbol=(.{3})/)[1]

          return { oclcSymbol: '', name: '' } if not library.oclcSymbol?

Now the flow forks to handle borrows and loans differently.

          if isBorrow

Since this is a borrow, we can look through the 'lender string list' to find the
library description.

            lenderStringListID = "#lender-string-list-#{transaction.id}-#{library.oclcSymbol}"

            library.name = transactionPanel.find(lenderStringListID + ' .suppliername').text()
          else
            # Make an API request to the ILL policies directory.
            # "https://ill.sd00.worldcat.org/illpolicies/servicePolicy/servicePolicyAggregateFees?inst=#{library.oclcSymbol}&wskey={#wskey}"

            library.name = ''

          return library
        )()

        if isBorrow
          transaction.lender = otherLibrary
          transaction.borrower = thisLibrary
        else
          transaction.lender = thisLibrary
          transaction.borrower = otherLibrary

Make an iframe and load the strap in it.

        strapFrame = (() ->
          frame = $('#strappy-iframe')

          frame = $(document.createElement('iframe')) if not frame[0]

          frame.attr('id', 'strappy-iframe')
          frame.attr('srcdoc', Mustache.render(strapTemplate, transaction))

          frame.css('border', 'none')

          $(document.body).append(frame)

          return frame
        )()

      )(jQuery.noConflict(), window._lodash)

Conditionally load the various scripts that will make this much easier. Don't
load them if their products already exist, if, for instance, the page hasn't
been reloaded since the bookmarklet was last used.

    loadScripts({
      'https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js': not window.jQuery?
      'https://cdnjs.cloudflare.com/ajax/libs/lodash.js/3.10.1/lodash.min.js': not window._lodash?
      'https://cdnjs.cloudflare.com/ajax/libs/mustache.js/2.1.3/mustache.min.js': not window.Mustache?
    }, strap)
