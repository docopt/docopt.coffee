print = console.log

class UsageMessageError extends Error
    constructor: (message) ->
        print message

class DocoptExit extends Error
    constructor: (message) ->
        print message
        process.exit(1)
    @usage: ''

# same as Option class in python
class Option
    constructor: (@short=null, @long=null, @argcount=0, @value=false) ->
    toString: -> "Option(#{@short}, #{@long}, #{@argcount}, #{@value})"
    name: -> @long or @short
    @parse: (description) ->
        # strip whitespaces
        description = description.replace(/^\s*|\s*$/g, '')
        # split on first occurence of 2 consecutive spaces ('  ')
        [_, options,
         description] = description.match(/(.*?)  (.*)/) ? [null, description, '']
        # replace ',' or '=' with ' '
        options = options.replace(/,|=/g, ' ' )
        # set some defaults
        [short, long, argcount, value] = [null, null, 0, false]
        for s in options.split(/\s+/)  # split on spaces
            if s[0..1] is '--'
                long = s
            else if s[0] is '-'
                short = s
            else
                argcount = 1
        if argcount is 1
            matched = description.match(/\[default: (.*)\]/)
            value = if matched then matched[1] else false
        new Option(short, long, argcount, value)
    

# same as TokenStream in python
class TokenStream extends Array
    constructor: (source, @error) -> 
        stream = 
           if source.constructor is String
               source.split(/\s+/)
           else
               source
        @push.apply @, stream
    move: -> @shift() or null
    current: -> @[0] or null
    toString: -> ([].slice.apply @).toString()
    error: (message) ->
        throw new @error(message)


parse_shorts = (tokens, options) ->
    raw = tokens.move()[1..]
    parsed = []
    while raw != ''
        opt = (o for o in options when o.short and o.short[1] == raw[0])
        if opt.length > 1
            tokens.error "-#{raw[0]} is specified ambiguously #{opt.length} times"
        if opt.length < 1
            tokens.error "-#{raw[0]} is not recognized"
        opt = opt[0] #####copy?  opt = copy(opt[0])
        raw = raw[1..]
        if opt.argcount == 0
            value = true
        else
            if raw == ''
                if tokens.current() is null
                    tokens.error "-#{opt.short[0]} requires argument"
                raw = tokens.move()
            [value, raw] = [raw, '']
        opt.value = value
        parsed.push(opt)
    return parsed


parse_long = (tokens, options) ->
    [_, raw,
     value] = tokens.current().match(/(.*?)=(.*)/) ? [null,
                                                      tokens.current(), '']
    tokens.move()
    value = if value == '' then null else value
    opt = (o for o in options when o.long and o.long[0...raw.length] == raw)
    if opt.length < 1
        tokens.error "-#{raw} is not recognized"
    if opt.length > 1
        tokens.error "-#{raw} is not a unique prefix"  # TODO report ambiguity
    opt = opt[0]  #copy? opt = copy(opt[0])
    if opt.argcount == 1
        if value is null
            if tokens.current() is null
                tokens.error "#{opt.name} requires argument"
            value = tokens.move()
    else if value is not null
        tokens.error "#{opt.name} must not have an argument"
    opt.value = value or true
    return [opt]


parse_args = (source, options) ->
    tokens = new TokenStream(source)
    #options = options.slice(0) # shallow copy, not sure if necessary
    [opts, args] = [[], []]
    while not (tokens.current() is null)
        if tokens.current() == '--'
            tokens.move()
            args = args.concat(tokens)
            break
        else if tokens.current()[0...2] == '--'
            opts = opts.concat(parse_long(tokens, options))
        else if tokens.current()[0] == '-' and tokens.current() != '-'
            opts = opts.concat(parse_shorts(tokens, options))
        else
            args.push(tokens.move())
    return [opts, args]

parse_doc_options = (doc) ->
    (Option.parse('-' + s) for s in doc.split(/^ *-|\n *-/)[1..])

printable_usage = (doc) ->
    if usage = (/\s*usage:\s+/i).exec(doc)
        usage = usage.replace(/^\s+/, '')
        uses = doc.substr(usage.length).split(/\n\s*\n/)[0].split('\n')
        ws = (new Array usage.length+1).join(' ')
        return usage + (u.replace /^\s+|\s+$/, '' for u in uses).join(ws)
    else
        throw new UsageMessageError("the first word in the usage should be usage.")

formal_usage = (printable_usage) ->
    pu = printable_usage.split()[1..]  # split and drop "usage:"
    ((if s == pu[0] then '|' else s) for s in pu[1..]).join(' ')

extras = (help, version, options, doc) ->
    opts = {}
    for opt in options
        if opt.value
            opts[opt.name()] = true
    if help and (opts['--help'] or opts['-h'])
        print(doc.strip())
        exit()
    if version and opts['--version']
        print(version)
        exit()

docopt = (doc, argv=process.argv[1..], help=true, version=null) ->
    DocoptExit.usage = docopt.usage = usage = printable_usage(doc)
    pot_options = parse_doc_options(doc)
    [options, args] = parse_args(argv, options=pot_options)

    extras(help, version, options, doc)
    formal_pattern = parse_pattern(formal_usage(usage), options=pot_options)
#    pot_arguments = [a for a in formal_pattern.flat
#                     if type(a) in [Argument, Command]]
#    [matched, left, arguments] = formal_pattern.fix().match(argv)
#    if matched and left == []:  # better message if left?
#        args = Dict((a.name, a.value) for a in
#                 (pot_options + options + pot_arguments + arguments))
#        return args
#    throw new DocoptExit()

__all__ = 
    docopt       : docopt
    Option       : Option
    TokenStream  : TokenStream
    parse_long   : parse_long
    parse_shorts : parse_shorts
    parse_args   : parse_args

for fun of __all__
    exports[fun] = __all__[fun]
