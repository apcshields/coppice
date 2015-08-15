fs = require 'fs'

module.exports = (grunt) ->
  grunt.initConfig(
    coffee:
      options:
        bare: true
        sourceMap: false
      default:
        files:
          'tmp/strappy.js': 'tmp/strappy.stached.litcoffee'
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
      addCssToMustache:
        options:
          data: () ->
            {
              css: fs.readFileSync('tmp/strappy.min.css')
            }
        files:
          'tmp/bookstrap.cssed.mustache': ['src/bookstrap.mustache']
      addConfigToLitcoffee:
        options:
          data: () ->
            # Get config variables from 'config.cson'.
            cson = require 'cson'
            _ = require 'lodash'

            config = cson.parseCSONFile('config.default.cson')
            _.extend(config, cson.parseCSONFile('config.cson'))

            # Get the mustache strap template (which has had the css minified and added).
            strapTemplate = new String(fs.readFileSync('tmp/bookstrap.cssed.mustache'))
            strapTemplate = strapTemplate.replace(/\n/g, '').replace(/(\W)\s{2,}(\W)/g, '$1$2')

            config.strapTemplate = strapTemplate

            return config
        files:
          'tmp/strappy.stached.litcoffee': ['src/strappy.litcoffee']
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

  grunt.registerTask('default', ['clean:dist', 'cssmin', 'template:addCssToMustache', 'template:addConfigToLitcoffee', 'coffee', 'concat', 'uglify', 'bookmarklet_wrapper', 'clean:tmp'])
  grunt.registerTask('no-cleanup', ['clean:dist', 'cssmin', 'template:addCssToMustache', 'template:addConfigToLitcoffee', 'coffee', 'concat', 'uglify','bookmarklet_wrapper'])
