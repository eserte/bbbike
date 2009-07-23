(setq bbbike-el-file-name load-file-name)

(defvar bbbike-font-lock-keywords
  '(("^\\(#[^:].*\\)" (1 font-lock-comment-face))                 ;; comments
    ("\\(#:.*\\)"  (1 font-lock-warning-face))	            ;; directives
    ("^\\([^\t\n]+\\)" (1 font-lock-constant-face))           ;; name
    ("^[^#][^\t\n:]+: \\([^\t\n]+\\)" (1 font-lock-string-face t)) ;; colon separated part of name
    ("\t\\([^ \n]+ \\)" (1 font-lock-keyword-face))            ;; category
    ("\\([-+]?[0-9.]+,[-+]?[0-9.]+\\)" (1 font-lock-type-face)) ;; coords
    ))

(defconst bbbike-font-lock-defaults
  '(bbbike-font-lock-keywords t nil nil nil (font-lock-multiline . nil)))
  
;;; reverses the current region
(defun bbbike-reverse-street ()
  (interactive)
  (let (reg tokens i)
    (setq reg (buffer-substring (region-beginning) (region-end)))
    (setq tokens (reverse (split-string reg)))
    (save-excursion
      (goto-char (region-end))
      (while tokens
	(insert (car tokens))
	(setq tokens (cdr tokens))
	(if tokens
	    (insert " "))
	)
      )
      (delete-region (region-beginning) (region-end))
    ))

(defun bbbike-split-street ()
  (interactive)
  (let (begin-line-pos end-name-cat-pos begin-coord-pos end-coord-pos name-cat coord)
    (save-excursion
      (beginning-of-line)
      (setq begin-line-pos (point)))
    (save-excursion
      (search-forward-regexp "\\($\\| \\)")
      (if (string= (buffer-substring (match-beginning 0) (match-end 0)) "")
	  (error "Cannot split at end"))
      (setq end-coord-pos (1- (match-end 0))))
    (save-excursion
      (search-backward-regexp " " begin-line-pos)
      (setq begin-coord-pos (1+ (match-beginning 0))))
    (setq coord (buffer-substring begin-coord-pos end-coord-pos))
    (save-excursion
      (beginning-of-line)
      (search-forward-regexp "\t[^ ]+ ")
      (setq end-name-cat-pos (match-end 0))
      (setq name-cat (buffer-substring begin-line-pos end-name-cat-pos)))
    (save-excursion
      (goto-char end-coord-pos)
      (insert "\n")
      (insert name-cat)
      (insert coord)
      )
    ))

(defun bbbike-join-street ()
  (interactive)
  (let (match-coord other-coord
	match-cat other-cat
	match-name other-name)
    (save-excursion
      (if (or (save-excursion (search-forward-regexp "\\=[^ ]+$" nil t)) ;; are we on the last coord of the line?
	      (save-excursion (search-forward-regexp "\\=$" nil t)))
	  (progn
	    (message (format "%s" (point)))
	    (beginning-of-line)
	    (if (not (search-forward-regexp "^\\([^\t]*\\)\t\\([^ ]+\\).* \\([^ ]+\\)$"))
	      (error "Cannot parse this line as valid bbd data line"))
	    (setq match-name (buffer-substring (match-beginning 1) (match-end 1)))
	    (setq match-cat (buffer-substring (match-beginning 2) (match-end 2)))
	    (setq match-coord (buffer-substring (match-beginning 3) (match-end 3)))
	    (end-of-line)
	    (goto-char (1+ (point)))
	    (if (= (point) (point-max))
		(error "We are one the last line"))
	    (if (string= (buffer-substring (point) (1+ (point))) "#")
		(error "Next line is a comment line, no join possible"))
	    (if (not (search-forward-regexp "^\\([^\t]*\\)\t\\([^ ]+\\) \\([^ ]+\\) "))
		(error "Next line does not look like a valid bbd data line or only has one coordinate at all"))
	    (setq other-name (buffer-substring (match-beginning 1) (match-end 1)))
	    (if (not (string= match-name other-name)) ;; XXX ask the user which one to choose!
		(error "Name on this line and name on next line do not match"))
	    (setq other-cat (buffer-substring (match-beginning 2) (match-end 2)))
	    (if (not (string= match-cat other-cat)) ;; XXX ask the user which one to choose!
		(error "Category on this line and category on next line do not match"))
	    (setq other-coord (buffer-substring (match-beginning 3) (match-end 3)))
	    (if (not (string= match-coord other-coord))
		(error "Last coordinate on this line and first coordinate on next line do not match"))
	    (delete-region (match-beginning 0) (match-end 0))  ;; XXX maybe replace name and/or cat if user chose the 2nd name/cat
	    (insert " ")
	    (delete-region (1- (1- (point))) (1- (point))))
	(error "no support for joining by first coordinate, must be on last coordinate")
	;; are we on the first coord of the line? no -> error message
	;;   is there a prev line, and non-comment? no -> error message
	;;   is the last coord of the prev line the same? no -> error message
	;;   is the category/name of the prev line the same? see above
	;;   delete name, cat and first coord of this line, join lines, maybe replace name and/or cat
	;;   ready!
	)
      )))

(defun bbbike-search-x-selection ()
  (interactive)
  (let* ((sel (if (fboundp 'w32-get-clipboard-data)
		  (w32-get-clipboard-data)
		(x-selection)))
	 (rx  sel))
    (if sel
	(let ((search-state 'begin)
	      (end-length)
	      (start-pos))
	  (if (string-match " " rx)
	      (progn
		(setq rev-rx-list (reverse (split-string rx " ")))
		(setq rev-rx (pop rev-rx-list))
		(while rev-rx-list
		  (setq rev-rx (concat rev-rx " " (pop rev-rx-list))))
		(setq rx (concat "\\(" rx "\\|" rev-rx "\\)"))
		)
	    (setq rx (concat "\\(" rx "\\)")))
	  (message rx)
	  (while (not (eq search-state 'found))
	    (if (eq search-state 'again)
		(goto-char (point-min)))
	    (if (not (search-forward-regexp (concat "\\(\t\\| \\)" rx "\\( \\|$\\)")
					    nil
					    (eq search-state 'begin)))
		(setq search-state 'again)
	      (setq search-state 'found)
	      (setq start-pos (- (point) (length sel)
				 (- (match-end 3) (match-beginning 3))
				 ))
	      (set-mark (+ start-pos (length sel)))
	      (goto-char start-pos)
	      )
	    ))
      (error "No X selection"))))

(defun bbbike-toggle-tabular-view ()
  (interactive)
  (if truncate-lines
      (progn
	(setq truncate-lines nil)
	(setq tab-width 8))
    (setq truncate-lines t)
    (setq tab-width 60))
  (recenter)
  )

(defun bbbike-center-point ()
  (interactive)
  (let (begin-coord-pos end-coord-pos)
    (save-excursion
      (search-forward-regexp "\\($\\| \\)")
      (if (string= (buffer-substring (match-beginning 0) (match-end 0)) "")
	  (setq end-coord-pos (match-end 0))
	(setq end-coord-pos (1- (match-end 0)))))
    (save-excursion
      (search-backward-regexp " ")
      (setq begin-coord-pos (1+ (match-beginning 0))))
    (setq coord (buffer-substring begin-coord-pos end-coord-pos))
    (string-match "^\\(.*\\)/[^/]+/[^/]+$" bbbike-el-file-name)
    (setq bbbikeclient-path (concat (substring bbbike-el-file-name (match-beginning 1) (match-end 1))
				    "/bbbikeclient"))
    (setq bbbikeclient-command (concat bbbikeclient-path
				       "  -centerc "
				       coord
				       " &"))
    (message bbbikeclient-command)
    (shell-command bbbikeclient-command nil nil)
    ))

(defvar bbbike-mode-map nil "Keymap for BBBike bbd mode.")
(if bbbike-mode-map
    nil
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-r" 'bbbike-reverse-street)
    (define-key map "\C-c\C-s" 'bbbike-search-x-selection)
    (define-key map "\C-c\C-t" 'bbbike-toggle-tabular-view)
    (define-key map "\C-c\C-c" 'comment-region)
    (define-key map "\C-c|"    'bbbike-split-street)
    (define-key map "\C-c\C-j" 'bbbike-join-street)
    (define-key map "\C-cj"    'bbbike-join-street)
    (setq bbbike-mode-map map)))

(defvar bbbike-syntax-table nil "Syntax table for BBBike bbd mode.")
(if bbbike-syntax-table
    nil
  (setq bbbike-syntax-table (make-syntax-table))
  (modify-syntax-entry ?#  "<" bbbike-syntax-table)
  (modify-syntax-entry ?\n ">" bbbike-syntax-table)
  (modify-syntax-entry ?\" "." bbbike-syntax-table)
  )

(defun bbbike-mode ()
  (interactive)
  (use-local-map bbbike-mode-map)
  (setq mode-name "BBBike"
	major-mode 'bbbike-mode)
  (set-syntax-table bbbike-syntax-table)
  (run-hooks 'bbbike-mode-hook)

  (if (string-match "^2[01]\\." emacs-version)
      (progn
	(set (make-local-variable 'font-lock-keyword-only) t)
	(set (make-local-variable 'font-lock-keywords) bbbike-font-lock-keywords))
    (set (make-local-variable 'font-lock-defaults) bbbike-font-lock-defaults)
    (set (make-local-variable 'comment-use-syntax) nil)
    (set (make-local-variable 'comment-start) "#")
    (set (make-local-variable 'comment-padding) " "))

  (setq bbbike-imenu-generic-expression '((nil "^#: \\(append_comment\\|section\\):? *\\(.*\\) +vvv+" 2)))
  (setq imenu-generic-expression bbbike-imenu-generic-expression)

  ;; Do not let emacs asking if another process (i.e. bbbike itself) changed
  ;; a bbd file:
  (make-local-variable 'revert-without-query)
  (setq revert-without-query (list (buffer-file-name)))

  (bbbike-set-grep-command)

  ;; In emacs 22, tab is something else
  (local-set-key "\t" 'self-insert-command)
  )

(defun bbbike-set-grep-command ()
  (set (make-local-variable 'grep-command)
       (if (not is-windowsnt)
	   (concat (if (string-match "csh" (getenv "SHELL"))
		       "" "2>/dev/null ")
		   "grep -ins *-orig *.coords.data -e ")
	 "grep -ni ")))

(fset 'bbbike-cons25-format-answer
   "\C-[[H\C-sCc:\C-a\C-@\C-[[B\C-w\C-s--text\C-[[B\C-a\C-@\C-s\\$strname\C-u10\C-[[D\C-w\C-[[C\C-[[C\C-u11\C-d\C-a\C-s\"\C-[[D\C-@\C-e\C-r\"\C-[[C\C-u\370shell-command-on-region\C-mperl -e 'print eval <>'\C-m\C-e\C-?\C-[[B\C-a\C-@\C-[[F\C-r^--\C-[[A\C-w\C-[[A\C-[[B\C-m\C-[[H\C-ssubject.* by \C-@\C-s \C-[[D\C-[w\C-[[F\C-r^--\C-[[AHallo \C-y,\C-m\C-m\C-mGru\337,\C-m    Slaven\C-m\C-[[A\C-[[A\C-[[A")

(condition-case ()
    (load "recode")
  (error ""))
(fset 'bbbike-format-answer
   [home ?\C-s ?C ?c ?: ?\C-a ?\C-k ?\C-k ?\C-s ?- ?- ?t ?e ?x ?t down ?\C-a ?\C-  ?\C-s ?s ?t ?r ?n ?a ?m ?e ?\C-s right right right ?\C-w ?> ?  ?\C-s ?\" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a ?\C-e backspace down ?\C-a ?\C-  ?\C-s ?^ ?- ?- ?  up up ?\C-x ?\C-x ?\C-w return ?H ?a ?l ?l ?o ?  home ?\C-s ?S ?u ?b ?j ?e ?c ?t ?. ?* ?b ?y right ?\C-  ?\C-e escape ?w ?\C-s ?H ?a ?l ?l ?o right ?\C-y ?, return return ?d ?a ?n ?k ?e ?  ?f ?ü ?r ?  ?d ?e ?i ?n ?e ?n ?  ?E ?i ?n ?t ?r ?a ?g ?. ?  ?D ?i ?e ?  ?S ?t ?r ?a ?ß ?e ?  ?w ?i ?r ?d ?  ?d ?e ?m ?n ?ä ?c ?h ?s ?t ?  ?b ?e ?i ?  ?B ?B ?B ?i ?k ?e ?  ?v ?e ?r ?f ?ü ?g ?b ?a ?r ?  ?s ?e ?i ?n ?. return return ?G ?r ?u ?ß ?, return tab ?S ?l ?a ?v ?e ?n return])

(defun gpsman-wpt-remove-irrelevant ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (delete-matching-lines "symbol=summit")
    (delete-matching-lines "symbol=geocache")))

;; (setq last-kbd-macro
;;    [?\C-s ?\" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a])


;; (setq last-kbd-macro
;;    [?\C-s ?" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a])

(defun bbbike-google-map ()
  "Open a browse with my googlemap implementation for the coordinates under cursor"
  (interactive)
  (let ((coords (buffer-substring (region-beginning) (region-end))))
    (setq coords (replace-regexp-in-string " " "!" coords))
    (browse-url (concat "http://bbbike.de/cgi-bin/bbbikegooglemap.cgi?coords=" coords)))
  )

(defun bbbike-now ()
  "Insert the current date in bbbike-temp-blockings.pl"
  (interactive)
  (let ((now (format "%s" (float-time))))
    (if (not (string-match "^\\([0-9]+\\)" now) )
	(error (concat "cannot match " now)))
    (setq now (substring now (match-beginning 1) (match-end 1)))
    (insert now)
    ))

(provide 'bbbike-mode)
