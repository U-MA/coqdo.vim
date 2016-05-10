Coqdo.vim
===

coqtop with Vim.

## Requirement

  * [vimproc](https://github.com/Shougo/vimproc.vim)

## Usage

### :Coqdo

  Start coqtop.

### :CoqdoQuit

  Quit coqtop.

### :CoqdoGoto

  Go to current line just like `Go to cursor` in CoqIDE.
  But do not backward now.

### :CoqdoClear

  Restart coqtop.

### :CoqdoForward

  Go to next line.

### :CoqdoBackward

  Back to previous line.

### :CoqdoSearchAbout

  Do SearchAbout command.

## Default key mapping

  Define `g:coqdo_default_key_mapping` to enable default key mapping.

  For example `let g:coqdo_default_key_mapping = 1`.

  | Coqdo command   | key mapping      |
  |:---------------:|:----------------:|
  | `CoqdoQuit`     | `<LocalLeader>q` |
  | `CoqdoGoto`     | `<LocalLeader>g` |
  | `CoqdoClear`    | `<LocalLeader>c` |
  | `CoqdoForward`  | `<LocalLeader>j` |
  | `CoqdoBackward` | `<LocalLeader>k` |

