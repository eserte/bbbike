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
  (let ((sel (x-selection)))
    (if sel
	(progn
	  (goto-char (point-min))
	  (search-forward-regexp (concat "\\(\t\\| \\)" sel "\\( \\|$\\)"))
	  (goto-char (- (point) (length sel))))
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
