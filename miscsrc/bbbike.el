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

(defvar bbbike-mode-map nil "Keymap for BBBike bbd mode.")
(if bbbike-mode-map
    nil
  (let ((map (make-sparse-keymap)))
    (setq bbbike-mode-map map)))

(defun bbbike-mode ()
  (interactive)
  (use-local-map bbbike-mode-map)
  (setq mode-name "BBBike"
	major-mode 'bbbike-mode)
  (run-hooks 'bbbike-mode-hook)
  )

(provide 'bbbike-mode)
