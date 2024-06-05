;;; bbbike.el --- editing BBBike .bbd files in GNU Emacs

;; Copyright (C) 1997-2014,2016-2024 Slaven Rezic

;; To use this major mode, put something like:
;;
;;     (setq auto-mode-alist (append (list (cons "\\(-orig\\|\\.bbd\\)$" 'bbbike-mode))
;;     		                     auto-mode-alist))
;;
;; to your .emacs file

(setq bbbike-el-file-name load-file-name)

(defvar bbbike-view-url-prefer-cached nil "If set to t then prefer showing the cached version in bbbike-view-url. Use bbbike-toggle-view-url to toggle the value.")

(defvar bbbike-font-lock-trailing-whitespace-face 'bbbike-font-lock-trailing-whitespace-face
  "Face name to use for highlightning trailing whitespace.")
(defface bbbike-font-lock-trailing-whitespace-face
  '((((class color) (min-colors 88)) (:foreground "Red1" :weight bold :underline t))
    (((class color) (min-colors 16)) (:foreground "Red1" :weight bold :underline t))
    (((class color) (min-colors 8)) (:foreground "red" :underline t))
    (t (:underline t)))
  "Font Lock mode face used to highlight trailing whitespace."
  :group 'font-lock-faces)
(defface bbbike-button
  '((t (:underline t)))
  "Face for buttons without changing foreground color")
(defface bbbike-button-strike
  '((t (:underline t :strike-through t)))
  "Face for sort-of inactive buttons without changing foreground color")
;; for this button face the mouseover background color needs to be adapted
(copy-face 'bbbike-button-strike 'bbbike-button-strike-hover)
(set-face-attribute 'bbbike-button-strike-hover nil :background "#b4eeb4")

(defvar bbbike-font-lock-keywords
  '(("\\( +\\)\t" (1 bbbike-font-lock-trailing-whitespace-face)) ;; trailing whitespace after names. works only partially, but at least it disturbs the fontification
    ("^\\(#[^:].*\\)" (1 font-lock-comment-face))                 ;; comments
    ("\\(#:.*\\)"  (1 font-lock-warning-face))	            ;; directives
    ("^\\([^\t\n]+\\)" (1 font-lock-constant-face))           ;; name
    ("^[^#][^\t\n:]+: \\([^\t\n]+\\)" (1 font-lock-string-face t)) ;; colon separated part of name
    ("\t\\([^ \n]+ \\)" (1 font-lock-keyword-face))            ;; category
    ("\\([-+]?[0-9.]+,[-+]?[0-9.]+\\)" (1 font-lock-type-face)) ;; coords
    ))

(defvar bbbike-date-for-last-checked)
(defvar bbbike-addition-for-last-checked "")

(setq bbbike-sourceid-viz-format "https://viz.berlin.de/2?p_p_id=vizmap_WAR_vizmapportlet_INSTANCE_Ds4N&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_cmd=traffic&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_submenu=traffic_default&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_poiId=News_id_%s&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_poiCoordX=%f&_vizmap_WAR_vizmapportlet_INSTANCE_Ds4N_poiCoordY=%f")

(setq bbbike-viz2021-regexp "viz2021:[0-9.,:]+")

(defvar bbbike-mc-traffic-base-url "https://mc.bbbike.org/mc/?profile=traffic&zoom=15&") ; add "lat=52.518117&lon=13.498035" for a complete URL

(setq bbbike-perl-modern-executable (if (boundp 'perl-modern-executable) perl-modern-executable "perl"))

(defconst bbbike-font-lock-defaults
  '(bbbike-font-lock-keywords t nil nil nil (font-lock-multiline . nil)))

;; using auto-revert-mode
;(defadvice switch-to-buffer (after bbbike-revert last act)
;  "Make sure bbbike buffers are up-to-date"
;  (when (and (eq major-mode 'bbbike-mode)
;	     (not (buffer-modified-p)))
;    (let ((last-modified (nth 5 (file-attributes (buffer-file-name)))))
;      (when (time-less-p bbbike-mode-load-time last-modified)
;        (revert-buffer)))))

;;; reverses the current region
(defun bbbike-reverse-street ()
  (interactive)
  (let (reg tokens i)
    (setq reg (buffer-substring-no-properties (region-beginning) (region-end)))
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
      (if (string= (buffer-substring-no-properties (match-beginning 0) (match-end 0)) "")
	  (error "Cannot split at end"))
      (setq end-coord-pos (1- (match-end 0))))
    (save-excursion
      (search-backward-regexp " " begin-line-pos)
      (setq begin-coord-pos (1+ (match-beginning 0))))
    (setq coord (buffer-substring-no-properties begin-coord-pos end-coord-pos))
    (save-excursion
      (beginning-of-line)
      (search-forward-regexp "\t[^ ]+ ")
      (setq end-name-cat-pos (match-end 0))
      (setq name-cat (buffer-substring-no-properties begin-line-pos end-name-cat-pos)))
    (save-excursion
      (goto-char end-coord-pos)
      (insert "\n")
      (insert name-cat)
      (insert coord)
      )
    ))

(defun bbbike-split-directions ()
  (interactive)
  (shell-command-on-region (save-excursion (beginning-of-line) (point))
			   (save-excursion (end-of-line) (point))
			   "perl -e '$in=<>; if (($name,$catfw,$catbw,$coord)=$in=~m{^([^\\t]*)\\t([^;]*);([^ ]*) (.*)}) { print qq{$name\\t$catfw; $coord\\n$name\\t$catbw; } . join(qq{ },reverse(split / /, $coord)) } else { print $in }'"
			   nil t)
  )

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
	    (setq match-name (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
	    (setq match-cat (buffer-substring-no-properties (match-beginning 2) (match-end 2)))
	    (setq match-coord (buffer-substring-no-properties (match-beginning 3) (match-end 3)))
	    (end-of-line)
	    (goto-char (1+ (point)))
	    (if (= (point) (point-max))
		(error "We are one the last line"))
	    (if (string= (buffer-substring-no-properties (point) (1+ (point))) "#")
		(error "Next line is a comment line, no join possible"))
	    (if (not (search-forward-regexp "^\\([^\t]*\\)\t\\([^ ]+\\) \\([^ ]+\\) "))
		(error "Next line does not look like a valid bbd data line or only has one coordinate at all"))
	    (setq other-name (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
	    (if (not (string= match-name other-name)) ;; XXX ask the user which one to choose!
		(error "Name on this line and name on next line do not match"))
	    (setq other-cat (buffer-substring-no-properties (match-beginning 2) (match-end 2)))
	    (if (not (string= match-cat other-cat)) ;; XXX ask the user which one to choose!
		(error "Category on this line and category on next line do not match"))
	    (setq other-coord (buffer-substring-no-properties (match-beginning 3) (match-end 3)))
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
  (let ((sel (bbbike--get-x-selection)))
    (if sel
	(let ((rx sel)
	      is-coords)
	  (if (string-match "^\\(CHANGED\\|NEW\\|REMOVED\\)\t.*\t\\([^\t]+\\)\t\\(INUSE\\)?$" rx)
	      (setq rx (concat "#:[ ]*source_id:?[ ]*" (substring rx (match-beginning 2) (match-end 2))))
	    (if (string-match " " rx)
		(progn
		  (setq rev-rx-list (reverse (split-string rx " ")))
		  (setq rev-rx (pop rev-rx-list))
		  (while rev-rx-list
		    (setq rev-rx (concat rev-rx " " (pop rev-rx-list))))
		  (setq rx (concat "\\(" rx "\\|" rev-rx "\\)"))
		  )
	      (setq rx (concat "\\(" rx "\\)")))
	    (setq rx (concat "\\(\t\\| \\)" rx "\\( \\|$\\)"))
	    (setq is-coords t)
	    )
	  (message rx)

	  (let ((search-state 'begin)
		(end-length)
		(start-pos))
	    (while (not (eq search-state 'found))
	      (if (eq search-state 'again)
		  (goto-char (point-min)))
	      (if (not (search-forward-regexp rx
					      nil
					      (eq search-state 'begin)))
		  (setq search-state 'again)
		(setq search-state 'found)
		(if is-coords
		    (progn
		      (setq start-pos (- (point) (length sel)
					 (- (match-end 3) (match-beginning 3))
					 ))
		      (set-mark (+ start-pos (length sel)))
		      (goto-char start-pos)))
		)
	      )))
      (error "No X selection"))))

(defun bbbike--get-x-selection ()
  (cond
   ((fboundp 'w32-get-clipboard-data) (w32-get-clipboard-data))
   ((eq system-type 'darwin) (shell-command-to-string "pbpaste"))
   ((fboundp 'x-get-selection)
    (let ((value (x-get-selection nil 'UTF8_STRING)))
      (if (not value) ; seen with xpdf selections, only STRING is available (but utf-8 text is wrong)
	  (setq value (x-get-selection nil 'STRING)))
      value))
   (t (x-selection nil 'UTF8_STRING))))

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
      (if (string= (buffer-substring-no-properties (match-beginning 0) (match-end 0)) "")
	  (setq end-coord-pos (match-end 0))
	(setq end-coord-pos (1- (match-end 0)))))
    (save-excursion
      (search-backward-regexp " ")
      (setq begin-coord-pos (1+ (match-beginning 0))))
    (setq coord (buffer-substring-no-properties begin-coord-pos end-coord-pos))
    (setq bbbikeclient-path (concat (bbbike-rootdir) "/bbbikeclient"))
    (setq bbbikeclient-command (concat bbbikeclient-path
				       "  -centerc "
				       coord
				       " &"))
    (message bbbikeclient-command)
    (shell-command bbbikeclient-command nil nil)
    ))

(defun bbbike-rootdir ()
  (string-match "^\\(.*\\)/[^/]+/[^/]+$" bbbike-el-file-name)
  (substring bbbike-el-file-name (match-beginning 1) (match-end 1))
  )

(defun bbbike-datadir ()
  (concat (bbbike-rootdir) "/data"))

(defun bbbike-aux-rootdir ()
  (concat (bbbike-rootdir) "-aux"))

(defun bbbike-aux-bbddir ()
  (concat (bbbike-aux-rootdir) "/bbd"))


(defvar bbbike-mode-map nil "Keymap for BBBike bbd mode.")
(if bbbike-mode-map
    nil
  (let ((map (make-sparse-keymap))
	(menu-map (make-sparse-keymap "BBBike")))
    (define-key map "\C-c\C-r" 'bbbike-reverse-street)
    (define-key map "\C-c\C-s" 'bbbike-search-x-selection)
    (define-key map "\C-c\C-t" 'bbbike-toggle-tabular-view)
    (define-key map "\C-c\C-c" 'comment-region)
    (define-key map "\C-c|"    'bbbike-split-street)
    (define-key map "\C-c\C-j" 'bbbike-join-street)
    (define-key map "\C-cj"    'bbbike-join-street)
    (define-key map "\C-c."    'bbbike-update-now)
    (define-key map "\C-c\C-l" 'bbbike-update-last-checked)
    (define-key map "\C-c\C-m" 'bbbike-center-point)
    ; menu
    (if (fboundp 'bindings--define-key)
	(progn
	  (bindings--define-key map [menu-bar bbbike] (cons "BBBike" menu-map))
	  (bindings--define-key menu-map [leaflet-map]         '(menu-item "Show on Leaflet Map" bbbike-leaflet-map))
	  (bindings--define-key menu-map [center-point]        '(menu-item "Show on BBBike" bbbike-center-point))
	  (bindings--define-key menu-map [toggle-tabular-view] '(menu-item "Toggle Tabular View" bbbike-toggle-tabular-view))
	  (bindings--define-key menu-map [search-x-selection]  '(menu-item "Search X Selection" bbbike-search-x-selection))
	  (bindings--define-key menu-map [grep]                '(menu-item "Grep" bbbike-grep-with-search-term))
	  (bindings--define-key menu-map [separator3]          menu-bar-separator)
	  (bindings--define-key menu-map [toggle-view-url]     '(menu-item "Toggle View URL behavior" bbbike-toggle-view-url))
	  (bindings--define-key menu-map [view-remote-url]     '(menu-item "View Remote URL" bbbike-view-remote-url))
	  (bindings--define-key menu-map [view-cached-url]     '(menu-item "View Cached URL" bbbike-view-cached-url))
	  (bindings--define-key menu-map [separator2]          menu-bar-separator)
	  (bindings--define-key menu-map [update-now]          '(menu-item "Update Now Timestamp (directive)" bbbike-update-now))
	  (bindings--define-key menu-map [now]                 '(menu-item "Insert Now Timestamp (temp-blockings)" bbbike-now))
	  (bindings--define-key menu-map [join-street]         '(menu-item "Join Street" bbbike-join-street))
	  (bindings--define-key menu-map [split-directions]    '(menu-item "Split Directions" bbbike-split-directions))
	  (bindings--define-key menu-map [split-street]        '(menu-item "Split Street" bbbike-split-street))
	  (bindings--define-key menu-map [reverse-street]      '(menu-item "Reverse Street" bbbike-reverse-street))
	  (bindings--define-key menu-map [update-last-checked] '(menu-item "Update last_checked" bbbike-update-last-checked))
	  ;(bindings--define-key menu-map [last-checked-unset]     ' (menu-item "... unset" bbbike-last-checked-unset-addition))
	  ;(bindings--define-key menu-map [last-checked-mapillary] ' (menu-item "... with mapillary" bbbike-last-checked-add-mapillary))
	  ;(bindings--define-key menu-map [set-last-checked]    '(menu-item "Set last_checked date" bbbike-set-date-for-last-checked))
	  (bindings--define-key menu-map [set-last-checked-mapillary] '(menu-item "Set last_checked date (mapillary)" bbbike-set-date-for-last-checked-mapillary))
	  (bindings--define-key menu-map [set-last-checked-unset]     '(menu-item "Set last_checked date (unset)" bbbike-set-date-for-last-checked-unset))
	  (bindings--define-key menu-map [separator1]          menu-bar-separator)
	  (bindings--define-key menu-map [insert-source-id]    '(menu-item "Insert source_id" bbbike-insert-source-id))
	  (bindings--define-key menu-map [update-osm-watch]    '(menu-item "Update osm_watch" bbbike-update-osm-watch))
	  (bindings--define-key menu-map [insert-osm-watch]    '(menu-item "Insert osm_watch" bbbike-insert-osm-watch))
	  ))
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
  (kill-all-local-variables)
  (use-local-map bbbike-mode-map)
  (setq mode-name "BBBike"
	major-mode 'bbbike-mode)
  (set-syntax-table bbbike-syntax-table)

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

  (bbbike-create-buttons)

  (setq-local bbbike-mode-load-time (current-time)) ; not really necessary since using auto-revert-mode
  (auto-revert-mode 1)

  (autoload 'org-read-date "org" "Read an Org date." t)

  (run-hooks 'bbbike-mode-hook)
  )

(defun bbbike-imenu-setup ()
  "Setup imenu for bbbike mode."
  (setq imenu-generic-expression
        '((nil "^#:[ ]+section:?[ ]+\\(.*?\\)[ ]+vvv+[ ]*$" 1))))

(add-hook 'bbbike-mode-hook 'bbbike-imenu-setup)
(add-hook 'bbbike-mode-hook 'imenu-add-menubar-index)

(defun bbbike-set-grep-command ()
  (set (make-local-variable 'grep-command)
       (let ((is-windowsnt (and (or (string-match "i386-.*-windows.*" system-configuration)
				    (string-match "i386-.*-nt" system-configuration))
				t)))
	 (if (not is-windowsnt)
	     (concat (if (string-match "csh" (getenv "SHELL"))
			 "" "2>/dev/null ")
		     "grep -ins *-orig *.coords.data -e ")
	   "grep -ni "))))

(fset 'bbbike-cons25-format-answer
   "\C-[[H\C-sCc:\C-a\C-@\C-[[B\C-w\C-s--text\C-[[B\C-a\C-@\C-s\\$strname\C-u10\C-[[D\C-w\C-[[C\C-[[C\C-u11\C-d\C-a\C-s\"\C-[[D\C-@\C-e\C-r\"\C-[[C\C-u\370shell-command-on-region\C-mperl -e 'print eval <>'\C-m\C-e\C-?\C-[[B\C-a\C-@\C-[[F\C-r^--\C-[[A\C-w\C-[[A\C-[[B\C-m\C-[[H\C-ssubject.* by \C-@\C-s \C-[[D\C-[w\C-[[F\C-r^--\C-[[AHallo \C-y,\C-m\C-m\C-mGru\337,\C-m    Slaven\C-m\C-[[A\C-[[A\C-[[A")

(condition-case ()
    (load "recode")
  (error ""))
(fset 'bbbike-format-answer
   [home ?\C-s ?C ?c ?: ?\C-a ?\C-k ?\C-k ?\C-s ?- ?- ?t ?e ?x ?t down ?\C-a ?\C-  ?\C-s ?s ?t ?r ?n ?a ?m ?e ?\C-s right right right ?\C-w ?> ?  ?\C-s ?\" left ?\C-  ?\C-s ?\C-s ?\C-s ?\M-x ?r ?e ?c ?o ?d ?e ?- ?p ?e ?r ?l ?s ?t ?r ?i ?n ?g ?- ?t ?o ?- ?l ?a ?t ?i ?n ?1 return ?\C-a ?\C-e backspace down ?\C-a ?\C-  ?\C-s ?^ ?- ?- ?  up up ?\C-x ?\C-x ?\C-w return ?H ?a ?l ?l ?o ?  home ?\C-s ?S ?u ?b ?j ?e ?c ?t ?. ?* ?b ?y right ?\C-  ?\C-e escape ?w ?\C-s ?H ?a ?l ?l ?o right ?\C-y ?, return return ?d ?a ?n ?k ?e ?  ?f ?� ?r ?  ?d ?e ?i ?n ?e ?n ?  ?E ?i ?n ?t ?r ?a ?g ?. ?  ?D ?i ?e ?  ?S ?t ?r ?a ?� ?e ?  ?w ?i ?r ?d ?  ?d ?e ?m ?n ?� ?c ?h ?s ?t ?  ?b ?e ?i ?  ?B ?B ?B ?i ?k ?e ?  ?v ?e ?r ?f ?� ?g ?b ?a ?r ?  ?s ?e ?i ?n ?. return return ?G ?r ?u ?� ?, return tab ?S ?l ?a ?v ?e ?n return])

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

(setq bbbike-bbd-data-line-regexp "^.*\t[^ ]+ \\(-?[0-9].*\\)")

(defun bbbike-leaflet-map ()
  "Open a browser with the bbbike leaflet implementation for the coordinates under cursor"
  (interactive)
  (let (coords)
    (cond
     ((region-active-p)
      (setq coords (buffer-substring-no-properties (region-beginning) (region-end))))
     ((save-excursion
	(beginning-of-line)
	(looking-at bbbike-bbd-data-line-regexp))
      (setq coords (buffer-substring-no-properties (match-beginning 1) (match-end 1))))
     (t
      (error "Neither region selected nor cursor on a bbd data line")))
    (setq coords (replace-regexp-in-string " " "!" coords))
    (browse-url (concat "http://bbbike.de/cgi-bin/bbbikeleaflet.cgi?coords=" coords)))
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

(defun bbbike-update-now ()
  "Update the current date in bbd files (e.g. in last_checked directives)"
  (interactive)
  (let ((now-iso-date (format-time-string "%Y-%m-%d" (current-time)))
	begin-iso-date-pos
	end-iso-date-pos
	(currpos (point)))
    (save-excursion
      (search-backward-regexp "\\(^\\| \\)")
      (setq begin-iso-date-pos (1+ (match-beginning 0)))
      )
    (save-excursion
      (search-forward-regexp "\\( \\|$\\)")
      (setq end-iso-date-pos (match-beginning 0)))
    (if (not (string-match "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$" (buffer-substring-no-properties begin-iso-date-pos end-iso-date-pos)))
	(error (concat "This does not look like an ISO date "
		       (buffer-substring-no-properties begin-iso-date-pos end-iso-date-pos))))
    (save-excursion
      (goto-char begin-iso-date-pos)
      (delete-region begin-iso-date-pos end-iso-date-pos)
      (insert now-iso-date))

    (goto-char currpos) ; this works because the length of a ISO date is constant (at least for a long time ;-)
    )
  )

(defun bbbike-set-date-for-last-checked ()
  (interactive)
  (setq bbbike-date-for-last-checked (org-read-date)))

;(defun bbbike-last-checked-add-mapillary ()
;  (interactive)
;  (setq bbbike-addition-for-last-checked " (mapillary)"))
;
;(defun bbbike-last-checked-unset-addition ()
;  (interactive)
;  (setq bbbike-addition-for-last-checked ""))

(defun bbbike-set-date-for-last-checked-mapillary ()
  (interactive)
  (setq bbbike-addition-for-last-checked " (mapillary)")
  (bbbike-set-date-for-last-checked))

(defun bbbike-set-date-for-last-checked-unset ()
  (interactive)
  (setq bbbike-addition-for-last-checked "")
  (bbbike-set-date-for-last-checked))

(defun bbbike-set-date-for-last-checked-any ()
  (interactive)
  (let* ((command `("perl" "-nle"
		    "BEGIN { binmode STDOUT, qq{:encoding(utf-8)} } /^#:\\s+last_checked:.*?\\((.*?)\\)/ and $by{$1}++; END { my $i = 0; for my $by (sort { $by{$b}<=>$by{$a} } keys %by) { last if $i++>20; print $by } }"
		    ,@(directory-files (bbbike-datadir) t ".*-orig$")))
	 (process-coding-system-alist (cons '("perl" utf-8 . utf-8) process-coding-system-alist))
	 (completions (split-string
		       (with-output-to-string
			 (apply #'call-process (car command) nil standard-output
				nil (cdr command)))
		       "\n" t)))
    (setq bbbike-addition-for-last-checked (concat " (" (completing-read "Choose last-modified appendix: " completions) ")")))
  (bbbike-set-date-for-last-checked))

(defun bbbike-update-last-checked ()
  (interactive)
  (if (not bbbike-date-for-last-checked)
      (error "Please run bbbike-set-date-for-last-checked first"))
  (let (begin-line-pos end-line-pos is-block)
    (save-excursion
      (beginning-of-line)
      (if (not (looking-at "#: *last_checked"))
	  (error "Current line is not a line with a last_checked directive"))
      (setq begin-line-pos (point)))
    (save-excursion
      (end-of-line)
      (setq end-line-pos (point))
      (beginning-of-line)
      (if (search-forward-regexp "vvv *$" end-line-pos t)
	  (setq is-block t))
      )
    (save-excursion
      (delete-region begin-line-pos end-line-pos)
      (insert (concat "#: last_checked: " bbbike-date-for-last-checked bbbike-addition-for-last-checked (if is-block " vvv")))))
  )

(defun bbbike-view-cached-url (&optional url)
  "View the URL under cursor, assuming it's cached in bbbike-aux"
  (interactive)
  (if (not url)
      (setq url (bbbike--get-url-under-cursor)))
  (call-process-shell-command (concat (bbbike-aux-rootdir) "/downloads/view -show-best '" url "'") nil 0))

(defun bbbike-view-remote-url (&optional url)
  "View the URL under cursor remotely"
  (interactive)
  (if (not url)
      (setq url (bbbike--get-url-under-cursor)))
  (browse-url url))

;;; View URL either from cache or remote.
;;; Some URLs are always viewed remote.
;;; Otherwise the value of bbbike-view-url-prefer-cached is
;;; used. This variable is per default set to nil which means:
;;; prefer remote viewing. This variable may be toggled using
;;; bbbike-toggle-view-url.
(defun bbbike-view-url (url)
  "View the URL under cursor, either the cached version (preferred), or the remote version"
  (interactive)
  (if (null url)
      (setq url (bbbike--get-url-under-cursor)))
  (if (or (and bbbike-view-url-prefer-cached
	       (not (string-match "^http://www.dafmap.de/" url)) ; depends on additional non-cached javascript files, cached version is not usable
	       )
	  (string-match "/___tmp/tmp/" url) ; temporary berlin.de URLs, usually only valid for a few minutes
	  )
      (bbbike-view-cached-url url)
    (bbbike-view-remote-url url)))

(defun bbbike-toggle-view-url ()
  "Toggle between remote and cache URL viewing"
  (interactive)
  (setq bbbike-view-url-prefer-cached (not bbbike-view-url-prefer-cached)))

(defun bbbike--get-url-under-cursor ()
  (let (begin-current-line-pos end-current-line-pos current-line)
    (save-excursion
      (search-backward-regexp "\\(^\\| \\)")
      (setq begin-current-line-pos (1+ (match-beginning 0))))
    (save-excursion
      (search-forward-regexp "\\( \\|$\\)")
      (setq end-current-line-pos (match-beginning 0)))
    (setq current-line (buffer-substring-no-properties begin-current-line-pos end-current-line-pos))
    (if (not (string-match "\\(https?://[^ ]+\\)" current-line))
	(error (concat "This does not look like a http/https URL "
		       (buffer-substring-no-properties begin-url-pos end-url-pos))))
    (substring current-line (match-beginning 1) (match-end 1))))

;;; Basic idea: run in the shell
;;;
;;;     miscsrc/check-osm-watch-list.pl -diff
;;;
;;; and mark the lines prefixed with "CHANGED" into  the
;;; x11/ui selection. Then run in emacs
;;;
;;;     M-x bbbike-update-osm-watch
;;;
;;; to find the matching osm watches in bbbike data.
(defun bbbike-update-osm-watch ()
  (interactive)
  (let ((sel (bbbike--get-x-selection))
	(tempbuf "*bbbike update osm watch*")
	elemversion
	grep-pattern
	is-osm-note
	)
    (cond ((string-match "\\+<\\(way\\|node\\|relation\\).* id=\"\\([0-9]+\\)\".* version=\"\\([0-9]+\\)\"" sel)
	   (let* ((elemtype (substring sel (match-beginning 1) (match-end 1)))
		  (elemid (substring sel (match-beginning 2) (match-end 2))))
	     (setq elemversion (substring sel (match-beginning 3) (match-end 3)))
	     (setq grep-pattern (concat "^#: osm_watch: " elemtype " id=\"" elemid "\""))))
	  ((string-match "CHANGED: \\(way\\|node\\|relation\\)/\\([0-9]+\\) (version [0-9]+ -> \\([0-9]+\\))" sel)
	   (let* ((elemtype (substring sel (match-beginning 1) (match-end 1)))
		  (elemid (substring sel (match-beginning 2) (match-end 2))))
	     (setq elemversion (substring sel (match-beginning 3) (match-end 3)))
	     (setq grep-pattern (concat "^#: osm_watch: " elemtype " id=\"" elemid "\""))))
	  ((string-match "CHANGED: note .*/note/\\([0-9]+\\): number of comments changed (now \\([0-9]+\\)" sel)
	   (let* ((elemtype "note")
		  (elemid (substring sel (match-beginning 1) (match-end 1))))
	     (setq elemversion (substring sel (match-beginning 2) (match-end 2)))
	     (setq grep-pattern (concat "^#: osm_watch: note " elemid " "))
	     (setq is-osm-note t)))
	  (t (error "No X selection or X selection does not contain a way/node/relation line")))
    (let* ((bbbike-datadir (bbbike-datadir))
	   (fragezeichen-lowprio (concat (bbbike-aux-bbddir) "/fragezeichen_lowprio.bbd"))
	   (grepcmd (concat "cd " bbbike-datadir " && grep -ns '" grep-pattern "' "
			    "*-orig "
			    "temp_blockings/bbbike-temp-blockings.pl"
			    (if (file-exists-p fragezeichen-lowprio) (concat " " fragezeichen-lowprio))
			    )))
      (condition-case nil
	  (kill-buffer tempbuf)
	(error ""))
      (if (> (call-process "/bin/sh" nil tempbuf nil "-c" grepcmd) 0)
	  (error "Command %s failed" grepcmd)
	(set-buffer tempbuf)
	(goto-char (point-min))
	(if (not (search-forward-regexp "^\\([^:]+\\):\\([0-9]+\\)"))
	    (error "Strange: can't find a grep result in " tempbuf)
	  (let ((file (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
		(line (string-to-int (buffer-substring-no-properties (match-beginning 2) (match-end 2)))))
	    (find-file (concat (if (not (file-name-absolute-p file)) (concat bbbike-datadir "/")) file))
	    (goto-line line)
	    (if (not (search-forward-regexp "\\(version=\"\\|note [0-9]+ \\)" (line-end-position)))
		(error "Cannot find osm watch item in file")
	      (let ((answer (read-char (format "Set version to %s? (y/n) " elemversion))))
		(if (not (string= (char-to-string answer) "y"))
		    (error "OK, won't change version")
		  (let ((beg-of-version (point))
			(end-of-version (if is-osm-note
					    (line-end-position)
					  (save-excursion
					    (search-forward-regexp "[^0-9]" (line-end-position) nil)
					    (1- (point))))))
		    (delete-region beg-of-version end-of-version)
		    (insert elemversion)
		    ))))))
	)
      )
    ))

(defun bbbike-insert-osm-watch ()
  (interactive)
  (let ((sel (bbbike--get-x-selection)))
    (cond
     ((string-match "<\\(way\\|node\\|relation\\).* \\(id=\"[0-9]+\"\\).* \\(version=\"[0-9]+\"\\)" sel)
      (let ((elemtype (substring sel (match-beginning 1) (match-end 1)))
	    (elemidxml (substring sel (match-beginning 2) (match-end 2)))
	    (elemversionxml (substring sel (match-beginning 3) (match-end 3))))
	(beginning-of-line)
	(insert (concat "#: osm_watch: " elemtype " " elemidxml " " elemversionxml "\n"))))
     ((string-match "/note/\\([0-9]+\\)" sel)
      (let ((elemid (substring sel (match-beginning 1) (match-end 1))))
	(beginning-of-line)
	(insert (concat "#: osm_watch: note " elemid " 1\n"))))
     ((string-match "https?://www.openstreetmap.org.*\\(way\\|node\\|relation\\)/\\([0-9]+\\)\\(#\\|$\\|/history\\)" sel)
      (let* ((elemtype (substring sel (match-beginning 1) (match-end 1)))
	     (elemid (substring sel (match-beginning 2) (match-end 2)))
	     (elemversion (bbbike--get-osm-elem-version elemtype elemid)))
	(beginning-of-line)
	(insert (concat "#: osm_watch: " elemtype " id=\"" elemid "\" version=\"" elemversion "\"\n"))))
     (t (error "No X selection or X selection does not contain a way/node/relation line")))))

(defun bbbike-insert-source-id ()
  (interactive)
  (let ((sel (bbbike--get-x-selection))
	(description "")
	source-id)
    (cond
     ((string-match "\t\\([A-Za-z0-9_/-]+\\)\t\\(INUSE\\)?$" sel) (setq source-id (substring sel (match-beginning 1) (match-end 1))))
     ((string-match (concat "\\(" bbbike-viz2021-regexp "\\)") sel) (setq source-id (substring sel (match-beginning 1) (match-end 1))))
     ((string-match "https://www.bvg.de/de/verbindungen/stoerungsmeldungen/\\(.*\\)" sel) (setq source-id (concat "bvg2021:" (substring sel (match-beginning 1) (match-end 1)))))
     (t (error "No X selection or X selection does not contain a source-id")))
    (if (string-match " \\(bis [0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]\\)" sel)
	(setq description (concat " (" (substring sel (match-beginning 1) (match-end 1)) ")")))
    (beginning-of-line)
    (insert (concat "#: source_id: " source-id description "\n"))))

(setq bbbike-next-check-id-regexp "^#:[ ]*\\(next_check_id\\):?[ ]*\\([^ \n]+\\)")

(defun bbbike-grep-next-check-id ()
  (let (search-key search-val dirop)
    (save-excursion
      (beginning-of-line)
      (if (looking-at bbbike-next-check-id-regexp)
	  (progn
	    (setq search-key (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
	    (setq search-val (buffer-substring-no-properties (match-beginning 2) (match-end 2))))))
    (if (not search-val)
	(error "Can't find anything to grep for"))
    (if search-key
	(bbbike-grep-bbd-directive search-key search-val))))

(defun bbbike-grep-bbd-directive (search-key search-val)
  (bbbike-grep-with-search-term (concat "^#:[ ]*" search-key ":?[ ]*" search-val) t))

;; old, now unused version which just uses the "grep" command
(defun bbbike-grep-with-search-term-simple (search-term &optional is-regexp)
  (let ((bbbike-rootdir (bbbike-rootdir)))
    (grep (concat bbbike-rootdir "/miscsrc/bbbike-grep -n"
		  " --add-file " bbbike-rootdir "/t/cgi-mechanize.t"
		  " --add-file " bbbike-rootdir "/t/old_comments.t"
		  (if is-regexp " --rx" " --")
		  " '" search-term "'"))))

;; new version: if there's only one match, then go directly to the file.
;; Otherwise display the output in temporary grep-mode buffer.
(defun bbbike-grep-with-search-term (search-term &optional is-regexp)
  (interactive "MString to grep for in bbbike data: ")
  (let* ((search-term (bbbike--string-trim search-term))
	 (bbbike-rootdir (bbbike-rootdir))
	 (bbbike-datadir (bbbike-datadir))
	 (bbbike-grep-cmd (concat bbbike-rootdir "/miscsrc/bbbike-grep -n"
				  " --add-file-with-encoding " bbbike-rootdir "/t/cgi-mechanize.t:iso-8859-1"
				  " --add-file-with-encoding " bbbike-rootdir "/t/old_comments.t:iso-8859-1"
				  ; XXX experimental: search also in org files (e.g. for Bebauungsplaene)
				  (if (org-agenda-files)
				      (concat " "
					      (mapconcat (lambda (file) (concat "--add-file-with-encoding " file ":utf-8")) ; assume that org-mode files are encoded using utf-8
							 (org-agenda-files)
							 " ")))
				  " --reldir " bbbike-datadir
				  (if is-regexp " --rx" " --")
				  " '" search-term "'"))
	 (output (shell-command-to-string bbbike-grep-cmd))
         (lines (split-string output "\n" t))
         (num-lines (length lines)))
    (cond
     ((= num-lines 0)
      (progn
	(if (get-buffer "*bbbike-grep-output*") (kill-buffer "*bbbike-grep-output*"))
	(message "No matching lines found for '%s'." search-term)))
     ((= num-lines 1)
      (let* ((line (car lines))
             (parts (split-string line ":"))
             (filename (car parts))
             (line-number (string-to-number (cadr parts))))
	(if (get-buffer "*bbbike-grep-output*") (kill-buffer "*bbbike-grep-output*"))
        (find-file (concat bbbike-datadir "/" filename))
        (goto-line line-number)))
     (t
      (let ((buffer (get-buffer-create "*bbbike-grep-output*")))
        (with-current-buffer buffer
          (read-only-mode -1)
          (erase-buffer)
          (dolist (line lines)
            (insert line)
            (insert "\n"))
	  (grep-mode)
	  (setq-local default-directory bbbike-datadir)
	  (setq-local compilation-directory (concat bbbike-datadir "/"))
	  (setq-local compile-command bbbike-grep-cmd)
	  (goto-char (point-min))
	  )
	(pop-to-buffer buffer))))))

(defun bbbike-next-check-id-button (button)
  (bbbike-grep-next-check-id))

(define-button-type 'bbbike-next-check-id-button
  'action 'bbbike-next-check-id-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to grep for the same next_check_id")

(defun bbbike-grep-selection ()
  (interactive)
  (let ((sel (bbbike--get-x-selection)))
    (if sel
	(progn
	  (if (string-match "^\\(?:UNCHANGED\\|CHANGED\\|NEW\\|REMOVED\\)\t[^\t]+\t\\([^\t]+\\)" sel) ; try to match diffnewvmz selection
	      (setq sel (substring sel (match-beginning 1) (match-end 1))))
	  (bbbike-grep-with-search-term sel nil) ;; XXX may fail with some meta characters like single quote
	  )
      (error "No X selection"))))

(defun bbbike-view-url-button (button)
  (let ((url (button-get button :url)))
    (message (format "url %s" url))
    (bbbike-view-url url)))

(define-button-type 'bbbike-url-button
  'action 'bbbike-view-url-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to browse (cached) URL")

(setq bbbike-sourceid-in-pl-regexp  (concat "^[ ]*source_id\\(\\[inactive\\]\\)?[ ]*=>[ ]*'\\(" bbbike-viz2021-regexp "\\|[0-9][0-9B]+\\|LMS[-_][^'\"]*\\|LS/[A-Z0-9/-]*\\|AdB/[0-9-]+\\)"))
(setq bbbike-sourceid-in-bbd-regexp (concat "^#:[ ]*source_id\\(\\[inactive\\]\\)?:?[ ]*\\(" bbbike-viz2021-regexp "\\|[0-9][0-9B]+\\|LMS[-_][^ \n]*\\|LS/[A-Z0-9/-]*\\|AdB/[0-9-]+\\)"))
(setq bbbike-vmz-diff-file "~/cache/misc/diffnewvmz.bbd")

;; old definition when it was possible to create deeplinks for VMZ ids
;(defun bbbike-sourceid-viz-button (button)
;  (let* ((bbbikepos (button-get button :bbbikepos))
;	 (lonlat (bbbike--convert-coord-to-wgs84 bbbikepos))
;	 lon lat)
;    (pcase-let ((`(,lon ,lat) (split-string lonlat ",")))
;      (browse-url (format bbbike-sourceid-viz-format (button-get button :sourceid) (string-to-number lon) (string-to-number lat))))))

(defun bbbike-sourceid-viz-button (button)
  (let ((sourceid (button-get button :sourceid))
	(bbbike-datadir (bbbike-datadir))
	(fragezeichen-lowprio (concat (bbbike-aux-bbddir) "/fragezeichen_lowprio.bbd")))
    (grep (concat "2>/dev/null egrep -a -ns "
		  bbbike-vmz-diff-file " "
		  (if (file-exists-p fragezeichen-lowprio) (concat fragezeichen-lowprio " "))
		  bbbike-datadir "/*-orig" " "
		  bbbike-datadir "/temp_blockings/bbbike-temp-blockings.pl" " "
		  "-e " "'" "(�|\246| )" sourceid "(�|\246| |$)" "'"))))

(define-button-type 'bbbike-sourceid-viz-button
  'action 'bbbike-sourceid-viz-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to show source_id element (VMZ/VIZ)")

(define-button-type 'bbbike-inactive-sourceid-viz-button
  'action 'bbbike-sourceid-viz-button
  'follow-link t
  'face 'bbbike-button-strike
  'mouse-face 'bbbike-button-strike-hover
  'help-echo "Click button to show inactive source_id element (VMZ/VIZ)")

(defun bbbike-bvg-button (button)
  ;; It would be better to link directly to the traffic note,
  ;; but unfortunately there's only an anchor available for
  ;; the "Stoerungsmeldungen" section, not for the specific
  ;; traffic notes.
  (browse-url (concat "https://www.bvg.de/de/verbindungen/linienuebersicht/" (button-get button :bvgline) "#stoerungsmeldungen")))

(define-button-type 'bbbike-bvg-button
  'action 'bbbike-bvg-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to show BVG traffic note")

(define-button-type 'bbbike-inactive-bvg-button
  'action 'bbbike-bvg-button
  'follow-link t
  'face 'bbbike-button-strike
  'mouse-face 'bbbike-button-strike-hover
  'help-echo "Click button to show inactive BVG traffic note" ; this should still link somewhere, as currently linking is done using BVG lines
  )

(defun bbbike-osm-button (button)
  (browse-url (concat "http://www.openstreetmap.org/" (button-get button :osmid))))

(define-button-type 'bbbike-osm-button
  'action 'bbbike-osm-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to show OSM element")

(defun bbbike-osm-note-button (button)
  (browse-url (concat "http://www.openstreetmap.org/note/" (button-get button :osmnoteid))))

(define-button-type 'bbbike-osm-note-button
  'action 'bbbike-osm-note-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to show OSM note")

(defun bbbike-traffic-button (button)
  (browse-url (concat bbbike-mc-traffic-base-url "&" (bbbike--convert-coord-to-wgs84 (button-get button :bbbikepos) "lat=%lat&lon=%lon"))))

(define-button-type 'bbbike-traffic-button
  'action 'bbbike-traffic-button
  'follow-link t
  'face 'bbbike-button
  'help-echo "Click button to show current traffic situation using mc.bbbike.org")

(defun bbbike-create-buttons ()
  ;; For some reason, overlays accumulate if a buffer
  ;; is visited another time, making emacs slower and slower.
  ;; Hack is to remove them all first.
  ;; remove-overlays does not seem to exist for older emacsen (<23.x.x?)
  (if (fboundp 'remove-overlays)
      (remove-overlays))

  ;; recognize "#: next_check_id" directives (will be linked to a grep in bbbike's data directory)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp bbbike-next-check-id-regexp nil t)
      (let ((next-check-id-val (buffer-substring-no-properties (match-beginning 2) (match-end 2))))
	(if (> (length next-check-id-val) 3)
	    (setq next-check-id-val (substring next-check-id-val 0 3)))
	(if (not (string= next-check-id-val "^^^"))
	    (make-button (match-beginning 1) (match-end 2) :type 'bbbike-next-check-id-button)))
      ))

  ;; recognize "#: by" directives which look like a URL in normal bbd files, additionally "#: also_indoor url" directives
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp "^#:[ ]*\\(?:by\\(?:\\[\\(?:nocache\\|removed\\)\\]\\)?\\|url\\|also_indoor:?[ ]+\\(?:url\\|webcam\\)\\):?[ ]*\\(http[^ \n]+\\)" nil t)
      (make-button (match-beginning 1) (match-end 1) :type 'bbbike-url-button)))

  (if (string-match "/bbbike-temp-blockings" buffer-file-name)
      (progn
	;; recognize "source_id" keys in bbbike-temp-blockings which look like a URL
	(save-excursion
	  (goto-char (point-min))
	  (while (search-forward-regexp "^[ ]*source_id[ ]*=>[ ]*'\\(http[^']+\\)" nil t)
	    (make-button (match-beginning 1) (match-end 1) :type 'bbbike-url-button :url (buffer-substring-no-properties (match-beginning 1) (match-end 1)))))
	;; recognize "source_id" keys in bbbike-temp-blockings which look like VIZ/VMZ ids (integers or starting with LMS)
	;; complicated, need to find a valid bbbike coordinate (which is later translated to lon/lat)
	(save-excursion
	  (goto-char (point-min))
	  (while (search-forward-regexp bbbike-sourceid-in-pl-regexp nil t)
	    (let* ((is-inactive (if (match-beginning 1) t nil))
		   (begin-pos (match-beginning 2))
		   (end-pos (match-end 2))
		   (source-id (buffer-substring begin-pos end-pos))
	           (button-type (if (or is-inactive (bbbike--is-source-id-inactive)) 'bbbike-inactive-sourceid-viz-button 'bbbike-sourceid-viz-button)))
	      (make-button begin-pos end-pos
			   :type button-type
			   :sourceid source-id
			   ))))
	))

  ;; recognize "#: source_id" directives in bbd files which look like VIZ/VMZ ids (see above)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp bbbike-sourceid-in-bbd-regexp nil t)
      (let* ((is-inactive (if (match-beginning 1) t nil))
	     (begin-pos (match-beginning 2))
	     (end-pos (match-end 2))
	     (source-id (buffer-substring begin-pos end-pos))
	     (button-type (if (or is-inactive (bbbike--is-source-id-inactive)) 'bbbike-inactive-sourceid-viz-button 'bbbike-sourceid-viz-button)))
	(make-button begin-pos end-pos
		     :type button-type
		     :sourceid source-id
		     ))))

  ;; recognize "#: source_id" bvg directives in bbd files
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp "^#:[ ]*source_id\\(\\[inactive\\]\\)?:?[ ]\\(bvg2021\\|bvg2024\\):\\([^# \n]+\\)\\([^ \n]*\\)" nil t)
      (let* ((is-inactive (if (match-beginning 1) t nil))
	     (button-type (if is-inactive 'bbbike-inactive-bvg-button 'bbbike-bvg-button))
	     (link-begin-pos (match-beginning 2))
	     (bvg-line-begin-pos (match-beginning 3))
	     (bvg-line-end-pos (match-end 3))
	     (link-end-pos (match-end 4))
	     (bvg-line (buffer-substring bvg-line-begin-pos bvg-line-end-pos)))
	(make-button link-begin-pos link-end-pos
		     :type button-type
		     :bvgline bvg-line
		     ))))

  ;; recognize "#: osm_watch" directives (ways etc.)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp "^#:[ ]*\\(osm_watch\\):?[ ]*\\(way\\|node\\|relation\\)[ ]+id=\"\\([0-9]+\\)\"" nil t)
      (make-button (match-beginning 1) (match-end 1)
		   :type 'bbbike-osm-button
		   :osmid (concat (buffer-substring-no-properties (match-beginning 2) (match-end 2)) "/" (buffer-substring-no-properties (match-beginning 3) (match-end 3)))
		   )))

  ;; recognize "#: osm_watch" directives (just notes)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp "^#:[ ]*\\(osm_watch\\):?[ ]*note[ ]+\\([0-9]+\\)" nil t)
      (make-button (match-beginning 1) (match-end 1)
		   :type 'bbbike-osm-note-button
		   :osmnoteid (buffer-substring-no-properties (match-beginning 2) (match-end 2))
		   )))

  ;; recognize "#: also_indoor: traffic" directives
  (save-excursion
    (goto-char (point-min))
    (while (search-forward-regexp "^#:[ ]*also_indoor:?[ ]*\\(traffic.*\\)" nil t)
      (make-button (match-beginning 1) (match-end 1)
		   :type 'bbbike-traffic-button
		   ;: very expensive, use only for debugging --- bbbikepos (bbbike--bbd-find-next-coordinate (format "traffic at line %s" (line-number-at-pos (match-beginning 1))))
		   :bbbikepos (bbbike--bbd-find-next-coordinate "traffic")
		   )))
  )

(defun bbbike--is-source-id-inactive ()
  (if (save-excursion (search-forward-regexp "\\(inactive\\|inaktiv\\))? *\\(vvv+\\)?$" (save-excursion (end-of-line) (point)) t))
      t
    nil))

;; convert bbbike "standard" coordinates to WGS84 coordinates using external commands
;; usage:
;;    (bbbike--convert-coord-to-wgs84 "8000,6000")
;;    (bbbike--convert-coord-to-wgs84 "8000,6000" "lat=%lat,lon=%lon")
(defun bbbike--convert-coord-to-wgs84 (in &optional fmt)
  (if (not fmt) (setq fmt "%lon,%lat"))
  (let (lon lat res)
    (pcase-let ((`(,lon ,lat) (split-string (replace-regexp-in-string "\n$" "" (shell-command-to-string (concat "perl -I " (bbbike-rootdir) " " (bbbike-rootdir) "/Karte.pm -from standard -to polar -- " in))) ",")))
      (setq res (replace-regexp-in-string "%lon" lon fmt))
      (setq res (replace-regexp-in-string "%lat" lat res))
      res)))

(defun bbbike--bbd-find-next-coordinate (label)
  (save-excursion
    (if (not (search-forward-regexp "^\\([^#].*\t\\|\t\\)[^ ]*[ ]*\\([^,]*,[^ ]*\\)" nil t)) ; search first coordinate (and make available as $1)
	(error (concat "Cannot find bbd record with coordinate for " label)))
    )
  (buffer-substring (match-beginning 2) (match-end 2))
  )

(defun bbbike--get-osm-elem-version-perl (elemtype elemid)
  (let* ((url (concat "https://api.openstreetmap.org/api/0.6/" elemtype "/" elemid))
	 (elemversion (shell-command-to-string (concat bbbike-perl-modern-executable " -MLWP::UserAgent -MXML::LibXML -e 'my $ua = LWP::UserAgent->new(timeout => 10); my $xml = $ua->get(shift)->decoded_content; print XML::LibXML->load_xml(string => $xml)->documentElement->findvalue(q{/osm/" elemtype "/@version})' " url))))
    elemversion))

(defun bbbike--get-osm-elem-version-elisp (elemtype elemid)
  (let* ((url (format "https://api.openstreetmap.org/api/0.6/%s/%s" elemtype elemid))
         (buffer (url-retrieve-synchronously url))
         (content (with-current-buffer buffer
                    (goto-char (point-min))
                    (re-search-forward "\n\n" nil 'move)
                    (buffer-substring-no-properties (point) (point-max))))
         (elemversion nil))
    (with-temp-buffer
      (insert content)
      (let* ((xml (xml-parse-region (point-min) (point-max))))
        (condition-case err
            (let* ((osm (car xml))
                   (element (car (xml-get-children osm (intern elemtype))))
                   (version-attr (xml-get-attribute element 'version)))
              (setq elemversion version-attr))
          (error (message "XML parsing error: %s" err)))))
    (kill-buffer buffer)
    elemversion))

(defun bbbike--get-osm-elem-version (elemtype elemid)
  (bbbike--get-osm-elem-version-elisp elemtype elemid))

(defun bbbike--string-trim (str)
  "Remove leading and trailing whitespace from STR."
  (replace-regexp-in-string "\\`[[:space:]\n]*\\|[[:space:]\n]*\\'" "" str))

(provide 'bbbike-mode)
