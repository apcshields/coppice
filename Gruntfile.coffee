module.exports = (grunt) ->
  grunt.initConfig(
    coffee:
      options:
        bare: true
        sourceMap: false
      default:
        files:
          'tmp/strappy.js': 'src/strappy.litcoffee'
    uglify:
      options:
        sourceMap: false
      default:
        files:
          'tmp/strappy.ugly.js': 'tmp/strappy.js'
    concat:
      options:
        separator: ''
      default:
        files:
          'dist/strappy.js': ['tmp/strappy.ugly.js']
    clean:
      tmp: ['tmp/*']
      dist: ['dist/*']
    bookmarklet_wrapper:
      default:
        files:
          'dist/strappy.js': ['tmp/strappy.ugly.js']
  )

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-bookmarklet-wrapper')

  grunt.registerTask('default', ['clean:dist', 'coffee', 'uglify', 'bookmarklet_wrapper', 'clean:tmp'])
  grunt.registerTask('no-cleanup', ['clean:dist', 'coffee', 'uglify','bookmarklet_wrapper'])
