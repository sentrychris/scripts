#/usr/bin/env bash

function extract {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xvjf $1;;
      *.tar.gz)    tar xvzf $1;;
      *.tar.xz)    tar Jxvf $1;;
      *.bz2)       bunzip2 $1;;
      *.rar)       rar x $1;;
      *.gz)        gunzip $1;;
      *.tar)       tar xvf $1;;
      *.tbz2)      tar xvjf $1;;
      *.tgz)       tar xvzf $1;;
      *.zip)       unzip -d `echo $1 | sed 's/\(.*\)\.zip/\1/'` $1;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1;;
      *)           echo "cannot extract '$1'";;
    esac
  else
    echo "'$1' does not exist"
  fi
}

function gitbranch
{
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

PATH="$PATH:/home/chris/.local/bin"
PATH="$PATH:/home/chris/.config/composer/vendor/bin"

# Bash prompt
PS1='\[\033]0;${PWD//[^[:ascii:]]/?}\007\]'
PS1=$PS1'\[\033[1;38;5;117m\]\u '
PS1=$PS1'\[\033[1;00m\]\w'
PS1=$PS1'\[\033[1;38;5;218m\]$(gitbranch)\[\033[1;38;5;166m\] λ \[\033[1;00m\]'
