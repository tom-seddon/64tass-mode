;;; 64tass-mode
;;
;; (Started out as dasm-mode,
;; http://www.cling.gu.se/~cl3polof/dasm-mode.el -- but I think it's
;; pretty much been rewritten at this point?)
;;
;; Copyright 2002 Per Olofsson
;;
;; Copyright 2008-24 Tom Seddon
;;
;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see
;; <https://www.gnu.org/licenses/>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; For use with 64tass: https://tass64.sourceforge.net/
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; . TAB cycles valid indentations, like python-mode. It knows about
;; comments, subroutine, and local names
;;
;; . imenu function populates the list with fully-qualified names
;;
;; . compilation error regexps handle 64tass output with M-x compile
;;
;; . C-c C-n cycles through the various parts of .if/.else/.endif,
;; .for/.endfor, etc.
;;
;; . Use 64tass-lst-mode for .lst files. C-c C-r reverts the file, no
;; questions asked. C-c C-l will try to visit the source line,
;; assuming built with --line-numbers, assuming paths relative to the
;; default-directory of the *compilation* buffer
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'cl-lib)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgroup _6502 nil
  "Major mode for editing 6502 code"
  :prefix "64tass-"
  :group 'languages)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom 64tass-instruction-indent 16
  "column for instruction"
  :group '_6502)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--all-64tass-directives ()
  (split-string ".addr .al .align .alignblk .alignind .alignpageind .as .assert .autsiz .bend .binary .binclude .bfor .block .break .breakif .brept .bwhile .byte .case .cdef .cerror .char .check .comment .continue .continueif .cpu .cwarn .databank .default .dint .dpage .dsection .dstruct .dunion .dword .edef .elif .else .elsif .enc .encode .end .endblock .endc .endalignblk .endcomment .endencode .endf .endfor .endfunction .endif .endlogical .endm .endmacro .endn .endnamespace .endp .endpage .endproc .endrept .ends .endsection .endsegment .endstruct .endswitch .endu .endunion .endv .endvirtual .endweak .endwhile .endwith .eor .error .fi .fill .for .from .function .goto .here .hidemac .if .ifeq .ifmi .ifne .ifpl .include .lbl .lint .logical .long .macro .mansiz .namespace .next .null .offs .option .page .pend .proc .proff .pron .ptext .rept .rta .section .seed .segment .send .sfunction .shift .shiftl .showmac .sint .struct .switch .tdef .text .union .var .virtual .warn .weak .while .with .word .xl .xs"))

