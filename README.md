Major more for editing [64tass](https://tass64.sourceforge.net/)
syntax source files.

# Use

Add appropriate folder to `load-path`. Then:

    (require '64tass-mode)
	
# Usage

It's a fairly ordinary major mode, prefix `64tass`. Activate with M-x
`64tass-mode`, or add file patterns of interest to `auto-mode-alist`;
add hooks to `64tass-mode-hook`; set mode-specific keys with
`64tass-mode-map` - and so on.

Features:

- sets `comment-start`, `comment-start-skip` and `comment-end-skip`,
  so that comment functions work ok. I only really use `comment-dwim`
  myself though
- sets a handler for `fill-paragraph` to stop it making a mess
  if invoked outside comments
- sets `compilation-error-regexp-alist` to handle 64tass output
- sets an imenu handler so that nested labels are shown with their
  full names
- press TAB to cycle indentation: column 0, instruction column
  (controlled by `64tass-instruction-indent`), or comment column
  (controlled by `comment-column`). This will try to find comment
  blocks too and cycle their indentation as a whole
  
  The behaviour is supposed to be vaguely reminiscent of python mode:
  the indentation will always cycle if you keep pressing TAB, but the
  first decision is supposed to be sensible
- use `C-c C-n` (`64tass-cycle-construct`) to find matching parts of
  the same construct: `.block`/`.endblock`, `.logical`/`.endlogical`,
  the various `if` options - and so on

## `64tass-lst-mode`

Use `64tass-lst-mode` if looking at a .lst file from 64tass.

- use `C-c C-r` (`64tass-lst-revert-buffer`) to revert the buffer. On
  the assumption these files are always transient, it will just do it
  for you, no questions asked, discarding any changes
- use `C-c C-l` (`64tass-lst-visit-source`) to visit the corresponding
  source line, assuming this lst was produced by the last run of
  `compile`. It will treat `default-directory` in buffer
  `*compilation*` as the base path for any relative paths encountered

# Licence

See the file [LICENCE](./LICENCE).

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
