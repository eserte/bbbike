(setq bbbike-el-file-name load-file-name)

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

(defun bbbike-search-x-selection ()
  (interactive)
  (let* ((sel (x-selection))
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
  (make-local-variable 'font-lock-keywords-only)
  (setq font-lock-keywords-only t)
  (make-local-variable 'font-lock-keywords)
  (setq font-lock-keywords
	'(t
	  ("\\(#:.*\\)"  (1 font-lock-warning-face))	            ;; directives
	  ("^\\(#.*\\)" (1 font-lock-comment-face))                 ;; comments
	  ("^\\([^\t\n]+\\)" (1 font-lock-constant-face))           ;; name
	  ("^[^#][^\t\n:]+: \\([^\t\n]+\\)" (1 font-lock-string-face t)) ;; colon separated part of name
	  ("\t\\([^ \n]+\\)" (1 font-lock-keyword-face))            ;; category
	  ("\\([-+]?[0-9]+,[-+]?[0-9]+\\)" (1 font-lock-type-face)) ;; coords
	  ))
  (make-local-variable 'comment-use-syntax)
  (setq comment-use-syntax nil)
  (make-local-variable 'comment-start)
  (setq comment-start "#")
  (make-local-variable 'comment-padding)
  (setq comment-padding " ")
  )

(fset 'bbbike-cons25-format-answer
   "\C-[[H\C-sCc:\C-a\C-@\C-[[B\C-w\C-s--text\C-[[B\C-a\C-@\C-s\\$strname\C-u10\C-[[D\C-w\C-[[C\C-[[C\C-u11\C-d\C-a\C-s\"\C-[[D\C-@\C-e\C-r\"\C-[[C\C-u\370shell-command-on-region\C-mperl -e 'print eval <>'\C-m\C-e\C-?\C-[[B\C-a\C-@\C-[[F\C-r^--\C-[[A\C-w\C-[[A\C-[[B\C-m\C-[[H\C-ssubject.* by \C-@\C-s \C-[[D\C-[w\C-[[F\C-r^--\C-[[AHallo \C-y,\C-m\C-m\C-mGru\337,\C-m    Slaven\C-m\C-[[A\C-[[A\C-[[A")

(condition-case ()
    (load "recode")
  (error ""))
(fset 'bbbike-format-answer
   [home ?\C-s ?C ?c ?: ?\C-a ?\C-k ?\C-k ?\C-s ?- ?- ?t ?e ?x ?t down ?\C-a ?\C-  ?\C-s ?s ?t ?r ?n ?a ?m ?e ?\C-s right right right ?\C-w ?> ?  ?\C-s ?\" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a ?\C-e backspace down ?\C-a ?\C-  ?\C-s ?^ ?- ?- ?  up up ?\C-x ?\C-x ?\C-w return ?H ?a ?l ?l ?o ?  home ?\C-s ?S ?u ?b ?j ?e ?c ?t ?. ?* ?b ?y right ?\C-  ?\C-e escape ?w ?\C-s ?H ?a ?l ?l ?o right ?\C-y ?, return return ?d ?a ?n ?k ?e ?  ?f ?ü ?r ?  ?d ?e ?i ?n ?e ?n ?  ?E ?i ?n ?t ?r ?a ?g ?. ?  ?D ?i ?e ?  ?S ?t ?r ?a ?ß ?e ?  ?w ?i ?r ?d ?  ?d ?e ?m ?n ?ä ?c ?h ?s ?t ?  ?b ?e ?i ?  ?B ?B ?B ?i ?k ?e ?  ?v ?e ?r ?f ?ü ?g ?b ?a ?r ?  ?s ?e ?i ?n ?. return return ?G ?r ?u ?ß ?, return tab ?S ?l ?a ?v ?e ?n return])

;; (setq last-kbd-macro
;;    [?\C-s ?\" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a])


;; (setq last-kbd-macro
;;    [?\C-s ?" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a])

(provide 'bbbike-mode)
