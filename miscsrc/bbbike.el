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
    (setq tab-width 72))
  (recenter)
  )

(defvar bbbike-mode-map nil "Keymap for BBBike bbd mode.")
(if bbbike-mode-map
    nil
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-r" 'bbbike-reverse-street)
    (define-key map "\C-c\C-s" 'bbbike-search-x-selection)
    (define-key map "\C-c\C-t" 'bbbike-toggle-tabular-view)
    (define-key map "\C-c\C-c" 'comment-region)
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
  ;;; XXX (setq font-lock-keywords-only t)
  (setq font-lock-keywords
	'(t
	  ("\t\\([^ ]+\\)" (1 font-lock-keyword-face))
	  ;("\\(#:\\)"  (1 font-lock-function-name-fact)) ;;; XXX does not work
	  ;("#.*" (0 font-lock-comment-face)) ;;; XXX does not work
	  ("^\\([^:\t]+\\)" (1 font-lock-constant-face))
	  ))
  (make-local-variable 'comment-use-syntax)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-padding)
  (setq comment-use-syntax nil)
  (setq comment-start "#")
  (setq comment-padding " ")
  )

(provide 'bbbike-mode)
