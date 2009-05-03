" ============================================================================
" File:        NERDSnippets.vim
" Description: vim global plugin for snippets that own hard
" Maintainer:  Martin Grenfell <martin_grenfell at msn dot com>
" Last Change: 18 October, 2008
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
"

if v:version < 700
    finish
endif

if exists("loaded_nerd_snippets_plugin")
    finish
endif
let loaded_nerd_snippets_plugin = 1

" Variable Definations: {{{1
" options, define them as you like in vimrc:
if !exists("g:NERDSnippets_key")
    let g:NERDSnippets_key = "<tab>"
endif

if !exists("g:NERDSnippets_marker_start")
    let g:NERDSnippets_marker_start = '${'
endif
let s:start = g:NERDSnippets_marker_start

if !exists("g:NERDSnippets_marker_end")
    let g:NERDSnippets_marker_end = '}'
endif
let s:end = g:NERDSnippets_marker_end

let s:in_windows = has("win16") ||  has("win32") || has("win64")

let s:topOfSnippet = -1
let s:appendTab = 1
let s:snippets = {}
let s:snippets['_'] = {}

function! s:enableMaps()
    exec "inoremap <silent>".g:NERDSnippets_key." <c-r>=NERDSnippets_Trigger()<CR>"
	exec "nnoremap <silent>".g:NERDSnippets_key." i<c-g>u<c-r>=NERDSnippets_SwitchRegion(0)<cr>"
	exec "snoremap <silent>".g:NERDSnippets_key." <esc>i<c-g>u<c-r>=NERDSnippets_SwitchRegion(0)<cr>"
endfunction
command! -nargs=0 NERDSnippetsEnable call <SID>enableMaps()
call s:enableMaps()

function! s:disableMaps()
    exec "iunmap ".g:NERDSnippets_key
    exec "nunmap ".g:NERDSnippets_key
    exec "sunmap ".g:NERDSnippets_key
endfunction
command! -nargs=0 NERDSnippetsDisable call <SID>disableMaps()

" Snippet class {{{1
let s:Snippet = {}

function! s:Snippet.New(expansion, ...)
    let newSnippet = copy(self)
    let newSnippet.expansion = a:expansion
    if a:0
        let newSnippet.name = a:1
    else
        let newSnippet.name = ''
    endif
    return newSnippet
endfunction

function! s:Snippet.stringForPrompt()
    if self.name != ''
        return self.name
    else
        return substitute(self.expansion, "\r", '<CR>', 'g')
    endif
endfunction
"}}}1

function! NERDSnippets_Trigger()
    let stuff  = NERDSnippets_ExpandSnippet()
    if stuff == ''
        let stuff =NERDSnippets_SwitchRegion(1)
    endif

    return stuff
endfunction

" ExpandSnippet {{{1
function! NERDSnippets_ExpandSnippet()
    let snippet_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
    let snippet = s:snippetFor(snippet_name)
    if snippet != ''
        let s:snippet = snippet
        let s:appendTab = 0
        let s:topOfSnippet = line('.')
        let snippet = s:ParseSnippet(snippet_name, snippet)
        " let snippet = s:ExpandSnippet(snippet_name)
    else
        let s:appendTab = 1
    endif
    return snippet
endfunction
" }}}1

