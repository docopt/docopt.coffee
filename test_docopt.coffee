# it's a troublesome policy that node's got...

print = console.log
eq = (a, b) ->
    as = a.toString()
    bs = b.toString()
    if as == bs then return else throw new Error "#{as} != #{bs}"

doc = require './docopt'

((module) -> 
    `with (module) {//`
    tests = 
        test_opt_parse: ->
            eq Option.parse('-h'), new Option('-h', null)
            eq Option.parse('-h'), new Option('-h', null)
            eq Option.parse('--help'), new Option(null, '--help')
            eq Option.parse('-h --help'), new Option('-h', '--help')
            eq Option.parse('-h, --help'), new Option('-h', '--help')
            
            eq Option.parse('-h TOPIC'), new Option('-h', null, 1)
            eq Option.parse('--help TOPIC'), new Option(null, '--help', 1)
            eq Option.parse('-h TOPIC --help TOPIC'), new Option('-h', '--help', 1)
            eq Option.parse('-h TOPIC, --help TOPIC'), new Option('-h', '--help', 1)
            eq Option.parse('-h TOPIC, --help=TOPIC'), new Option('-h', '--help', 1)
            
            eq Option.parse('-h  Description...'), new Option('-h', null)
            eq Option.parse('-h --help  Description...'), new Option('-h', '--help')
            eq Option.parse('-h TOPIC  Description...'), new Option('-h', null, 1)
            
            eq Option.parse('    -h'), new Option('-h', null)
            
            eq Option.parse('-h TOPIC  Descripton... [default: 2]'),
                   new Option('-h', null, 1, '2')
            eq Option.parse('-h TOPIC  Descripton... [default: topic-1]'),
                   new Option('-h', null, 1, 'topic-1')
            eq Option.parse('--help=TOPIC  ... [default: 3.14]'),
                   new Option(null, '--help', 1, '3.14')
            eq Option.parse('-h, --help=DIR  ... [default: ./]'),
                       new Option('-h', '--help', 1, "./")
            
        test_token_stream: ->
            eq new TokenStream(['-o', 'arg']), ['-o', 'arg']
            eq new TokenStream('-o arg'), ['-o', 'arg']
            eq new TokenStream('-o arg').move(), '-o'
            eq new TokenStream('-o arg').current(), '-o'
            
        test_parse_shorts: ->
            eq(parse_shorts(new TokenStream('-a'), [new Option('-a')]),
                [new Option('-a', null, 0, true)])
            eq(parse_shorts(new TokenStream('-ab'), [new Option('-a'), new Option('-b')]),
                [new Option('-a', null, 0, true), new Option('-b', null, 0, true)])
            eq(parse_shorts(new TokenStream('-b'), [new Option('-a'), new Option('-b')]),
                [new Option('-b', null, 0, true)])
            eq(parse_shorts(new TokenStream('-aARG'), [new Option('-a', null, 1)]),
                [new Option('-a', null, 1, 'ARG')])
            eq(parse_shorts(new TokenStream('-a ARG'), [new Option('-a', null, 1)]),
                [new Option('-a', null, 1, 'ARG')])
            
        test_parse_long: ->
            eq(parse_long(new TokenStream('--all'), [new Option(null, '--all')]),
                [new Option(null, '--all', 0, true)])
            eq(parse_long(new TokenStream('--all'), [new Option(null, '--all'),
                                                  new Option(null, '--not')]),
                [new Option(null, '--all', 0, true)])
            eq(parse_long(new TokenStream('--all=ARG'), [new Option(null, '--all', 1)]),
                [new Option(null, '--all', 1, 'ARG')])
            eq(parse_long(new TokenStream('--all ARG'), [new Option(null, '--all', 1)]),
                [new Option(null, '--all', 1, 'ARG')])
            
        test_parse_args: ->
            test_options = [new Option(null, '--all'), new Option('-b'), new Option('-W', null, 1)]
            eq(parse_args('--all -b ARG', test_options),
                [[new Option(null, '--all', 0, true), new Option('-b', null, 0, true)]
                 ['ARG']])
            eq(parse_args('ARG -Wall', test_options),
                [[new Option('-W', null, 1, 'all')]
                 ['ARG']])

    `}`

    print '================================================================'

    passes = 0
    errors = []
    for test of tests
        try
            tests[test]()
            passes += 1
            process.stdout.write '.'
        catch e
            errors.push([test, e])
            process.stdout.write 'F'
    print ''

    for [test, e] in errors
        print "In test #{test}, #{e.message}"

    print "#{passes} successes, #{errors.length} failures"
    print '================================================================'
)(doc)
