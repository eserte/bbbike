;;; obsolete: fügt die Indices aus der aktuellen X-Selection in den Punkt ein
(defun inslauf ()
  (interactive)
  (let ((str (x-selection))
	(start 0)
	(out "")
	(loop t))
    (while loop
      (cond
       ((string-match "\\((-?[0-9]+,-?[0-9]+)\\|[0-9]+\\)\\s *$" str start)
	(let ((match (substring str (match-beginning 1) (match-end 1))))
	  (if (string= out "")
	      (setq out match)
	    (setq out (concat out " " match)))))
       (t (setq loop nil))
       )
      (setq start (match-end 1)))
    (insert out)))

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

;(global-set-key [f8] 'inslauf)
;(message "Press F8 for using inslauf!")
