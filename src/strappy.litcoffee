    loadScript = (url, callback) ->
      script = document.createElement('script')

      script.addEventListener('load', callback)

      script.setAttribute('src', url)
      script.setAttribute('async', 'async')

      document.body.appendChild(script)

This function holds everything we want to do, so that we can run it after jQuery
loads, if that was necessary.

    strap = () ->
      alert('strap')

First, check whether we need to inject jQuery into the page. If yes, inject and
run `strap` again on load.

      if !window.jQuery?
        return loadScript('https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js', strap)

### Use jQuery to load this.

      if !window._?
        return loadScript('https://cdnjs.cloudflare.com/ajax/libs/lodash.js/3.10.1/lodash.min.js', strap)

We have jQuery and lodash. Relinquish control of `$` and `_` and then get them
back as local variables.

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

        transaction.library = (() ->
          library = {}

First, get the OCLC symbol.

          library.oclcSymbol = transactionPanel.find('.nd-pdlink').attr('href')?.match(/instSymbol=(.{3})/)[1]

### We can't go any further, but maybe there is something intelligent we could
do to recover?

          return null if not library.oclcSymbol?

Now the flow forks to handle borrows and loans differently.

          if isBorrow

Since this is a borrow, we can look through the 'lender string list' to find the
library description.

            lenderStringListID = "#lender-string-list-#{transaction.id}-#{library.oclcSymbol}"

            library.name = transactionPanel.find(lenderStringListID + ' .suppliername').text()
          else
            # Make an API request to the ILL policies directory.
            # "https://ill.sd00.worldcat.org/illpolicies/servicePolicy/servicePolicyAggregateFees?inst=#{library.oclcSymbol}&wskey={#wskey}"

          return library
        )()

        alert(JSON.stringify(transaction, null, 2))

      )(jQuery.noConflict(), _.noConflict())

### Store _'s noConflict version in a global variable.

    strap()
