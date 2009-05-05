" ============================================================================
" File:        NERDSnippets.vim
" Description: vim global plugin for snippets that own hard
" Maintainer:  Martin Grenfell <martin_grenfell at msn dot com>
"              Reza Jelveh
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
    let g:NERDSnippets_marker_start = '<+'
endif
let s:start = g:NERDSnippets_marker_start

if !exists("g:NERDSnippets_marker_end")
    let g:NERDSnippets_marker_end = '+>'
endif
let s:end = g:NERDSnippets_marker_end

let s:in_windows = has("win16") ||  has("win32") || has("win64")

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
        let snippet = s:ExpandSnippet(snippet_name)
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
    endif

    try
        let markerPos = s:nextMarker()
        let markersEmpty = stridx(getline("."), s:start.s:end) == markerPos[0]-1

        let removedMarkers = 0
        if s:removeMarkers()
            let markerPos[1] -= (strlen(s:start) + strlen(s:end))
            let removedMarkers = 1
        endif

        call cursor(line("."), markerPos[0])
        normal! v
        call cursor(line("."), markerPos[1] + strlen(s:end) - 1 + (&selection == "exclusive"))

        if removedMarkers && markersEmpty
            return "\<right>"
        else
            return "\<c-\>\<c-n>gvo\<c-g>"
        endif

    catch /NERDSnippets.NoMarkersFoundError/
        if s:appendTab && a:allowAppend
            if g:NERDSnippets_key == "<tab>"
                return "\<tab>"
            endif
        endif
        "we were called from normal mode so return to normal and move the
        "cursor forward again
        return "\<ESC>l"
    endtry

endfunction
"}}}1

"jump the cursor to the start of the next marker and return an array of the
"for [start_column, end_column], where start_column points to the start of
"<+ and end_column points to the start of +> {{{1
function! s:nextMarker()
    let start = searchpos('\V'.s:start.'\.\{-\}'.s:end, 'c')[1]
    if start == 0
        throw "NERDSnippets.NoMarkersFoundError"
    endif

    let l = getline(".")
    let balance = 0
    let i = start-1
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
" }}}1

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

"removes a set of markers from the current cursor postion
"
"i.e. turn this
"   foo <+foobar+> foo

"into this
"
"  foo foobar foo {{{1
function! s:removeMarkers()
    try
        let marker = s:nextMarker()
        if strpart(getline('.'), marker[0]-1, strlen(s:start)) == s:start

            "remove them
            let line = getline(".")
            let start = marker[0] - 1
            let startOfBody = start + strlen(s:start)
            let end = marker[1] - 1
            let line = strpart(line, 0, start) .
                        \ strpart(line, startOfBody, end - startOfBody) .
                        \ strpart(line, end+strlen(s:end))
            call setline(line("."), line)
            return 1
        endif
    catch /NERDSnippets.NoMarkersFoundError/
    endtry
endfunction
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
" snipmate based stuff{{{1

