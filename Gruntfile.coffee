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
      css:
        options:
          data: () ->
            {
              css: fs.readFileSync('tmp/strappy.min.css')
            }
        files:
          'tmp/bookstrap.cssed.mustache': ['src/bookstrap.mustache']
      mustache:
        options:
          data: () ->
            {
              strapTemplate: fs.readFileSync('tmp/bookstrap.cssed.mustache')
            }
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

  grunt.registerTask('default', ['clean:dist', 'cssmin', 'template:css', 'template:mustache', 'coffee', 'concat', 'uglify', 'bookmarklet_wrapper', 'clean:tmp'])
  grunt.registerTask('no-cleanup', ['clean:dist', 'cssmin', 'template:css', 'template:mustache', 'coffee', 'concat', 'uglify','bookmarklet_wrapper'])