;; directives that should get the warning face
(defun 64tass--warn-directives ()
  '(".cerror" ".error" ".cwarn" ".warn"))

;; returns 
(defun 64tass--word-regexp-opt (strings)
  (eval `(rx symbol-start
	     (or ,@strings)
	     symbol-end)))

(defun 64tass--nmos-mnemonics ()
  '("adc" "and" "asl" "bcc" "bcs" "beq" "bit" "bmi" "bne" "bpl" "brk" "bvc" "bvs" "clc" "cld" "cli" "clv" "cmp" "cpx" "cpy" "dec" "dex" "dey" "eor" "inc" "inx" "iny" "jmp" "jsr" "lda" "ldx" "ldy" "lsr" "nop" "ora" "pha" "php" "pla" "plp" "rol" "ror" "rti" "rts" "sbc" "sec" "sed" "sei" "sta" "stx" "sty" "tax" "tay" "tsx" "txa" "txs" "tya"))

(defun 64tass--cmos-mnemonics ()
  '("plx" "ply" "phx" "phy" "stz" "tsb" "trb" "bra"))

(defun 64tass--all-64tass-types ()
  (split-string "address bits bool bytes code dict float gap int list str tuple type"))

(defun 64tass--all-64tass-builtin-functions ()
  (split-string " abs acos addr all any asin atan atan2 binary byte cbrt ceil char cos cosh deg dint dword exp floor format frac hypot len lint log log10 long pow rad random range repr round rta sign sin sinh sint size sort sqrt tan tanh trunc word "))

(defvar 64tass-font-lock-keywords
  (eval-when-compile
    `(
      ;; comment-face
      ("[^']\\(;.*\\)$" . font-lock-comment-face)

      ;; constant-face
      ("^\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\b" . font-lock-constant-face)

      ;; function-name-face
      ("^\\(\\.[a-zA-Z0-9_]+\\)\\b" . font-lock-function-name-face)
      (,(64tass--word-regexp-opt (64tass--all-64tass-builtin-functions))
       .
       font-lock-function-name-face)

      ;; type-face
      (,(64tass--word-regexp-opt (64tass--all-64tass-types))
       .
       font-lock-type-face)

      ;; builtin-face
      (,(64tass--word-regexp-opt
	 (cl-set-difference (64tass--all-64tass-directives)
			    (64tass--warn-directives)
			    :test 'equal))
       .
       font-lock-builtin-face)
      
      ;; warning-face
      (,(64tass--word-regexp-opt (64tass--warn-directives))
       .
       font-lock-warning-face)

      ;; keyword-face
      (,(64tass--word-regexp-opt (cl-union (64tass--nmos-mnemonics)
					     (64tass--cmos-mnemonics)
					     :test 'equal))
       .
       font-lock-keyword-face)
      ))
  "Expressions to highlight in 64tass-mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; rx snippet for 6502 labels.
(defvar 64tass--label-rx)
(setq 64tass--label-rx '(and (1+ (any word "_" "."))))

;; regexp for things that go in column 0.
(defvar 64tass--column0-regexp)
(setq 64tass--column0-regexp
      (rx
       (or
	;; dasm subroutine/64tass 
	(and (eval 64tass--label-rx) (1+ space) (or "subroutine"
						      (and "." (1+ word))))

	;; label with colon
	(and (eval 64tass--label-rx) ":")

	;; anonymous label
	"+"
	"-"

	;; assignment
	(and (eval 64tass--label-rx) (0+ space) (or "="
						      ":="))
	(and "*" (0+ space) "=")
	)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar 64tass--message-enabled nil)

(defun 64tass--message (fmt &rest args)
  (when 64tass--message-enabled
    (apply 'message fmt args)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--current-indentation ()
  "Get indentation column of current line"
  (save-excursion
    (back-to-indentation)
    (current-column)))

(defun 64tass--line-type ()
  "Get type of current line, a symbol.

Types are `column0' (something that should be in column 0),
`comment' (a comment), `empty' (a blank line), or nil (other)."
  (save-excursion
    (back-to-indentation)
    (cond
     ((looking-at 64tass--column0-regexp) 'column0)
     ((looking-at (regexp-quote comment-start)) 'comment)
     ((looking-at "$") 'empty)
     (t nil))))

(defun 64tass--reindent-line (new-indent)
  "Set the current line's indentation to NEW-INDENT.

The current column's indentation-relative position will be as
preserved as possible."
  (let ((old-column (current-column))
	(old-indent (64tass--current-indentation)))
    (when (not (eq old-indent new-indent))
      (beginning-of-line)
      (delete-horizontal-space)
      (indent-to new-indent))
    (let ((new-column (+ new-indent (- old-column old-indent))))
      (when (>= new-column 0)
	(move-to-column new-column)))))

(defun 64tass--reindent-lines (num-lines direction new-indent)
  (let ((num-left num-lines))
    (while (> num-left 0)
      (forward-line direction)
      (64tass--reindent-line new-indent)
      (setq num-left (1- num-left)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--count-comment-lines (direction)
  (let ((n 0))
    (while (and (eq (forward-line direction) 0)
		(eq (64tass--line-type) 'comment))
      (setq n (1+ n)))
    (when (not (eq (64tass--line-type) 'comment))
      (forward-line (- direction)))
    n))

(defun 64tass--comment-range ()
  "Find range of current comment.

Return (BACK . FORWARD), where BACK is the number of lines to
move backwards to get to the start of the comment, and FORWARD
the number of lines to move forward to get to the end. Return nil
if not in a comment."
  (cl-block nil
    (when (eq (64tass--line-type) 'comment)
      (let (back forward)
	(save-excursion
	  (setq back (64tass--count-comment-lines -1))
	  
	  ;; Return nil if this appears to be the filled
	  ;; continuation of an end-of-line comment inserted by
	  ;; comment-dwim.
	  (let ((column (64tass--current-indentation)))
	    (when (and (equal (forward-line -1) 0)
		       (equal (move-to-column column) column)
		       (looking-at (regexp-quote comment-start)))
	      (cl-return nil))))
	  
	(save-excursion
	  (setq forward (64tass--count-comment-lines 1)))
	  
	`(,back . ,forward)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--cycle-indentations ()
  "Cycle through valid indentations for the current line"
  (let ((type (64tass--line-type)))
    (cond
     ((equal type 'column0)
      ;; Always put in column 0
      (64tass--reindent-line 0))
     
     ((equal type 'comment)
      (let ((range (64tass--comment-range)))
	(when range
	  (let ((new-indent (if (< (64tass--current-indentation)
				   64tass-instruction-indent)
				64tass-instruction-indent
			      0)))
	    (64tass--message "64tass--cycle-indentations: type=%s new-indent=%s range=%s" type new-indent range)
	    (save-excursion
	      (64tass--reindent-lines (car range) -1 new-indent))
	    (save-excursion
	      (64tass--reindent-lines (cdr range) 1 new-indent))
	    (64tass--reindent-line new-indent)))))

     (t
      (let ((new-indent (if (< (64tass--current-indentation)
			       64tass-instruction-indent)
			    64tass-instruction-indent
			  0)))
	(64tass--reindent-line new-indent))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--is-indent-trigger-command (command)
  (or (eq command 'indent-for-tab-command)
	  (and (boundp 'python-indent-trigger-commands)
	       (member this-command python-indent-trigger-commands))))

(defun 64tass--get-previous-nonempty-line-details (&optional max)
  (save-excursion
    (cl-block nil
      (let ((n 0))
	(while (< n (or max 2))
	  ;; bad if out of lines.
	  (unless (equal (forward-line -1) 0)
	    (cl-return nil))

	  ;;
	  (let ((type (64tass--line-type)))
	    (when (not (equal type 'empty))
	      (cl-return `(,type . ,(64tass--current-indentation)))))

	  (setq n (1+ n)))))))

(defun 64tass--indent (reindent)
  "Indent the current line.

If REINDENT is t, this is due to indent-for-tab-command;
otherwise, this is due to newline-and-indent. This affects how
empty lines are treated."
  (let ((type (64tass--line-type)))
    (64tass--message "64tass--indent: type=%s" type)
    (cond
     ((equal type 'column0)
      ;; Always put in column 0
      (64tass--reindent-line 0))

     ((equal type 'comment)
      ;; If a valid comment, reindent as per previous non-empty line -
      ;; possibly part of the same comment.
      (let ((range (64tass--comment-range)))
	(when range
	  (let ((info (64tass--get-previous-nonempty-line-details)))
	    (64tass--reindent-line (if info
				     (cdr info)
				   0))))))

     ((equal type 'empty)
      ;; When reindenting, just leave empty lines alone.
      ;;
      ;; For newline-and-indent, do something sensible.
      (unless reindent
	(let* ((info (64tass--get-previous-nonempty-line-details))
	       (new-indent (cond
			    ((null info) 64tass-instruction-indent)
			    ((equal (car info) 'column0) 64tass-instruction-indent)
			    ((cdr info)))))
	  (64tass--message "64tass--indent: type=%s reindent=%s info=%s new-indent=%s" type reindent info new-indent)
	  (64tass--reindent-line new-indent))))

     (t
      ;; Always put in instruction column. (If that's wrong, the
      ;; cycling behaviour makes it easy to fix.)
      (64tass--reindent-line 64tass-instruction-indent)))))

(defun 64tass-indent-line ()
  (interactive)

  (64tass--message "64tass-indent-line: this-command=%s last-command=%s point=%s" this-command last-command (point))

  (cond
   ((64tass--is-indent-trigger-command this-command)
    ;; TAB - indent, or cycle with repeated presses.
    (if (equal this-command last-command)
	(64tass--cycle-indentations)
      (64tass--indent t)))
   ((equal this-command 'newline-and-indent)
    (64tass--indent nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--fill-paragraph-function (&optional arg)
  (cl-block nil
    (when (equal (64tass--line-type) 'comment)
      ;; it's a comment line - fill OK.
      (64tass--message "line type is comment")
      (cl-return nil))

    (save-excursion
      (let ((old-point (point))
	    (limit (save-excursion
		     (end-of-line)
		     (point))))
	(beginning-of-line)
	(comment-normalize-vars)
	(let ((com (comment-search-forward limit t)))
	  (when (and com
		     (<= com old-point))
	    ;; inside an inline comment - fill OK.
	    (64tass--message "inside inline comment")
	    (cl-return nil)))))

    ;; other... no fill.
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass--match-string (n)
  (buffer-substring-no-properties (match-beginning n)
				  (match-end n)))

(defvar 64tass--imenu-nesting-openers-regexp
  (eval-when-compile (regexp-opt '("proc"
				   "block"
				   "macro"
				   "struct"
				   "union"))))

(defvar 64tass--imenu-nesting-closers-regexp
  (eval-when-compile (regexp-opt '("endproc" "pend"
				   "endblock" "bend"
				   "endmacro" "endm"
				   "endstruct" "ends"
				   "endunion" "endu"))))

;; TODO - . and $ are valid in labels!
(defvar 64tass--imenu-label-regexp
  (eval-when-compile "[A-Za-z0-9_]+"))

;; Group 1 = label name
(defvar 64tass--imenu-label-or-symbol
  (eval-when-compile
    (rx (group (regexp 64tass--imenu-label-regexp))
	(or (seq (zero-or-more (any space)) "=")
	    ":"))))

;; Group 1 = label name
(defvar 64tass--imenu-named-nesting-opener-regexp
  (eval-when-compile
    (concat "\\(" 64tass--imenu-label-regexp "\\):"
	    "[[:space:]]*"
	    "\\." 64tass--imenu-nesting-openers-regexp)))

(defvar 64tass--imenu-unnamed-nesting-opener-regexp
  (eval-when-compile
    (concat "[[:space:]]*"
	    "\\." 64tass--imenu-nesting-openers-regexp)))

(defvar 64tass--nesting-closer-regexp
  (eval-when-compile
    (concat "[[:space:]]*"
	    "\\." 64tass--imenu-nesting-closers-regexp)))

(defun 64tass--imenu-create-index ()
  (save-restriction
    (let* (stack alist)
      (widen)
      (goto-char (point-min))
      (while (not (eobp))
	(cond
	 ((looking-at 64tass--imenu-named-nesting-opener-regexp)
	  (let* ((full-name
		  (concat (car stack) (64tass--match-string 1))))
	    (push (concat full-name ".") stack)
	    (push (cons full-name (point)) alist)))

	 ((looking-at 64tass--imenu-unnamed-nesting-opener-regexp)
	  ;; This doesn't contribute to the name, but it does need a
	  ;; stack entry.
	  (push (car stack) stack))

	 ((looking-at 64tass--imenu-label-or-symbol)
	  (let* ((full-name
		  (concat (car stack) (64tass--match-string 1))))
	    (push (cons full-name (point)) alist)))

	 ((looking-at 64tass--nesting-closer-regexp)
	  (pop stack)))

	(forward-line 1))
      alist)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cl-defstruct 64tass--construct
  "eoea"
  name
  opening-regexp
  middle-regexp
  closing-regexp)

(defun 64tass--construct-regexp (directives)
  (when directives
    (let* ((rx-sexpr `(rx bol
			  (0+ (syntax -))
			  (optional
			   (or (sequence (eval 64tass--label-rx) ":")
			       "+"
			       "-"))
			  (0+ (syntax -))
			  (group-n 1
			    "."
			    (or ,@(split-string directives))
			    word-end))))
      (eval rx-sexpr t))))

(defvar 64tass--constructs
  (eval-when-compile
    (mapcar (lambda (x)
	      (make-64tass--construct
	       :name (car (split-string (car x)))
	       :opening-regexp (64tass--construct-regexp (car x))
	       :middle-regexp (64tass--construct-regexp (cadr x))
	       :closing-regexp (64tass--construct-regexp (caddr x))))
	    '(("alignblk" nil "endalignblk")
	      ("block" nil "bend endblock")
	      ("comment" "endc" "endcomment")
	      ("encode" nil "endencode")
	      ("for bfor" nil "endfor next")
	      ("function" nil "endf endfunction")
	      ("if ifne ifeq ifpl ifmi" "else elsif elif" "endif fi") ;nth 6
	      ("logical" nil "here endlogical")
	      ("macro" nil "endm endmacro")
	      ("namespace" nil "endn endnamespace")
	      ("page" nil "endpage")
	      ("proc" nil "pend endproc")
	      ("rept brept" nil "next endrept")
	      ("section" nil "send endsection")
	      ("segment" nil "endm endsegment")
	      ("struct" nil "ends endstruct")
	      ("switch" "case default" "endswitch")
	      ("union" nil "endu endunion")
	      ("virtual" nil "endv endvirtual")
	      ("weak" nil "endweak")
	      ("while bwhile" nil "next endwhile")
	      ("with" nil "endwidth")))))

(defun 64tass--looking-at (regexp)
  (when regexp
    (looking-at regexp)))

;; When returning non-nil, the match data has been modified.
(defun 64tass--looking-at-construct (construct)
  (when construct
    (cond
     ((64tass--looking-at (64tass--construct-opening-regexp construct))
      '64tass--construct-opening-regexp)
     ((64tass--looking-at (64tass--construct-middle-regexp construct))
      '64tass--construct-middle-regexp)
     ((64tass--looking-at (64tass--construct-closing-regexp construct))
      '64tass--construct-closing-regexp)
     (t nil))))

(defun 64tass--cycle-construct (construct dir)
  ;;(message "construct=%s dir=%s" construct dir)
  (let (done
	(level 0))
    (while (not done)
      ;; Barf when buffer boundary reached.
      (let ((old-point (point)))
	(forward-line dir)
	(when (= old-point (point))
	  (error (format "Matching part of %s construct not found"
			 (64tass--construct-name construct)))))

      (cl-case (64tass--looking-at-construct construct)
	(64tass--construct-opening-regexp
	 ;; Opening construct
	 (if (> dir 0)
	     ;; Searching forwards - increase nesting level
	     (cl-incf level)
	   ;; Searching backwards - decrease nesting level, possibly
	   ;; finishing.
	   (when (< (cl-decf level) 0)
	     (setq done t))))
	(64tass--construct-middle-regexp
	 (when (> dir 0)
	   ;; Middle construct - finish if at top level.
	   (if (= level 0)
	       (setq done t))))
	(64tass--construct-closing-regexp
	 ;; Closing construct
	 (if (> dir 0)
	     ;; Searching forwards - decrease nesting level, possibly
	     ;; finishing.
	     (when (< (cl-decf level) 0)
	       (setq done t))
	   ;; Searching backwards - increase nesting level
	   (cl-incf level)))))

      ;; Put point on the first char of the appropriate directive.
      (goto-char (match-beginning 1))))

(defun 64tass-cycle-construct ()
  (interactive)

  (let (new-point)
    (save-excursion
      (move-beginning-of-line nil)

      (let ((result (cl-loop
		     with result = nil
		     for construct in 64tass--constructs
		     do (setq result (64tass--looking-at-construct construct))
		     until result
		     finally return (when result (cons result construct)))))
	(unless result
	  (error "Not a 64tass construct"))

	;;(message "%s" (car result))

	(cl-case (car result)
	  ((64tass--construct-opening-regexp
	    64tass--construct-middle-regexp )
	   (64tass--cycle-construct (cdr result) 1))
	  ((64tass--construct-closing-regexp)
	   (64tass--cycle-construct (cdr result) -1)))

	(setq new-point (point))))
    (goto-char new-point)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-derived-mode
  64tass-mode
  fundamental-mode
  "64tass"
  "Mode for editing 6502 cross assembler source."
  (interactive)

  ;;
  ;; Indentation
  ;;

  (setq indent-tabs-mode
	nil)
  
  (set (make-local-variable 'tab-stop-list)
       (list 0
	     64tass-instruction-indent))

;;   (define-key 64tass-mode-map
;;     (kbd "TAB")
;;     'tab-to-tab-stop)

  (set (make-local-variable 'indent-line-function)
       '64tass-indent-line)

  ;;
  ;; Comments
  ;;
  (setq comment-column
	32)

  (make-local-variable 'comment-start)

  ;; python-mode's comment-start includes the trailing space too. So
  ;; it must be OK.
  (setq comment-start "; ")

  ;; from `asm-mode'
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "\\(?:\\s<+\\|/[/*]+\\)[ \t]*")

  ;; from `asm-mode'
  (make-local-variable 'comment-end-skip)
  (setq comment-end-skip "[ \t]*\\(\\s>\\|\\*+/\\)")

  ;;
  ;; Fill paragraph
  ;;
  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function '64tass--fill-paragraph-function)

  ;;
  ;; Font lock
  ;;
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(64tass-font-lock-keywords
			     nil
			     t))

  ;;
  ;; syntax table
  ;;

  ;; ; (not ?;, obviously!) starts a comment
  (modify-syntax-entry 59 "<" 64tass-mode-syntax-table)

  ;; newline ends comments
  (modify-syntax-entry ?\n ">" 64tass-mode-syntax-table)

  ;; various characters are punctuation
  (cl-loop for c in `(?~ ?* ?/ ?% ?+ ?- ?< ?> ?= ?! ?& ?^ ?| ?? ?,) do
	(modify-syntax-entry c "." 64tass-mode-syntax-table))

  ;; . and $ are symbol constituent chars
  (modify-syntax-entry ?. "_" 64tass-mode-syntax-table)
  (modify-syntax-entry ?$ "_" 64tass-mode-syntax-table)

  ;; ' is character quote
  (modify-syntax-entry ?' "/" 64tass-mode-syntax-table)

  ;;
  ;; compilation
  ;;

  ;; 64tass prints tidily-indented file names, and the default Emacs
  ;; compilation error regexps dutifully store off the spaces.
  (add-to-list 'compilation-error-regexp-alist
	       `(,(rx bol
		      (one-or-more space)
		      (group (+ (not (any ?\n ?:)))) ?:
		      (group (+ (any (?0 . ?9)))) ?:
		      (group (+ (any (?0 . ?9)))) (or ?: ?,)
		      eol)
		 1 2 3 0))
  
  ;;
  ;; imenu
  ;; 

  ;; The custom imenu function populates the alist with
  ;; fully-qualified names.
  (setq imenu-create-index-function '64tass--imenu-create-index)

  (setq dabbrev-case-replace nil)

  ;; 
  )

;; By analogy with the c-mode binding for `c-forward-conditional'
(define-key 64tass-mode-map (kbd "C-c C-n") '64tass-cycle-construct)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun 64tass-lst-revert-buffer ()
  (interactive)
  (revert-buffer t			;ignore auto-save file
		 t			;don't ask for confirmation
		 t))			;preserve file mode

(defun 64tass-lst--compilation-default-directory ()
  (let* ((compilation-buffer (get-buffer "*compilation*")))
    (unless compilation-buffer
      (error "No *compilation* buffer"))
    (with-current-buffer compilation-buffer
      default-directory)))

(defun 64tass-lst-visit-source ()
  (interactive)
  (save-excursion
    (beginning-of-line)
    (unless (looking-at (rx bol (group-n 1 (1+ digit))))
      (error "No line number found. Ensure code was built with --line-numbers"))
    (let* ((source-line (string-to-number (match-string 1)))
	   (search-result (re-search-backward
			   (rx (or "******  Processing file: "
				   "******  Return to file: ")
			       (group-n 1 (1+ any) eol))
			   nil		;no bounds
			   t)		;no error
			  ))
      (unless search-result
	(error "Source file info not found"))

      (let* ((source-file (match-string 1))
	     (full-source-file
	      (expand-file-name
	       source-file
	       (64tass-lst--compilation-default-directory))))
	(unless (file-exists-p full-source-file)
	  (error "File not found: %s" full-source-file))
	(find-file-other-window full-source-file)
	(goto-char (point-min))
	(forward-line (1- source-line))))))

(define-derived-mode
  64tass-lst-mode
  fundamental-mode
  "64tass-lst"
  "Mode for working with 64tass listing files."
  (interactive)

  ;; There's no particular editing support, and 64tass-lst-mode is
  ;; careless with any modification, on the basis that these files are
  ;; designed to be read rather than modified.
  
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(64tass-font-lock-keywords nil t))

  (make-local-variable '64tass-lst-default-directory)

  ;; 
  )


(define-key 64tass-lst-mode-map (kbd "C-c C-r") '64tass-lst-revert-buffer)
(define-key 64tass-lst-mode-map (kbd "C-c C-l") '64tass-lst-visit-source)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide '64tass-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