"jump to the next marker, remove the delimiters and select the text inside in "select mode {{{1
"
"if no markers are found, a <tab> may be inserted into the text
function! NERDSnippets_SwitchRegion(allowAppend)
    if exists('s:snipPos')
	    return s:JumpTabStop()
    elseif s:appendTab && a:allowAppend
        if g:NERDSnippets_key == "<tab>"
            return "\<tab>"
        endif
    else
        return "\<ESC>l"
	endif
endfunction
"}}}1

"asks the user to select a snippet from the given list
"
"returns the body of the chosen snippet {{{1
function! s:chooseSnippet(snippets)
    "build the dialog/choice list
    let prompt = ""
    let i = 0
    while i < len(a:snippets)
        let prompt .= i+1 . ". " . a:snippets[i].stringForPrompt() . "\n"
        let i += 1
    endwhile
    let prompt .= "\nSelect a snippet:"

    "input(save|restore) needed because this function is called during a
    "mapping
    redraw!
    call inputsave()
    if len(a:snippets) < 10
        echon prompt
        let choice = nr2char(getchar())
    else
        let choice = input(prompt)
    endif
    call inputrestore()
    redraw!

    if choice !~ '^\d*$' || choice < 1 || choice > len(a:snippets)
        return ""
    endif

    return a:snippets[choice-1].expansion
endfunction
"}}}1

"get a snippet for the given keyword, if multiple snippets are found then prompt
"the user to choose.
"
"if no snippets are found, return '' {{{1
function! s:snippetFor(keyword)
    let snippets = []
    if has_key(s:snippets,&ft)
        if has_key(s:snippets[&ft],a:keyword)
            let snippets = extend(snippets, s:snippets[&ft][a:keyword])
        endif
    endif
    if has_key(s:snippets['_'],a:keyword)
        let snippets = extend(snippets, s:snippets['_'][a:keyword])
    endif

    if len(snippets)
        if len(snippets) == 1
            return snippets[0].expansion
        else
            return s:chooseSnippet(snippets)
        endif
    endif

    return ''
endfunction
"}}}1

"}}}1

"add a new snippet for the given filetype and keyword {{{1
function! s:addSnippet(filetype, keyword, expansion, ...)
    if !has_key(s:snippets, a:filetype)
        let s:snippets[a:filetype] = {}
    endif

    if !has_key(s:snippets[a:filetype], a:keyword)
        let s:snippets[a:filetype][a:keyword] = []
    endif

    let snippetName = ''
    if a:0
        let snippetName = a:1
    endif

    let newSnippet = s:Snippet.New(a:expansion, snippetName)

    call add(s:snippets[a:filetype][a:keyword], newSnippet)
endfunction
"}}}1

"remove all snippets {{{1
function! NERDSnippetsReset()
    let s:snippets = {}
    let s:snippets['_'] = {}
endfunction
"}}}1


"Extract snippets from the given directory. The snippet filetype, keyword, and
"possibly name, are all inferred from the path of the .snippet files relative
"to a:dir. {{{1
function! NERDSnippetsFromDirectory(dir)
    let snippetFiles = split(globpath(expand(a:dir), '**/*.snippet'), '\n')
    for fullpath in snippetFiles
        let tail = strpart(fullpath, strlen(expand(a:dir)))

        if s:in_windows
            let tail = substitute(tail, '\\', '/', 'g')
        endif

        let filetype = substitute(tail, '^/\([^/]*\).*', '\1', '')
        let keyword = substitute(tail, '^/[^/]*\(.*\)', '\1', '')
        call s:extractSnippetFor(fullpath, filetype, keyword)
    endfor
endfunction
"}}}1

"Extract snippets from the given directory for the given filetype.
"
"The snippet keywords (and possibly names) are interred from the path of the
".snippet files relative to a:dir {{{1
function! NERDSnippetsFromDirectoryForFiletype(dir, filetype)
    let snippetFiles = split(globpath(expand(a:dir), '**/*.snippet'), '\n')
    for i in snippetFiles
        let base = expand(a:dir)
        let fullpath = expand(i)
        let tail = strpart(fullpath, strlen(base))

        if s:in_windows
            let tail = substitute(tail, '\\', '/', 'g')
        endif

        call s:extractSnippetFor(fullpath, a:filetype, tail)
    endfor
endfunction
"}}}1

"create a snippet from the given file
"
"Args:
"fullpath: full path to snippet file
"filetype: the filetype for the new snippet
"tail: the last part of the path containing the keyword and possibly name. eg
" '/class.snippet'   or  '/class/with_constructor.snippet' {{{1
function! s:extractSnippetFor(fullpath, filetype, tail)
    let keyword = ""
    let name = ""

    let slashes = strlen(substitute(a:tail, '[^/]', '', 'g'))
    if slashes == 1
        let keyword = substitute(a:tail, '^/\(.*\)\.snippet', '\1', '')
    elseif slashes == 2
        let keyword = substitute(a:tail, '^/\([^/]*\)/.*$', '\1', '')
        let name = substitute(a:tail, '^/[^/]*/\(.*\)\.snippet', '\1', '')
    else
        throw 'NERDSnippets.ScrewedSnippetPathError ' . a:fullpath
    endif

    let snippetContent = s:parseSnippetFile(a:fullpath)

    call s:addSnippet(a:filetype, keyword, snippetContent, name)
endfunction
"}}}1


"Extract and munge the body of the snippet from the given file. {{{1
function! s:parseSnippetFile(path)
    try
        let lines = readfile(a:path)
    catch /E484/
        throw "NERDSnippet.ScrewedSnippetPathError " . a:path
    endtry

    return join(lines, "\n")
endfunction
"}}}1

"some global functions that are handy inside snippet files {{{1
function! NS_prompt(varname, prompt, default)
    "input(save|restore) needed because this function is called during a
    "mapping
    call inputsave()
    let input = input(a:prompt . ':', a:default)
    exec "let g:" . a:varname . "='" . escape(input, "'") . "'"
    call inputrestore()
    redraw!
    return input
endfunction

function! NS_camelcase(s)
    "upcase the first letter
    let toReturn = substitute(a:s, '^\(.\)', '\=toupper(submatch(1))', '')
    "turn all '_x' into 'X'
    return substitute(toReturn, '_\(.\)', '\=toupper(submatch(1))', 'g')
endfunction

function! NS_underscore(s)
    "down the first letter
    let toReturn = substitute(a:s, '^\(.\)', '\=tolower(submatch(1))', '')
    "turn all 'X' into '_x'
    return substitute(toReturn, '\([A-Z]\)', '\=tolower("_".submatch(1))', 'g')
endfunction
"}}}

" new snippet handler {{{1

" at this point we assume that we already have a proper snippet trigger
function! s:ParseSnippet(trigger, snippet)
    let line = line(".")

    " add indent to each line of the snippet
    let snippet = s:AddIndent(a:trigger, a:snippet)

    " for the mark generation we use the actual snippet
    " not yet split
    let markers = s:Marker.getAllMarker(a:snippet)
    let snippet = s:Marker.removeMarkers(snippet)
    let snippet = s:Marker.removePlaceholder(snippet)

    " insert the snippet
    call setline (line, snippet)

    " jump to first tabstop
    call cursor(s:Marker.tabstops[4]['line'], s:Marker.tabstops[4]['col']-1)
    return ''
endfunction

function! s:AddIndent(trigger, snippet)
    " turn the snippets into a list of newline seperated items
    let snippet = split(a:snippet, "\n", 1)

    " get position of snippet start
    let col = col(".") - len(a:trigger)

    " remove snippet trigger
    silent exe 's/'.escape(a:trigger, '.^$/\*[]').'\%#//'

    let lines = []
    for line in snippet
        " TODO: add current indent level to snippet
        call add(lines, line)
    endfor

    return lines
endfunction

" Marker class {{{1
let s:Marker = {}
" tempTabstops before you translate the snippet into a line based
" list
let s:Marker.tabstops = {}

"get all marks for a given snippet
function! s:Marker.getAllMarker(snippet)
    let i = 1
    let markers = []
    while i
        try
            let marker = s:Marker.nextMarker(a:snippet, i)
            call add(markers, marker)
            let i += 1
        catch /NERDSnippets.NoMarkersFoundError/
            break
        endtry
    endwhile

    return markers
endfunction

"jump the cursor to the start of the next marker and return an array of the
"for [start_column, end_column], where start_column points to the start of
"<+ and end_column points to the start of +> {{{1
function! s:Marker.nextMarker(line,index)
    let start = match(a:line, '\V'.s:start.a:index.'\.\{-\}'.s:end)
    if start == -1
        throw "NERDSnippets.NoMarkersFoundError"
    endif

    let l = a:line
    let balance = 0
    let i = start
    while i < strlen(l)
        if strpart(l, i, strlen(s:start)) == s:start
            let balance += 1
        elseif strpart(l, i, strlen(s:end)) == s:end
            let balance -= 1
        endif

        if balance == 0
            "add 1 for 'string index' => 'column number' conversion
            return [start,i+1]
        endif

        let i += 1

    endwhile
    throw "NERDSnippets.MalformedMarkersError"
endfunction

function! s:Marker.removeMarker(snippet, lnum, i, marker)
    " length of the marker start
    let startlen = strlen(s:start) + strlen(a:i) + 1
    let endlen = strlen(s:end)

    let start = a:marker[0]
    let end = a:marker[1] - 1
    let startOfBody = start + startlen
    let bodyLen = end-startOfBody
    let snip = strpart(a:snippet, 0, start) .
                \ strpart(a:snippet, startOfBody, bodyLen) .
                \ strpart(a:snippet, end+endlen)

    
    " add tab stop to our list
    call s:Marker.addTabstop(a:lnum, a:i, startOfBody, bodyLen)

    return snip
endfunction

function! s:Marker.addTabstop(lnum, i, start, len)
    let s:Marker.tabstops[a:i] = { 'line': a:lnum+1, 'col': a:start, 'end':a:len }
    
    " get size of tabstop marker surrounding
    let len = strlen(s:start) + strlen(a:i) + 1 + strlen(s:end)

    " update the tabstops
    call s:Marker.updateTabstops(a:i, a:start, len)
endfunction

function! s:Marker.updateTabstops(i, start, len)
    for marker in keys(s:Marker.tabstops)
        " check if start position is greater the last modified
        " snippet and adjust it's position if so
        if s:Marker.tabstops[marker]['col'] > a:start
            let s:Marker.tabstops[marker]['col'] -= a:len
        endif
    endfor
endfunction

"removes a set of markers from the current cursor postion
"
"i.e. turn this
"   foo <+foobar+> foo

"into this
"
"  foo foobar foo {{{1
function! s:Marker.removeMarkers(snippet)
    let snip = a:snippet

    let i = 1
    let lnum = match(snip, '\V'.s:start.i.'\.\{-\}'.s:end)
    while lnum != -1
        try
            let marker = s:Marker.nextMarker(snip[lnum], i)
            let snip[lnum] = s:Marker.removeMarker(snip[lnum], lnum, i, marker)
            let i += 1
            let lnum = match(a:snippet, '\V'.s:start.i.'\.\{-\}'.s:end)
        catch /NERDSnippets.NoMarkersFoundError/
            break
        endtry
    endwhile

    " currently all tabs are in one line
    " we will extract the line numbers and update the 
    " tabstops accordingly

    return snip
endfunction

function! s:Marker.removePlaceholder(snippet)
    let snip = a:snippet

    "iterate through tabstop counts and see if we got a 
    "corresponding placeholder
    for i in keys(s:Marker.tabstops)
        let j = 0
        for line in snip
            let start = match(line, '$'.i)
            let line = substitute(line, '$'.i, '', 'g')

            "TODO: we need to adjust tabstops 
            let snip[j] = line
            let j += 1
        endfor
    endfor
    return snip
endfunction
"}}}1

" vim: set ft=vim ff=unix fdm=marker sts=4 sw=4 et:
