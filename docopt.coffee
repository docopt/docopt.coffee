print = (s) -> console.log(s)
eq = (a, b) ->
    process.stdout.write if a.toString() == b.toString() then '.' else 'F'


# same as Option class in python
option = (short, long, argcount, value) ->
    short: short ? null
    long: long ? null
    argcount: argcount ? 0
    value: value ? false
    toString: -> "option(#{@short}, #{@long}, #{@argcount}, #{@value})"


# same as Option.parse in python
parse = (description) ->
    # strip whitespace
    description = description.replace(/^\s*|\s*$/g, '')
    # split on first occurence of 2 consecutive spaces ('  ')
    [_, options,
     description] = description.match(/(.*?)  (.*)/) ? [null, description, '']
    # replace ',' or '=' with ' '
    options = options.replace(/,|=/g, ' ' )
    # set some defaults
    [short, long, argcount, value] = [null, null, 0, false]
    for s in options.split(/\s+/)  # split on spaces
        if s[0...2] is '--'
            long = s
        else
            if s[0] is '-'
                short = s
            else
                argcount = 1
    if argcount == 1
        matched = description.match(/\[default: (.*)\]/)
        value = if matched then matched[1] else false
    option(short, long, argcount, value)

eq parse('-h'), option('-h', null)
eq parse('-h'), option('-h', null)
eq parse('--help'), option(null, '--help')
eq parse('-h --help'), option('-h', '--help')
eq parse('-h, --help'), option('-h', '--help')

eq parse('-h TOPIC'), option('-h', null, 1)
eq parse('--help TOPIC'), option(null, '--help', 1)
eq parse('-h TOPIC --help TOPIC'), option('-h', '--help', 1)
eq parse('-h TOPIC, --help TOPIC'), option('-h', '--help', 1)
eq parse('-h TOPIC, --help=TOPIC'), option('-h', '--help', 1)

eq parse('-h  Description...'), option('-h', null)
eq parse('-h --help  Description...'), option('-h', '--help')
eq parse('-h TOPIC  Description...'), option('-h', null, 1)

eq parse('    -h'), option('-h', null)

eq parse('-h TOPIC  Descripton... [default: 2]'),
       option('-h', null, 1, '2')
eq parse('-h TOPIC  Descripton... [default: topic-1]'),
       option('-h', null, 1, 'topic-1')
eq parse('--help=TOPIC  ... [default: 3.14]'),
       option(null, '--help', 1, '3.14')
eq parse('-h, --help=DIR  ... [default: ./]'),
           option('-h', '--help', 1, "./")


# same as TokenStream in python
token_stream = (source) ->
    s: if source.constructor is String then source.split(/\s+/) else source
    move: -> if @s.length then @s.splice(0, 1)[0] else null
    current: -> if @s.length then @s[0] else null

eq token_stream(['-o', 'arg']).s, ['-o', 'arg']
eq token_stream('-o arg').s, ['-o', 'arg']
eq token_stream('-o arg').move(), '-o'
eq token_stream('-o arg').current(), '-o'


parse_shorts = (tokens, options) ->
    raw = tokens.move()[1...]
    parsed = []
    while raw != ''
        opt = (o for o in options when o.short and o.short[1] == raw[0])
        if opt.length > 1
            print "-#{raw[0]} is specified ambiguously #{opt.length} times"
            exit
        if opt.length < 1
            print "-#{raw[0]} is not recognized"
            exit
        opt = opt[0] #####copy?  opt = copy(opt[0])
        raw = raw[1...]
        if opt.argcount == 0
            value = true
        else
            if raw == ''
                if tokens.current() is null
                    print "-#{opt.short[0]} requires argument"
                    exit
                raw = tokens.move()
            [value, raw] = [raw, '']
        opt.value = value
        parsed.push(opt)
    return parsed

eq(parse_shorts(token_stream('-a'), [option('-a')]),
    [option('-a', null, 0, true)])
eq(parse_shorts(token_stream('-ab'), [option('-a'), option('-b')]),
    [option('-a', null, 0, true), option('-b', null, 0, true)])
eq(parse_shorts(token_stream('-b'), [option('-a'), option('-b')]),
    [option('-b', null, 0, true)])
eq(parse_shorts(token_stream('-aARG'), [option('-a', null, 1)]),
    [option('-a', null, 1, 'ARG')])
eq(parse_shorts(token_stream('-a ARG'), [option('-a', null, 1)]),
    [option('-a', null, 1, 'ARG')])


parse_long = (tokens, options) ->
    [_, raw,
     value] = tokens.current().match(/(.*?)=(.*)/) ? [null,
                                                      tokens.current(), '']
    tokens.move()
    value = if value == '' then null else value
    opt = (o for o in options when o.long and o.long[0...raw.length] == raw)
    if opt.length < 1
        print "-#{raw} is not recognized"
        exit
    if opt.length > 1
        print "-#{raw} is not a unique prefix"  # TODO report ambiguity
        exit
    opt = opt[0]  #copy? opt = copy(opt[0])
    if opt.argcount == 1
        if value is null
            if tokens.current() is null
                print "#{opt.name} requires argument"
                exit
            value = tokens.move()
    else if value is not null
        print "#{opt.name} must not have an argument"
        exit
    opt.value = value or true
    return [opt]

eq(parse_long(token_stream('--all'), [option(null, '--all')]),
    [option(null, '--all', 0, true)])
eq(parse_long(token_stream('--all'), [option(null, '--all'),
                                      option(null, '--not')]),
    [option(null, '--all', 0, true)])
eq(parse_long(token_stream('--all=ARG'), [option(null, '--all', 1)]),
    [option(null, '--all', 1, 'ARG')])
eq(parse_long(token_stream('--all ARG'), [option(null, '--all', 1)]),
    [option(null, '--all', 1, 'ARG')])


parse_args = (source, options) ->
    tokens = token_stream(source)
    options = options.slice(0)  # shallow copy, not sure if necessary
    opts = []
    args = []
    while not (tokens.current() is null)
        if tokens.current() == '--'
            tokens.move()
            args = args.concat(tokens.s)
            break
        else
            if tokens.current()[0...2] == '--'
                opts = opts.concat(parse_long(tokens, options))
            else
                if tokens.current()[0] == '-' and tokens.current() != '-'
                    opts = opts.concat(parse_shorts(tokens, options))
                else
                    args.push(tokens.move())
    return [opts, args]

test_options = [option(null, '--all'), option('-b'), option('-W', null, 1)]
eq(parse_args('--all -b ARG', test_options),
    [[option(null, '--all', 0, true), option('-b', null, 0, true)]
     ['ARG']])
eq(parse_args('ARG -Wall', test_options),
    [[option('-W', null, 1, 'all')]
     ['ARG']])