fun s:ExpandSnippet(trigger)
    let col = col('.') - len(a:trigger)
    " remove the trigger from the input
    " this must be after the col getting otherwise indented snippets
    " will lose the first indentlevel for the mark => bad
    silent exe 's/'.escape(a:trigger, '.^$/\*[]').'\%#//'

    let lnum = line('.')

    call s:ProcessSnippet()
    if s:snippet == ''
        return unl s:snippet " Avoid an error if the snippet is now empty
    endif


    " at this point all trigger contents have been duplicated
    " ie. the c for snippet for (${2:i}i = 0; $2i < ${1:count}count; $2i${3:++}++)
    let snip = split(substitute(s:snippet, '$\d\|${\d.\{-}}', '', 'g'), "\n", 1)

    let line = getline(lnum)
    let afterCursor = strpart(line, col - 1)
    if afterCursor != "\t" && afterCursor != ' '
        let line = strpart(line, 0, col - 1)
        let snip[-1] .= afterCursor
    else
        let afterCursor = ''
        " For some reason the cursor needs to move one right after this
        if line != '' && col == 1 && &ve !~ 'all\|onemore'
            let col += 1
        endif
    endif

    call setline(lnum, line.snip[0])

    " Autoindent snippet according to previous indentation
    let indent = matchend(line, '^.\{-}\ze\(\S\|$\)') + 1
    call append(lnum, map(snip[1:], "'".strpart(line, 0, indent - 1)."'.v:val"))

    if exists('s:snipPos') && stridx(s:snippet, '${1') != -1
        if exists('s:update')
            call s:UpdateSnip(len(snip[-1]) - len(afterCursor))
            call s:UpdatePlaceholderTabStops()
        else
            call s:UpdateTabStops(len(snip) - 1, len(snip[-1]) - len(afterCursor))
        endif
    endif

    let snipLen = s:BuildTabStops(lnum, col - indent, indent)
    unl s:snippet

    if snipLen
        if exists('s:snipLen')
            let s:snipLen += snipLen | let s:curPos += 1
        else
            let s:snipLen = snipLen | let s:curPos = 0
        endif
        let s:endSnip     = s:snipPos[s:curPos][1]
        let s:endSnipLine = s:snipPos[s:curPos][0]

        call cursor(s:snipPos[s:curPos][0], s:snipPos[s:curPos][1])
        let s:prevLen = [line('$'), col('$')]
        if s:snipPos[s:curPos][2] != -1 | return s:SelectWord() | endif
    else
        if !exists('s:snipLen') | unl s:snipPos | endif
        " Place cursor at end of snippet if no tab stop is given
        let newlines = len(snip) - 1
        call cursor(lnum + newlines, indent + len(snip[-1]) - len(afterCursor)
                    \ + (newlines ? 0: col - 1))
    endif
    return ''
endf

