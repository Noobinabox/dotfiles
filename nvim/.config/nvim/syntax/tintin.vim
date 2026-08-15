if exists("b:current_syntax")
  finish
endif

syn case ignore

syn match tintinRepeat /^\s*#\d\+\>/

syn match tintinCommand /\c#\s*\%(action\|alias\|all\|bell\|break\|buffer\|button\|case\|cat\|chat\|class\|config\|continue\|cr\|cursor\|daemon\|debug\|default\|delay\|draw\|echo\|edit\|else\|elseif\|end\|event\|foreach\|format\|function\|gag\|grep\|help\|highlight\|history\|if\|ignore\|info\|kill\|line\|list\|local\|log\|loop\|macro\|map\|math\|message\|nop\|parse\|path\|pathdir\|port\|prompt\|read\|regexp\|repeat\|replace\|return\|run\|scan\|screen\|script\|send\|session\|showme\|snoop\|split\|ssl\|substitute\|suspend\|switch\|system\|tab\|textin\|ticker\|time\|variable\|while\|write\|zap\)\>/
syn match tintinComment /^\s*#nop\>.*/

syn match tintinVariable /\$[A-Za-z_][A-Za-z0-9_]*/
syn match tintinParameter /%\(\d\{1,2}\|\*\|[dDisSwW]\)/
syn match tintinEscape /\\./
syn match tintinNumber /\v(^|[^A-Za-z0-9_$])\zs\d+(\.\d+)?\ze([^A-Za-z0-9_$]|$)/
syn match tintinSeparator /;/
syn match tintinBrace /[{}]/

syn region tintinString start=/"/ skip=/\\./ end=/"/
syn region tintinString start=/'/ skip=/\\./ end=/'/

hi def link tintinBrace Delimiter
hi def link tintinCommand Statement
hi def link tintinComment Comment
hi def link tintinEscape SpecialChar
hi def link tintinNumber Number
hi def link tintinParameter Identifier
hi def link tintinRepeat Repeat
hi def link tintinSeparator Delimiter
hi def link tintinString String
hi def link tintinVariable Identifier

let b:current_syntax = "tintin"
