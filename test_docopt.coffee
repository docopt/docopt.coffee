print = () -> console.log.apply @, [].slice.call(arguments)
eq = (a, b) ->
    as = a.toString()
    bs = b.toString()
    if as == bs then return else throw new Error "#{as} != #{bs}"


[setup, teardown, test] = (() ->
    cl = console.log
    psw = process.stdout.write
    buffer = ''
    number = 0
    passes = 0
    failures = 0
    results = []

    [(f) ->
        results = []
        console.log = () ->
            buffer += ([].slice.call arguments).join() + '\n'
        process.stdout.write = () ->
            buffer += ([].slice.call arguments).join()
        if f then f() else null

        cl '================================================================'

    (f) ->
        cl ''
        console.log = cl
        process.stdout.write = psw
        if f then f() else null

        for result in results
            if result[0] == 'F'
                ++failures
                half = (56 - result[1].length)/2
                if half > 0
                    [left, right] = [new Array(half + half%1).join('=') + ' ',
                               ' ' + new Array(half - half%1).join('=')]
                else
                    [left, right] = ['', '']
                cl "#{left}In test #{result[1]}#{right}"
                cl "#{result[2]}"
                if result[3] isnt ''
                    cl '------------------------ captured stdout -----------------------'
                    cl result[3]
             else
                 ++passes

        cl '================================================================'
        cl((result[0] for result in results).join(''))
        cl "#{passes} successes, #{failures} failures"
        cl '================================================================'

    (n, f) ->
        #psw "collecting #{++number} item(s)\r"
        try
            f()
            results.push ['.', n, 'ok', buffer]
        catch e
            results.push ['F', n, e.message, buffer]
        buffer = '']
)()

((module) ->

    setup()

    {Option, TokenStream, parse_shorts, parse_long,
                       parse_args, printable_usage} = module

    test "Option.parse", ->
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
        
    test "TokenStream", ->
        eq new TokenStream(['-o', 'arg']), ['-o', 'arg']
        eq new TokenStream('-o arg'), ['-o', 'arg']
        eq new TokenStream('-o arg').shift(), '-o'
        eq new TokenStream('-o arg').current(), '-o'
            
    test "parse_shorts", ->
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
        
    test "parse_long", ->
        eq(parse_long(new TokenStream('--all'), [new Option(null, '--all')]),
            [new Option(null, '--all', 0, true)])
        eq(parse_long(new TokenStream('--all'), [new Option(null, '--all'),
                                              new Option(null, '--not')]),
            [new Option(null, '--all', 0, true)])
        eq(parse_long(new TokenStream('--all=ARG'), [new Option(null, '--all', 1)]),
            [new Option(null, '--all', 1, 'ARG')])
        eq(parse_long(new TokenStream('--all ARG'), [new Option(null, '--all', 1)]),
            [new Option(null, '--all', 1, 'ARG')])
        
    test "parse_args", ->
        test_options = [new Option(null, '--all'), new Option('-b'), new Option('-W', null, 1)]
        eq(parse_args('--all -b ARG', test_options),
            [[new Option(null, '--all', 0, true), new Option('-b', null, 0, true)]
             ['ARG']])
        eq(parse_args('ARG -Wall', test_options),
            [[new Option('-W', null, 1, 'all')]
             ['ARG']])

    test "printable_usage", ->
        usage = 'Usage: prog <a> <b> <c>\n\n'
        eq printable_usage(usage, 'my_script'), 'Usage: my_script <a> <b> <c>'
        eq printable_usage(usage, null), 'Usage: prog <a> <b> <c>'

        usage = 'Usage:\tprog <a> <b> <c>\n' +
                        'prog --version\n'   +
                        'prog (--help | -h)\n\n'
        eq printable_usage(usage, 'rn'), 'Usage:\trn <a> <b> <c>\n' +
                                         '      \trn --version\n'   +
                                         '      \trn (--help | -h)'
        eq printable_usage(usage, null), 'Usage:\tprog <a> <b> <c>\n' +
                                         '      \tprog --version\n'   +
                                         '      \tprog (--help | -h)'

        usage = 'Usage:\n' +
                '  prog <a> <b> <c>\n' +
                '  prog --version\n'   +
                '  prog (--help | -h)\n\n'
        eq printable_usage(usage, 'rn'), 'Usage:\n' +
                                         '  rn <a> <b> <c>\n' +
                                         '  rn --version\n'   +
                                         '  rn (--help | -h)'
        eq printable_usage(usage, null), 'Usage:\n' +
                                         '  prog <a> <b> <c>\n' +
                                         '  prog --version\n'   +
                                         '  prog (--help | -h)'

        usage = 'usage:nospace'
        eq printable_usage(usage, null), 'usage: nospace'


    teardown()
)(require './docopt')