fun s:ProcessSnippet()
	" Evaluate eval (`...`) expressions.
	" Using a loop here instead of a regex fixes a bug with nested "\=".
	if stridx(s:snippet, '`') != -1
		wh match(s:snippet, '`.\{-}`') != -1
			let s:snippet = substitute(s:snippet, '`.\{-}`',
						\ substitute(eval(matchstr(s:snippet, '`\zs.\{-}\ze`')),
						\ "\n\\%$", '', ''), '')
		endw
		let s:snippet = substitute(s:snippet, "\r", "\n", 'g')
	endif

	" Place all text after a colon in a tab stop after the tab stop
	" (e.g. "${#:foo}" becomes "${:foo}foo").
	" This helps tell the position of the tab stops later.
	let s:snippet = substitute(s:snippet, '${\d:\(.\{-}\)}', '&\1', 'g')

	" Update the s:snippet so that all the $# become
	" the text after the colon in their associated ${#}.
	" (e.g. "${1:foo}" turns all "$1"'s into "foo")
	let i = 1
	wh stridx(s:snippet, '${'.i) != -1
		let s = matchstr(s:snippet, '${'.i.':\zs.\{-}\ze}')
		if s != ''
			let s:snippet = substitute(s:snippet, '$'.i, '&'.s, 'g')
		endif
		let i += 1
	endw

	if &et " Expand tabs to spaces if 'expandtab' is set.
		let s:snippet = substitute(s:snippet, '\t',
						\ repeat(' ', &sts ? &sts : &sw), 'g')
	endif
endf

" removesnippet {{{2
fun s:RemoveSnippet()
	unlet s:snipPos s:curPos s:snipLen s:endSnip s:endSnipLine s:prevLen
endf
" }}}2

" UpdatePlaceholderTabStops {{{2
fun s:UpdatePlaceholderTabStops()
	" Update tab stops in snippet if text has been added via "$#",
	" e.g. in "${1:foo}bar$1${2}"
	if exists('s:origPos')
		let changeLen = s:origWordLen - s:snipPos[s:curPos][2]

		" This could probably be more efficent...
		if changeLen != 0
			let lnum = line('.')
			let len = len(s:origPos)
			for pos in s:snipPos[(s:curPos + 1):]
				let i = 0 | let j = 0 | let k = 0
				let endSnip = pos[2] + pos[1] - 1
				wh i < len && s:origPos[i][0] <= pos[0]
					if pos[0] == s:origPos[i][0]
						if pos[1] > s:origPos[i][1]
								\ || (pos[2] == -1 && pos[1] == s:origPos[i][1])
							let j += 1
						elseif s:origPos[i][1] < endSnip " Parse variables within placeholders
							let k += 1
						endif
					endif
					let i += 1
				endw
				if pos[0] == lnum && pos[1] > s:origSnipPos
					let j += 1
				endif
				let pos[1] -= changeLen*j
				let pos[2] -= changeLen*k

				if pos[2] != -1
					for nPos in pos[3]
						let i = 0 | let j = 0
						wh i < len && s:origPos[i][0] <= nPos[0]
							if nPos[0] == s:origPos[i][0] && nPos[1] > s:origPos[i][1]
								let j += 1
							endif
							let i += 1
						endw
						if nPos[0] == lnum && nPos[1] > s:origSnipPos
							let j += 1
						endif
						if nPos[0] > s:origPos[0][0] | break | endif
						let nPos[1] -= changeLen*j
					endfor
				endif
			endfor
		endif
		unl s:endSnip s:origPos s:origSnipPos
	endif
	unl s:startSnip s:origWordLen s:update
endf
" }}}2

" {{{2
fun s:UpdateTabStops(...)
	let changeLine = a:0 ? a:1 : s:endSnipLine - s:snipPos[s:curPos][0]
	let changeCol  = a:0 > 1 ? a:2 : s:endSnip - s:snipPos[s:curPos][1]
	if exists('s:origWordLen')
		let changeCol -= s:origWordLen | unl s:origWordLen
	endif
	" There's probably a more efficient way to do this as well...
	let lnum = s:snipPos[s:curPos][0]
	let col  = s:snipPos[s:curPos][1]
	" Update the line number of all proceeding tab stops if <cr> has
	" been inserted.
	if changeLine != 0
		for pos in s:snipPos[(s:curPos + 1):]
			if pos[0] >= lnum
				if pos[0] == lnum
					let pos[1] += changeCol
				endif
				let pos[0] += changeLine
			endif
			if pos[2] != -1
				for nPos in pos[3]
					if nPos[0] >= lnum
						if nPos[0] == lnum
							let nPos[1] += changeCol
						endif
						let nPos[0] += changeLine
					endif
				endfor
			endif
		endfor
	elseif changeCol != 0
		" Update the column of all proceeding tab stops if text has
		" been inserted/deleted in the current line.
		for pos in s:snipPos[(s:curPos + 1):]
			if pos[1] >= col && pos[0] == lnum
				let pos[1] += changeCol
			endif
			if pos[2] != -1
				for nPos in pos[3]
					if nPos[0] > lnum | break | endif
					if nPos[0] == lnum && nPos[1] >= col
						let nPos[1] += changeCol
					endif
				endfor
			endif
		endfor
	endif
endf
" }}}2


" jumptabstop {{{2
fun s:JumpTabStop()
	if exists('s:update')
		call s:UpdatePlaceholderTabStops()
	else
		call s:UpdateTabStops()
	endif

	let s:curPos += 1
	if s:curPos == s:snipLen
		let sMode = s:endSnip == s:snipPos[s:curPos-1][1]+s:snipPos[s:curPos-1][2]
		call s:RemoveSnippet()
		return sMode ? "\<tab>" : TriggerSnippet()
	endif

	call cursor(s:snipPos[s:curPos][0], s:snipPos[s:curPos][1])

	let s:endSnipLine = s:snipPos[s:curPos][0]
	let s:endSnip     = s:snipPos[s:curPos][1]
	let s:prevLen     = [line('$'), col('$')]

	return s:snipPos[s:curPos][2] == -1 ? '' : s:SelectWord()
endf
" }}}2

" buildtabstops{{{2

" This function builds a list of a list of each tab stop in the
" snippet containing:
" 1.) The tab stop's line number.
" 2.) The tab stop's column number
"     (by getting the length of the string between the last "\n" and the
"     tab stop).
" 3.) The length of the text after the colon for the current tab stop
"     (e.g. "${1:foo}" would return 3). If there is no text, -1 is returned.
" 4.) If the "${#:}" construct is given, another list containing all
"     the matches of "$#", to be replaced with the placeholder. This list is
"     composed the same way as the parent; the first item is the line number,
"     and the second is the column.
fun s:BuildTabStops(lnum, col, indent)
	let snipPos = []
	let i = 1
	let withoutVars = substitute(s:snippet, '$\d', '', 'g')
	while stridx(s:snippet, '${'.i) != -1
		let beforeTabStop = matchstr(withoutVars, '^.*\ze${'.i)
		let withoutOthers = substitute(withoutVars, '${'.i.'\@!\d.\{-}}', '', 'g')
		let snipPos += [[a:lnum + s:Count(beforeTabStop, "\n"),
						\ a:indent + len(matchstr(withoutOthers,
						\ "^.*\\(\n\\|^\\)\\zs.*\\ze${".i)), -1]]
		if snipPos[i-1][0] == a:lnum
			let snipPos[i-1][1] += a:col
		endif

		" Get all $# matches in another list, if ${#:name} is given
		if stridx(withoutVars, '${'.i.':') != -1
			let j = i-1
			let snipPos[j][2] = len(matchstr(withoutVars, '${'.i.':\zs.\{-}\ze}'))
			let snipPos[j] += [[]]
			let withoutOthers = substitute(s:snippet, '${\d.\{-}}\|$'.i.'\@!\d', '', 'g')
			while stridx(withoutOthers, '$'.i) != -1
				let beforeMark = matchstr(withoutOthers, '^.\{-}\ze$'.i)
				let linecount = a:lnum + s:Count(beforeMark, "\n")
				let snipPos[j][3] += [[linecount,
							\ a:indent + (linecount > a:lnum
							\ ? len(matchstr(beforeMark, "^.*\n\\zs.*"))
							\ : a:col + len(beforeMark))]]
				let withoutOthers = substitute(withoutOthers, '$'.i, '', '')
			endw
		endif
		let i += 1
	endw

	if exists('s:snipPos') " Build a nested snippet
		let s:snipPos = extend(s:snipPos, snipPos, s:curPos + 1)
	else
		let s:snipPos = snipPos
	endif
	return i-1
endf
" }}}2

" text processing helper {{{2
fun s:Count(haystack, needle)
	let counter = 0
	let index = stridx(a:haystack, a:needle)
	while index != -1
		let index = stridx(a:haystack, a:needle, index+1)
		let counter += 1
	endw
	return counter
endf


fun s:SelectWord()
	let s:origWordLen = s:snipPos[s:curPos][2]
	let s:oldWord     = strpart(getline('.'), s:snipPos[s:curPos][1] - 1,
								\ s:origWordLen)
	let s:prevLen[1] -= s:origWordLen
	if !empty(s:snipPos[s:curPos][3])
		let s:update    = 1
		let s:endSnip   = -1
		let s:startSnip = s:snipPos[s:curPos][1] - 1
	endif
	if !s:origWordLen | return '' | endif
	let l = col('.') != 1 ? 'l' : ''
	if &sel == 'exclusive'
		return "\<esc>".l.'v'.s:origWordLen."l\<c-g>"
	endif
	return s:origWordLen == 1 ? "\<esc>".l.'gh'
							\ : "\<esc>".l.'v'.(s:origWordLen - 1)."l\<c-g>"
endf
" }}}2


" {{{2
" This updates the snippet as you type when text needs to be inserted
" into multiple places (e.g. in "${1:default text}foo$1bar$1",
" "default text" would be highlighted, and if the user types something,
" UpdateChangedSnip() would be called so that the text after "foo" & "bar"
" are updated accordingly)
"
" It also automatically quits the snippet if the cursor is moved out of it
" while in insert mode.
au CursorMovedI * call s:UpdateChangedSnip(0)
au InsertEnter * call s:UpdateChangedSnip(1)
fun s:UpdateChangedSnip(entering)
	if exists('s:update')
		if !exists('s:origPos') && s:curPos + 1 < s:snipLen
			" Save the old snippet & word length before it's updated
			" s:startSnip must be saved too, in case text is added
			" before the snippet (e.g. in "foo$1${2}bar${1:foo}").
			let s:origSnipPos = s:startSnip
			let s:origPos     = deepcopy(s:snipPos[s:curPos][3])
		endif
		let col = col('.') - 1

		if s:endSnip != -1
			let changeLen = col('$') - s:prevLen[1]
			let s:endSnip += changeLen
		else " When being updated the first time, after leaving select mode
			if a:entering | return | endif
			let s:endSnip = col - 1
		endif

		" If the cursor moves outside the snippet, quit it
		if line('.') != s:snipPos[s:curPos][0] || col < s:startSnip ||
					\ col - 1 > s:endSnip
			unl! s:startSnip s:origWordLen s:origPos s:update
			return s:RemoveSnippet()
		endif

		call s:UpdateSnip()
		let s:prevLen[1] = col('$')
	elseif exists('s:snipPos')
		let col        = col('.')
		let lnum       = line('.')
		let changeLine = line('$') - s:prevLen[0]

		if lnum == s:endSnipLine
			let s:endSnip += col('$') - s:prevLen[1]
			let s:prevLen = [line('$'), col('$')]
		endif
		if changeLine != 0
			let s:endSnipLine += changeLine
			let s:endSnip = col
		endif

		" Delete snippet if cursor moves out of it in insert mode
		if (lnum == s:endSnipLine && (col > s:endSnip || col < s:snipPos[s:curPos][1]))
			\ || lnum > s:endSnipLine || lnum < s:snipPos[s:curPos][0]
			call s:RemoveSnippet()
		endif
	endif
endf

fun s:UpdateSnip(...)
	" Using strpart() here avoids a bug if s:endSnip was negative that would
	" happen with the getline('.')[(s:startSnip):(s:endSnip)] syntax
	let newWordLen = a:0 ? a:1 : s:endSnip - s:startSnip + 1
	let newWord    = strpart(getline('.'), s:startSnip, newWordLen)
	if newWord != s:oldWord
		let changeLen    = s:snipPos[s:curPos][2] - newWordLen
		let curLine      = line('.')
		let startCol     = col('.')
		let oldStartSnip = s:startSnip
		let updateSnip   = changeLen != 0
		let i            = 0

		for pos in s:snipPos[s:curPos][3]
			if updateSnip
				let start = s:startSnip
				if pos[0] == curLine && pos[1] <= start
					let s:startSnip -= changeLen
					let s:endSnip -= changeLen
				endif
				for nPos in s:snipPos[s:curPos][3][(i):]
					if nPos[0] == pos[0]
						if nPos[1] > pos[1] || (nPos == [curLine, pos[1]] &&
												\ nPos[1] > start)
							let nPos[1] -= changeLen
						endif
					elseif nPos[0] > pos[0] | break | endif
				endfor
				let i += 1
			endif

			call setline(pos[0], substitute(getline(pos[0]), '\%'.pos[1].'c'.
						\ s:oldWord, newWord, ''))
		endfor
		if oldStartSnip != s:startSnip
			call cursor('.', startCol + s:startSnip - oldStartSnip)
		endif

		let s:oldWord = newWord
		let s:snipPos[s:curPos][2] = newWordLen
	endif
endf
" }}}2
" }}}1

" vim: set ft=vim ff=unix fdm=marker sts=4 sw=4 et:
