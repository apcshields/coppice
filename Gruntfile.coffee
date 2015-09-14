fs = require 'fs'

module.exports = (grunt) ->
  grunt.initConfig(
    coffee:
      options:
        bare: true
        sourceMap: false
      default:
        files:
          'tmp/strappy.js': 'tmp/strappy.tmpld.litcoffee'
          'tmp/barcode.js': 'src/barcode/barcode.litcoffee'
    uglify:
      options:
        sourceMap: false
      default:
        files:
          'tmp/strappy.ugly.js': 'tmp/strappy.concat.js'
    concat:
      options:
        separator: ''
      default:
        files:
          'tmp/strappy.concat.js': ['tmp/barcode.js', 'tmp/strappy.js']
    clean:
      tmp: ['tmp/*']
      dist: ['dist/*']
    bookmarklet_wrapper:
      default:
        files:
          'dist/strappy.js': ['tmp/strappy.ugly.js']
    template:
      addCssToHtml:
        options:
          data: () ->
            {
              css: fs.readFileSync('tmp/strappy.min.css')
            }
        files:
          'tmp/bookstrap.cssed.html': ['src/bookstrap.html']
      addConfigToLitcoffee:
        options:
          data: () ->
            # Get config variables from 'config.cson'.
            cson = require 'cson'
            _ = require 'lodash'
            path = require 'path'

            config = cson.parseCSONFile('config.default.cson')
            _.extend(config, cson.parseCSONFile('config.cson'))

            # Read the logo image file into Base 64.
            # See https://github.com/BrightcoveOS/grunt-base64/blob/2eb0204cf1eb07a934f7660ea71684f519fcaf15/tasks/base64.js#L17
            if config.thisLibrary.logo and grunt.file.exists(config.thisLibrary.logo)
              config.thisLibrary.logo = 'data:image/' + path.extname(config.thisLibrary.logo)[1..] + ';base64,' + grunt.file.read(config.thisLibrary.logo, { encoding: null }).toString('base64')

            # Get the Handlebars strap template and the strap document (which has had the css minified and added).
            strapDocument = new String(fs.readFileSync('tmp/bookstrap.cssed.html'))
            strapDocument = strapDocument.replace(/\n/g, '').replace(/(\W)\s{2,}(\W)/g, '$1$2')

            strapTemplate = new String(fs.readFileSync('src/bookstrap.handlebars'))
            strapTemplate = strapTemplate.replace(/\n/g, '').replace(/(\W)\s{2,}(\W)/g, '$1$2')

            config.strapDocument = strapDocument
            config.strapTemplate = strapTemplate

            return config
        files:
          'tmp/strappy.tmpld.litcoffee': ['src/strappy.litcoffee']
    cssmin:
      options:
        sourceMap: false
      default:
        files:
          'tmp/strappy.min.css': ['src/strappy.css']
  )

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-bookmarklet-wrapper')
  grunt.loadNpmTasks('grunt-template');
  grunt.loadNpmTasks('grunt-contrib-cssmin')

  grunt.registerTask('default', ['clean:dist', 'cssmin', 'template:addCssToHtml', 'template:addConfigToLitcoffee', 'coffee', 'concat', 'uglify', 'bookmarklet_wrapper', 'clean:tmp'])
  grunt.registerTask('no-cleanup', ['clean:dist', 'cssmin', 'template:addCssToHtml', 'template:addConfigToLitcoffee', 'coffee', 'concat', 'uglify','bookmarklet_wrapper'])
