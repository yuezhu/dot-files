;;; init.el --- ... -*- lexical-binding: t -*-

;; Used to report time spent loading this module
(defconst emacs-start-time (current-time))

;; `file-name-handler-alist' maps filename patterns (regexes) to
;; special handler functions. When Emacs opens or operates on a file
;; whose name matches a pattern, it routes the operation through that
;; During startup, Emacs calls `load', `require', and various file
;; operations hundreds of times to load packages and config files. For
;; every file operation, Emacs iterates through
;; `file-name-handler-alist' and runs each regex against the filename
;; to check for a match.  These regexes almost never match during
;; startup (you're loading local .el files, not remote TRAMP paths or
;; .gz archives), so it's pure overhead. As a result, we temperatily
;; clear `file-name-handler-alist' during startup and restore it at
;; the end.
(defvar file-name-handler-alist-old file-name-handler-alist)

(setq file-name-handler-alist nil)

(add-hook 'after-init-hook
          #'(lambda ()
              (setq file-name-handler-alist file-name-handler-alist-old)))

;; Add local lisp files directory to `load-path'.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))


;; Debugging utilities for package loading.  Useful for tracking down
;; which package is loading a particular feature.
(defun debug-package-load (feature)
  "Trace where FEATURE is loaded from.

Add advice to both `require' and `load' to print a backtrace
when FEATURE is loaded.  Call this early in init.el, before
the package in question could be loaded.

FEATURE is a symbol, e.g. \\='reformatter.

Usage:
  (debug-package-load \\='reformatter)"
  (let ((name (symbol-name feature)))
    (advice-add 'require :before
                `(lambda (feat &rest _)
                   (when (eq feat ',feature)
                     (message "*** %s required ***" ,name)
                     (backtrace)))
                `((name . ,(intern (format "debug-%s-require" name)))))
    (advice-add 'load :before
                `(lambda (file &rest _)
                   (when (and (stringp file)
                              (string-match-p ,name file))
                     (message "*** %s loaded via load ***" ,name)
                     (backtrace)))
                `((name . ,(intern (format "debug-%s-load" name)))))))


;; (debug-package-load 'reformatter)


;;
;; Initialize ELPA
;;
(require 'package)

;; Some packages are built into Emacs, but I want to use the ELPA
;; versions.
(defconst package-must-use-elpa-packages
  '(org eldoc flymake eglot)
  "A list of packages that must use the ELPA versions.")

(advice-add 'package-installed-p :around
            (lambda (func &rest args)
              (let ((pkg (car args)))
                (if (memq pkg package-must-use-elpa-packages)
                    (assq pkg package-alist)
                  (apply func args)))))

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(advice-add 'package-upgrade-all :around
            (lambda (func &rest _)
              "Upgrade all packages without asking."
              (funcall func)))

;;
;; Initialize `use-package'
;; https://github.com/jwiegley/use-package
;;
(setq use-package-enable-imenu-support t
      use-package-verbose t)

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))


;;
;; Packages configurations
;;
(use-package diminish
  :ensure t
  :commands diminish)


(use-package emacs
  :defer t
  :custom
  ;; src/nsterm.m
  (ns-alternate-modifier 'super)
  (ns-command-modifier 'meta)

  ;; src/frame.c
  (menu-bar-mode (equal system-type 'darwin))
  (tool-bar-mode nil)

  ;; src/xdisp.c
  (frame-title-format
   '((:eval (or buffer-file-name (buffer-name)))
     (:eval (if (buffer-modified-p) " * " " - "))
     "GNU Emacs " emacs-version " - " system-name))
  (max-mini-window-height 0.5)
  (redisplay-skip-fontification-on-input t)

  ;; src/lread.c
  (load-prefer-newer t)

  ;; src/process.c
  (read-process-output-max (* 1024 1024))

  ;; src/font.c
  (inhibit-compacting-font-caches t)

  ;; src/fileio.c
  (delete-by-moving-to-trash t)

  ;; src/minibuffer.c
  (context-menu-mode t)
  (enable-recursive-minibuffers t)
  (hisqtory-delete-duplicates t)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt))

  ;; src/buffer.c
  (tab-width 4)

  ;; src/frame.c
  (frame-resize-pixelwise t)
  (frame-inhibit-implied-resize t)

  ;; src/xdisp.c
  (message-log-max 16384)
  (x-stretch-cursor t)

  ;; src/eval.c
  (max-lisp-eval-depth 2000)
  (max-specpdl-size 16384)

  ;; src/terminal.c
  (ring-bell-function 'ignore)

  ;; src/undo.c
  (undo-limit 1000000)

  ;; src/fns.c
  (use-dialog-box nil)
  (use-file-dialog nil)
  (use-short-answers t)

  ;; files.el
  (confirm-kill-emacs 'yes-or-no-p)
  (directory-free-space-args "-Pkh")
  (find-file-visit-truename t)
  (make-backup-files nil)
  (mode-require-final-newline t)
  (require-final-newline t)

  ;; mouse.el
  ;; Enable context menu. `vertico-multiform-mode' adds a menu in the
  ;; minibuffer to switch display modes.
  (context-menu-mode t)

  ;; startup.el
  (inhibit-startup-screen t)
  (initial-major-mode 'fundamental-mode)
  (initial-scratch-message nil)
  (large-file-warning-threshold 50000000)

  ;; indent.el
  ;; TAB first tries to indent the current line, and if the line was
  ;; already indented, then try to complete the thing at point.
  (tab-always-indent 'complete)

  ;; minibuffer.el
  (completion-cycle-threshold nil)

  :custom-face
  (aw-leading-char-face
   ((t (:inherit aw-leading-char-face :weight bold :height 3.0))))

  :init
  (add-hook 'after-save-hook
            #'executable-make-buffer-file-executable-if-script-p))


(use-package scroll-bar
  :defer t
  :custom
  (scroll-bar-mode nil))


(use-package mouse
  :defer t
  :custom
  (mouse-drag-copy-region t)
  (mouse-yank-at-point t))


(use-package mwheel
  :defer t
  :custom
  (mouse-wheel-progressive-speed nil))


(use-package warnings
  :defer t
  :custom
  (warning-minimum-level :error))


(use-package window
  :defer t
  :custom
  (scroll-error-top-bottom t))


(use-package delsel
  :defer t
  :custom
  (delete-selection-mode t))


(use-package cus-edit
  :defer t
  :init
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  (setq custom-buffer-done-kill t)
  ;; I don't use "M-x customize", so don't load `custom-file'.
  ;; :config
  ;; (load custom-file 'noerror)
  ;; (let ((elapsed (float-time (time-subtract (current-time)
  ;;                                           emacs-start-time))))
  ;;   (message "Loading %s (source)...done (%.3fs) (GC: %d)"
  ;;            custom-file elapsed gcs-done))
  )


(use-package image-file
  :defer t
  :custom
  (auto-image-file-mode t))


(use-package font-core
  :defer t
  :custom
  (global-font-lock-mode t))


(use-package frame
  :defer t
  :custom
  (blink-cursor-mode nil))


(use-package isearch
  :no-require t
  :bind (:map isearch-mode-map
              ;; DEL during isearch should edit the search string, not jump
              ;; back to the previous result
              ;; https://github.com/purcell/emacs.d/blob/b484cada4356803d0ecb063d33546835f996fefe/lisp/init-isearch.el#L14
              ([remap isearch-delete-char] . isearch-del-char))
  :custom
  (isearch-allow-scroll t)
  (search-highlight t))


(use-package replace
  :defer t
  :custom
  (list-matching-lines-default-context-lines 3)
  (query-replace-highlight t))


(use-package select
  :defer t
  :custom
  (select-enable-clipboard t))


(use-package uniquify
  :defer t
  :custom
  (uniquify-after-kill-buffer-p t)
  (uniquify-buffer-name-style
   'post-forward-angle-brackets nil (uniquify)))


(use-package hl-line
  :defer t
  :hook ((compilation-mode
          gnus-mode
          ibuffer-mode
          magit-mode
          occur-mode
          dired-mode)
         . hl-line-mode))


(use-package goto-addr
  :defer t
  :hook
  (prog-mode . goto-address-prog-mode)
  ((text-mode magit-process-mode) . goto-address-mode))


(use-package display-fill-column-indicator
  :defer t
  :hook
  (auto-fill-mode
   . (lambda ()
       (display-fill-column-indicator-mode
        (if auto-fill-function 1 -1)))))


(use-package simple
  :defer t
  :diminish auto-fill-function
  :hook ((markdown-mode
          prog-mode
          protobuf-mode
          org-mode)
         . turn-on-auto-fill)
  :hook (((compilation-mode
           dired-mode
           speedbar-mode
           occur-mode)
          . (lambda () (visual-line-mode -1))))
  :custom
  (column-number-mode t)
  (indent-tabs-mode nil)
  (line-number-mode t)
  (size-indication-mode t)
  (transient-mark-mode t)

  (global-mark-ring-max 500)
  (mark-ring-max 100)

  (kill-do-not-save-duplicates t)
  (kill-ring-max 1000000)
  (kill-whole-line nil)

  (next-line-add-newlines nil))


(use-package ns-win
  :defer t
  :custom
  (ns-pop-up-frames nil))


(use-package subword
  :defer t
  :diminish
  :custom
  (global-subword-mode t))


(use-package xref
  :defer t
  :custom
  (xref-prompt-for-identifier nil))


(use-package autorevert
  :defer 2
  :custom
  (global-auto-revert-non-file-buffers t)
  :config
  (global-auto-revert-mode t))


(use-package time
  :defer 2
  :custom
  (display-time-day-and-date nil)
  :config
  (display-time-mode t))


(use-package so-long
  :defer 2
  :config
  (global-so-long-mode t))


(use-package eldoc
  :ensure t
  :defer 2
  :diminish
  :hook
  (prog-mode . global-eldoc-mode)
  :custom
  ;; Show all the results eagerly
  (eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)
  :config
  (global-eldoc-mode t))


(use-package which-func
  :defer 2
  :custom
  (which-func-unknown "n/a")
  :hook
  (prog-mode . which-function-mode)
  :config
  (which-function-mode t))


(use-package electric
  :hook
  (after-init . electric-indent-mode))


(use-package elec-pair
  :hook
  (after-init . electric-pair-mode))


(use-package ediff-wind
  :defer t
  :custom
  (ediff-split-window-function 'split-window-horizontally)
  (ediff-window-setup-function 'ediff-setup-windows-plain))


(use-package ialign
  :ensure t
  :bind ("C-c |" . ialign))


(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :ensure t
  :config
  (exec-path-from-shell-initialize))


(use-package winner
  :unless noninteractive
  :defer 2
  :preface
  (defun transient-winner-undo ()
    "Transient version of `winner-undo'."
    (interactive)
    (let ((echo-keystrokes nil))
      (winner-undo)
      (message "Winner: [u]ndo [r]edo")
      (set-transient-map
       (let ((map (make-sparse-keymap)))
         (define-key map [?u] #'winner-undo)
         (define-key map [?r] #'winner-redo)
         map)
       t)))

  :bind ("C-c u" . transient-winner-undo)

  :hook
  ;;  (after-init . winner-mode)
  (ediff-before-setup . winner-mode)
  (ediff-quit . winner-undo)

  :config
  (winner-mode))


(use-package midnight
  :disabled ;; 2023-07-31 not used
  :defer 2
  :config
  (midnight-mode))


(use-package repeat
  :defer t
  :custom
  (repeat-exit-key [return])
  (repeat-mode t))


(use-package paren
  :defer t
  :custom
  (show-paren-mode t)
  (show-paren-delay 0)
  (show-paren-style 'parentheses))


(use-package recentf
  :defer 2
  :preface
  ;; https://github.com/jwiegley/dot-emacs/blob/master/init.el
  (defun recentf-add-dired-directory ()
    (if (and dired-directory
             (file-directory-p dired-directory)
             (not (string= "/" dired-directory)))
        (let ((last-idx (1- (length dired-directory))))
          (recentf-add-file
           (if (= ?/ (aref dired-directory last-idx))
               (substring dired-directory 0 last-idx)
             dired-directory)))))

  :custom
  (recentf-auto-cleanup 60)
  (recentf-exclude
   '("\\`out\\'"
     "\\.log\\'"
     "\\.el\\.gz\\'"
     "/\\.emacs\\.d/elpa/.*-\\(autoloads\\|pkg\\)\\.el\\'"
     "/\\.emacs\\.d/\\(auto-save-list\\|projects\\|recentf\\|snippets\\|tramp\\|var\\)"
     "/\\.git/COMMIT_EDITMSG\\'"))
  (recentf-filename-handlers '(abbreviate-file-name))
  (recentf-max-saved-items 2000)

  :hook
  (dired-mode . recentf-add-dired-directory)

  :commands (recentf-mode
             recentf-add-file
             recentf-save-list
             recentf-string-member)

  :config
  (recentf-mode)

  (advice-add 'recentf-cleanup :around
              (lambda (func &rest args)
                "Do not echo the message onto minibuffer when cleaning up
`recentf-list'."
                (let ((inhibit-message t))
                  (apply func args)))))


(use-package whitespace
  :defer t
  :bind (("C-c w m" . whitespace-mode)
         ("C-c w r" . whitespace-report)
         ("C-c w c" . whitespace-cleanup))
  :diminish (global-whitespace-mode
             whitespace-mode
             whitespace-newline-mode)
  :hook ((conf-mode
          json-mode
          ssh-config-mode
          yaml-mode
          makefile-mode)
         . whitespace-mode)
  :custom
  (whitespace-line-column 100)
  (whitespace-style '(face trailing tabs)))


(use-package ispell
  :defer t
  ;; 2023-08-12 use `flyspell-correct'
  ;;  :bind ("C-c i w" . ispell-word)
  :custom
  (ispell-program-name "hunspell")
  (ispell-personal-dictionary "~/.emacs.d/ispell-personal-dictionary")
  (ispell-silently-savep t)
  (ispell-local-dictionary-alist
   '(("en_US"
      "[[:alpha:]]" "[^[:alpha:]]" "[']" nil
      ("-d" "en_US") nil utf-8)))
  (ispell-local-dictionary "en_US")
  :config
  ;; Hunspell cannot create the personal dictionary file if it does not exist.
  (unless (file-exists-p ispell-personal-dictionary)
    (make-empty-file ispell-personal-dictionary)))


(use-package flyspell
  :bind ("C-c i b" . flyspell-buffer)
  :hook
  (text-mode . flyspell-mode)
  :custom
  (flyspell-sort-corrections t)
  :config
  ;; https://github.com/abo-abo/oremacs/blob/github/modes/ora-flyspell.el
  (defun flyspell-ignore-http-and-https ()
    "Function used for `flyspell-generic-check-word-predicate' to
ignore stuff starting with \"http\" or \"https\"."
    (save-excursion
      (forward-whitespace -1)
      (not (looking-at "[\t ]+https?\\b"))))
  (dolist (mode '(text-mode org-mode)) ;; need to specify all derived modes
    (put mode 'flyspell-mode-predicate #'flyspell-ignore-http-and-https)))


(use-package flyspell-correct
  :ensure t
  :after flyspell
  :bind (:map flyspell-mode-map
              ("C-c i w" . flyspell-correct-wrapper)))


(use-package flymake
  :ensure t
  :defer t
  :hook
  (prog-mode . flymake-mode))


(use-package flycheck
  :disabled ;; 2023-08-12 use `flymake'
  :defer 2
  :custom
  (flycheck-disabled-checkers
   '(c/c++-cppcheck
     c/c++-gcc
     go-build
     go-errcheck
     go-gofmt
     go-golint
     go-staticcheck
     go-test
     go-unconvert
     go-vet
     json-jsonlint
     json-python-json
     python-mypy
     python-pycompile
     python-pyright
     ruby-rubocop
     sh-bash
     sh-posix-bash
     sh-posix-dash
     sh-zsh
     yaml-jsyaml
     yaml-ruby
     emacs-lisp-checkdoc))
  :config
  (global-flycheck-mode 1))


(use-package ibuffer
  :bind ("C-x C-b" . ibuffer)
  :hook
  (ibuffer-mode . ibuffer-auto-mode)
  (ibuffer . (lambda ()
               (ibuffer-vc-set-filter-groups-by-vc-root)
               (unless (eq ibuffer-sorting-mode 'filename/process)
                 (ibuffer-do-sort-by-filename/process))))

  :custom
  (ibuffer-filter-group-name-face 'font-lock-doc-face)
  (ibuffer-formats '((mark modified read-only vc-status-mini " "
                           (name 32 32 :left :elide)
                           " "
                           (size-h 9 -1 :right)
                           " "
                           (mode 16 16 :left :elide)
                           " "
                           (vc-status 16 -1 :left)
                           " " filename-and-process)))

  :config
  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (cond
     ((> (buffer-size) 1000) (format "%7.3fK" (/ (buffer-size) 1024.0)))
     ((> (buffer-size) 1000000) (format "%7.3fM" (/ (buffer-size) 1048576.0)))
     (t (format "%8d" (buffer-size))))))


(use-package ibuffer-vc
  :ensure t
  :after ibuffer)


(use-package hideshow
  :defer t
  :diminish hs-minor-mode
  :hook (prog-mode . hs-minor-mode))


(use-package diff-hl
  :ensure t
  :defer t
  :hook ((conf-mode
          protobuf-mode
          ssh-config-mode
          text-mode
          prog-mode)
         . diff-hl-mode)
  (magit-pre-refresh . diff-hl-magit-pre-refresh)
  (magit-post-refresh . diff-hl-magit-post-refresh)
  :custom
  (diff-hl-draw-borders nil))


(use-package tramp-sh
  :defer t
  :init
  ;; https://www.gnu.org/software/emacs/manual/html_node/tramp/Frequently-Asked-Questions.html
  (setq
   vc-ignore-dir-regexp
   (format "\\(%s\\)\\|\\(%s\\)"
           vc-ignore-dir-regexp
           tramp-file-name-regexp)
   tramp-connection-timeout 15
   tramp-default-method "ssh"
   tramp-use-ssh-controlmaster-options nil))


(use-package rg
  :ensure t
  :defer t
  :bind ("C-c r" . rg-menu)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*rg\\*\\'"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t)
                 (window-height . 0.5))))


(use-package wgrep
  :ensure t
  :defer t)


(use-package dumb-jump
  :ensure t
  :defer t
  :init
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
  :custom
  (dumb-jump-force-searcher 'rg))


(use-package hippie-exp
  :bind ("M-/" . hippie-expand)
  :defer t
  :config
  (advice-add 'hippie-expand :around
              (lambda (func &rest args)
                "Make `hippie-expand' do case-sensitive expanding. Though not all,
this is effective with some expand functions, eg.,
`try-expand-all-abbrevs'"
                (let ((case-fold-search nil))
                  (apply func args)))))


(use-package dired
  :defer t
  :preface
  (defun dired-find-directory (dir)
    (interactive "DFind directory: ")
    (let ((orig (current-buffer)))
      (dired dir)
      (kill-buffer orig)))

  ;; https://github.com/jwiegley/dot-emacs/blob/master/init.el
  (defun dired-next-window ()
    (interactive)
    (let ((next (car (cl-remove-if-not (lambda (wind)
                                         (with-current-buffer (window-buffer wind)
                                           (eq major-mode 'dired-mode)))
                                       (cdr (window-list))))))
      (when next
        (select-window next))))

  (defun dired-find-file-reuse-buffer ()
    "Replace current buffer if file is a directory."
    (interactive)
    (let ((orig (current-buffer))
          (filename (dired-get-file-for-visit)))
      (dired-find-file)
      (when (and (file-directory-p filename)
                 (not (eq (current-buffer) orig)))
        (kill-buffer orig))))

  (defun dired-up-directory-reuse-buffer ()
    "Replace current buffer if file is a directory."
    (interactive)
    (let ((orig (current-buffer)))
      (dired-up-directory)
      (kill-buffer orig)))

  :commands (dired-get-file-for-visit
             dired-find-file
             dired-up-directory
             dired-hide-details-mode)

  :bind (:map dired-mode-map
              ("/"     . dired-find-directory)
              ("<tab>" . dired-next-window)
              ("M-p"   . dired-up-directory-reuse-buffer)
              ("M-n"   . dired-find-file-reuse-buffer)
              ("!"     . crux-open-with))

  :hook
  (dired-mode
   . (lambda ()
       ;; (dired-hide-details-mode)
       (setq-local auto-revert-verbose nil)))

  :custom
  (insert-directory-program
   (cond
    ((and (equal system-type 'darwin)
          (executable-find "gls"))
     "gls")
    ((equal system-type 'darwin)
     "ls")))
  (dired-listing-switches
   (cond
    ((equal system-type 'gnu/linux)
     "-Ahl --group-directories-first")
    ((equal system-type 'darwin)
     (if (string-suffix-p "gls" insert-directory-program)
         "-Alh --group-directories-first"
       "-Ahl"))))
  (dired-dwim-target t)
  (dired-isearch-filenames 'dwim)
  (dired-omit-files "^\\.?#\\|^\\.$\\|^\\.\\.$\\|^\\..+$")
  (dired-omit-size-limit nil)
  (dired-omit-verbose nil)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always))


(use-package diredfl
  :ensure t
  :defer t
  :hook
  (dired-mode . diredfl-mode))


(use-package dired-x
  :disabled
  :defer t
  :hook
  (dired-mode . dired-omit-mode))


(use-package eglot
  :ensure t
  ;; 2023-07-31 manually start
  ;; :hook
  ;; ((go-mode
  ;;   c-mode
  ;;   c++-mode
  ;;   python-mode)
  ;;  . eglot-ensure)

  :defer t

  :bind (:map eglot-mode-map
              ("C-c l d" . eglot-find-declaration)
              ("C-c l t" . eglot-find-typeDefinition)
              ("C-c l i" . eglot-find-implementation)
              ("C-c l r" . eglot-rename))

  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  ;; (eglot-ignored-server-capabilites
  ;;  '(:documentHighlightProvider
  ;;    :codeActionProvider
  ;;    :codeLensProvider
  ;;    :documentFormattingProvider
  ;;    :documentRangeFormattingProvider
  ;;    :documentOnTypeFormattingProvider
  ;;    :documentLinkProvider))

  ;; :config
  ;; (add-to-list 'eglot-stay-out-of 'flymake)
  )


(use-package abbrev
  ;; Defer does not work. It is loaded somewhere else.
  ;; 09/11/20 `enh-ruby-mode' loads `abbrev'.
  :defer t
  :diminish
  :hook
  ;; ((text-mode prog-mode) . abbrev-mode)
  (expand-load
   . (lambda ()
       (add-hook 'expand-expand-hook #'indent-according-to-mode)
       (add-hook 'expand-jump-hook #'indent-according-to-mode)))
  :commands abbrev-mode ;; `cc-mode' turns on `abbrev-mode'.

  :custom
  (save-abbrevs 'silently)

  :config
  (if (file-exists-p abbrev-file-name)
      (quietly-read-abbrev-file)))


(use-package imenu
  :defer t
  :custom
  (imenu-auto-rescan t)
  (imenu-auto-rescan-maxout 600000)
  (imenu-max-item-length "Unlimited")
  :hook
  ((prog-mode
    conf-mode
    outline-mode
    markdown-mode
    package-menu-mode)
   . imenu-add-menubar-index))


(use-package crux
  :ensure t
  :defer t)


;; Prevent cursor from moving onto the minibuffer prompt
(use-package cursor-sensor
  :defer t
  :hook
  (minibuffer-setup . cursor-intangible-mode))


(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))


(use-package vertico
  :ensure t
  ;; :hook (after-init . vertico-mode)
  :init
  (vertico-mode)
  :custom
  (vertico-multiform-commands
   '((consult-yank-pop indexed)
     (consult-yank-replace indexed)
     (consult-imenu (completion-ignore-case . t))
     (consult-recent-file (completion-ignore-case . t))))
  :config
  (vertico-multiform-mode))


(use-package consult
  :ensure t
  :after vertico
  ;; Replace bindings. Lazily loaded by `use-package'.
  :bind (;; C-c bindings in `mode-specific-map'
         ("C-c M-x" . consult-mode-command)
         ("C-c TAB" . consult-imenu)
         ([remap Info-search] . consult-info)

         ;; C-x bindings in `ctl-x-map'
         ("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x 5 b" . consult-buffer-other-frame)
         ("C-x C-r" . consult-recent-file)
         ("C-x p b" . consult-project-buffer)
         ("C-x p g" . consult-ripgrep)

         ;; Other custom bindings
         ("M-y"     . consult-yank-replace)
         ("C-M-s"   . consult-line)

         ;; M-g bindings in `goto-map'
         ("M-g M-g" . consult-goto-line)
         ("M-g i"   . consult-imenu)

         ;; Isearch integration
         :map isearch-mode-map
         ("M-o" . consult-line))

  :init
  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  ;; Trigger preview manually
  (setq consult-preview-key "M-.")

  :config
  ;; Explicitly require `recentf' in order to use `consult-recent-file'.
  (require 'recentf)
  (setq completion-in-region-function #'consult-completion-in-region))


(use-package marginalia
  :ensure t
  :after vertico
  :bind (:map minibuffer-local-map
              ("M-A" . marginalia-cycle))

  :init
  ;; Marginalia must be activated in the :init section of use-package such that
  ;; the mode gets enabled right away. Note that this forces loading the
  ;; package.
  (marginalia-mode))


(use-package embark
  :ensure t
  :after vertico

  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'

  :init

  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc.  You may adjust the Eldoc
  ;; strategy, if you want to see the documentation from multiple providers.
  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  :config

  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))


(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))


(use-package corfu
  :ensure t
  :custom

  ;; Only use `corfu' when calling `completion-at-point' or
  ;; `indent-for-tab-command'
  (corfu-auto nil)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.25)

  (corfu-min-width 80)
  (corfu-max-width corfu-min-width)     ; Always have the same width
  (corfu-count 14)
  (corfu-scroll-margin 4)
  (corfu-cycle nil)

  ;; `nil' means to ignore `corfu-separator' behavior, that is, use the older
  ;; `corfu-quit-at-boundary' = nil behavior. Set this to separator if using
  ;; `corfu-auto' = `t' workflow (in that case, make sure you also set up
  ;; `corfu-separator' and a keybind for `corfu-insert-separator', which my
  ;; configuration already has pre-prepared). Necessary for manual corfu usage with
  ;; orderless, otherwise first component is ignored, unless `corfu-separator'
  ;; is inserted.
  (corfu-quit-at-boundary nil)
  (corfu-separator ?\s)            ; Use space
  (corfu-quit-no-match 'separator) ; Don't quit if there is `corfu-separator' inserted
  (corfu-preview-current 'insert)  ; Preview first candidate. Insert on input if only one
  (corfu-preselect-first t)        ; Preselect first candidate?

  :bind (:map corfu-map
              ("<escape>" . corfu-quit)
              ("M-l"      . corfu-info-location)
              ("M-d"      . corfu-popupinfo-toggle))

  :hook
  (after-init . global-corfu-mode))


(use-package corfu-popupinfo
  :after corfu
  :hook (corfu-mode . corfu-popupinfo-mode)
  :bind (:map corfu-map
              ("M-n" . corfu-popupinfo-scroll-up)
              ("M-p" . corfu-popupinfo-scroll-down)
              ([remap corfu-show-documentation] . corfu-popupinfo-toggle))

  :custom
  (corfu-popupinfo-delay 0.5)
  (corfu-popupinfo-max-width 70)
  (corfu-popupinfo-max-height 20))


(use-package cape
  :ensure t
  :after corfu
  :init
  (add-to-list 'completion-at-point-functions #'cape-keyword t)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev t)
  (add-to-list 'completion-at-point-functions #'cape-file t))


(use-package copilot
  :ensure t
  :defer t
  :bind (:map copilot-completion-map
              ;; I use TAB to trigger `corfu' completion.
              ;; ("<tab>" . copilot-accept-completion)
              ;; ("TAB" . copilot-accept-completion)
              ("C-e" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("C-TAB" . copilot-accept-completion-by-word)
              ("M-n" . copilot-next-completion)
              ("M-p" . copilot-previous-completion))
  :hook
  ((text-mode prog-mode conf-mode) . copilot-mode))


(use-package ace-window
  :ensure t
  :defer t
  :bind ("M-o" . ace-window)
  :custom
  (aw-scope 'frame))


(use-package ace-link
  :ensure t
  :defer t
  :bind ("C-c j a" . ace-link-addr))


(use-package avy
  :ensure t
  :defer t
  :bind (("C-c j c" . avy-goto-char)
         ("C-c j w" . avy-goto-word-1)
         ("C-c j l" . avy-goto-line)
         ("C-c j j" . avy-resume))
  :bind (:map isearch-mode-map
              ("C-," . avy-isearch))
  :custom
  (avy-case-fold-search t))


(use-package compile
  :defer t
  :preface
  (defun delete-compile-windows-if-success (buffer string)
    "Delete compilation windows if succeeded without warnings."
    (when (and (buffer-live-p buffer)
               (string-match "compilation" (buffer-name buffer))
               (string-match "finished" string)
               (not (with-current-buffer buffer
                      (goto-char (point-min))
                      (search-forward "warning" nil t))))
      (run-with-timer 1 nil
                      (lambda (buf)
                        (bury-buffer buf)
                        (delete-windows-on buf))
                      buffer)))

  :hook
  (shell-mode . compilation-shell-minor-mode)

  :init
  (add-hook 'compilation-finish-functions
            #'delete-compile-windows-if-success)

  :custom
  (compilation-always-kill t)
  (compilation-context-lines 10)
  (compilation-scroll-output t))


(use-package comint
  :defer t
  :preface
  (defun comint-output-read-only (&optional _string)
    "Add to comint-output-filter-functions to make comint output read only."
    (let ((inhibit-read-only t)
          (comint-last-output-end
           (process-mark (get-buffer-process (current-buffer)))))
      (put-text-property
       comint-last-output-start comint-last-output-end 'read-only t)))

  :init
  (add-hook 'comint-output-filter-functions #'comint-truncate-buffer)
  (add-hook 'comint-output-filter-functions #'comint-output-read-only)
  (add-hook 'comint-output-filter-functions #'ansi-color-process-output)
  (add-hook 'comint-mode-hook #'ansi-color-for-comint-mode-on)

  :custom
  (comint-buffer-maximum-size 16384)
  (comint-completion-addsuffix t)
  (comint-input-ignoredups t)
  (comint-input-ring-size 16384)
  (comint-move-point-for-output nil)
  (comint-prompt-read-only t)
  (comint-scroll-show-maximum-output t)
  (comint-scroll-to-bottom-on-input t))


(use-package term
  :defer t
  :hook (term-mode
         . (lambda ()
             (setq term-prompt-regexp "^[^#$%>\n]*[#$%>] *")
             (setq-local transient-mark-mode nil)
             (auto-fill-mode -1))))


(use-package terminal-here
  :ensure t
  :if window-system
  :defer t
  :custom
  (terminal-here-mac-terminal-command 'iterm2))


(use-package cwarn
  :commands cwarn-mode
  :diminish)


;; https://github.com/jwiegley/dot-emacs/blob/master/init.org#ps-print
(use-package ps-print
  :defer t
  :custom
  (ps-font-size '(8 . 10))
  (ps-footer-font-size '(12 . 14))
  (ps-header-font-size '(12 . 14))
  (ps-header-title-font-size '(14 . 16))
  (ps-line-number-font-size 10)
  (ps-print-color-p nil)
  :preface
  (defun ps-spool-to-pdf (beg end &rest _ignore)
    (interactive "r")
    (let ((temp-file (expand-file-name
                      (concat "~/" (make-temp-name "ps2pdf") ".pdf"))))
      (call-process-region beg end (executable-find "ps2pdf")
                           nil nil nil "-" temp-file)
      (call-process (executable-find "open") nil nil nil temp-file)))
  :config
  (setq ps-print-region-function 'ps-spool-to-pdf))


(use-package org
  :ensure t
  :defer t
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         ("C-c l" . org-store-link))

  :hook
  (org-mode
   . (lambda ()
       ;; (setq-local fill-column 120)
       ;; (setq-local electric-pair-pairs
       ;;             (append electric-pair-pairs '((?* . ?*)
       ;;                                           (?/ . ?/)
       ;;                                           (?_ . ?_)
       ;;                                           (?= . ?=)
       ;;                                           (?~ . ?~)
       ;;                                           (?+ . ?+))))
       ;; (setq-local electric-pair-text-pairs electric-pair-pairs)
       ))

  :custom
  (org-agenda-files `(,(file-name-as-directory org-directory)))
  (org-blank-before-new-entry '((heading)
                                (plain-list-item)))
  (org-clone-delete-id t)
  ;; (org-default-notes-file (concat
  ;;                          (file-name-as-directory org-directory)
  ;;                          "notes.org"))
  (org-edit-src-content-indentation 0)
  (org-export-default-language "en")
  (org-export-with-creator t)
  (org-export-with-section-numbers nil)
  (org-export-with-sub-superscripts '{})
  (org-export-with-toc nil)
  (org-hide-emphasis-markers t)
  (org-hide-leading-stars t)
  (org-log-done 'time)
  (org-log-reschedule 'time)
  (org-publish-use-timestamps-flag nil)
  (org-src-window-setup 'current-window)
  ;; (org-startup-folded "nofold")
  (org-startup-indented t)
  (org-yank-adjusted-subtrees t)

  (org-capture-templates
   '(("j" "Journal" entry
      (file+olp+datetree "journal.org")
      "* %?\n%i"
      :jump-to-captured t)))

  (org-publish-project-alist
   '(("org"
      :base-directory "~/org/"
      :base-extension "org"
      :publishing-function org-html-publish-to-html
      :publishing-directory "~/.www/org"
      :recursive t)
     ("org-roam"
      :base-directory "~/org-roam/"
      :base-extension "org"
      :publishing-function org-html-publish-to-html
      :publishing-directory "~/.www/org-roam"
      :recursive t)))

  :config
  (unless (file-directory-p org-directory)
    (make-directory org-directory))

  (add-to-list 'display-buffer-alist
               '("\\`\\*Org Select\\*\\|\\*Agenda Commands\\*\\'"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t))))


(use-package org-indent
  ;; It is part of `org'
  :defer t
  :after org
  :diminish org-indent-mode)


(use-package org-make-toc
  :ensure t
  :after org
  :hook (org-mode . org-make-toc-mode))


(use-package ox-gfm
  :ensure t
  :after org)


(use-package org-roam
  :ensure t
  :defer t
  :custom
  (org-roam-directory (file-truename "~/org-roam"))

  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ;; Dailies
         ("C-c n j" . org-roam-dailies-capture-today))

  :config
  (unless (file-directory-p org-roam-directory)
    (make-directory org-roam-directory))
  (setq org-roam-node-display-template
        (concat "${title:*} "
                (propertize "${tags:10}" 'face 'org-tag)))
  (org-roam-db-autosync-mode))


;; This is needed for `org-mode' to fontify code blocks.
(use-package htmlize
  :ensure t
  :defer t
  :after org)


(use-package markdown-mode
  :ensure t
  :mode (("\\.md\\'"       . gfm-mode)
         ("\\.markdown\\'" . markdown-mode))
  :hook (markdown-mode . markdown-toc-mode)
  :custom
  (markdown-command "multimarkdown")
  (markdown-nested-imenu-heading-index nil)
  (markdown-toc-header-toc-title "# Table of Contents"))


(use-package markdown-toc
  :ensure t
  :after markdown-mode
  :defer t
  :diminish
  :hook
  (markdown-mode
   . (lambda ()
       "Refresh the table of contents before saving the file.

This only affects the current markdown buffer, and does not add the
`before-save-hook' globally.
"
       (add-hook 'before-save-hook #'markdown-toc-refresh-toc t t))))


(use-package edit-indirect
  :ensure t
  :defer t)


(use-package paredit
  :disabled
  :ensure t
  :diminish
  :bind (:map lisp-mode-map       ("<return>" . paredit-newline))
  :bind (:map emacs-lisp-mode-map ("<return>" . paredit-newline))
  :hook ((emacs-lisp-mode lisp-interaction lisp-mode) . enable-paredit-mode))


(use-package aggressive-indent
  :ensure t
  :defer t
  :diminish
  :hook (emacs-lisp-mode . aggressive-indent-mode)
  :custom
  (aggressive-indent-dont-indent-if
   '((string-match "^\\s-+$" (thing-at-point 'line)))))


(use-package rainbow-delimiters
  :ensure t
  :defer t
  :hook ((prog-mode ielm-mode) . rainbow-delimiters-mode))


(use-package highlight-escape-sequences
  :ensure t
  :defer t
  :hook (prog-mode . hes-mode)
  :config
  (put 'hes-escape-backslash-face 'face-alias 'font-lock-builtin-face)
  (put 'hes-escape-sequence-face 'face-alias 'font-lock-builtin-face)
  (push `(json-mode . ,hes-js-escape-sequence-re) hes-mode-alist)
  (push `(enh-ruby-mode . ,hes-ruby-escape-sequence-keywords) hes-mode-alist))


(use-package git-link
  :ensure t
  :defer t
  :bind (("C-c g l" . git-link)
         ("C-c g c" . git-link-commit)
         ("C-c g h" . git-link-homepage))
  :custom
  (git-link-use-commit t))


(use-package magit
  :ensure t
  :defer t
  :config
  (add-to-list 'display-buffer-alist
               '("\\`magit:"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t)
                 (window-height . 0.5)))
  (add-to-list 'display-buffer-alist
               '("\\`magit-process:"
                 (display-buffer-in-direction)
                 (direction . right)))
  :custom
  (magit-commit-show-diff nil))


(use-package which-key
  :ensure t
  :defer 2
  :diminish
  :config
  (which-key-mode))


(use-package unfill
  :ensure t
  :defer t
  :bind ([remap fill-paragraph] . unfill-toggle))


(use-package reformatter
  :ensure t
  :defer t
  :functions reformatter-define
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*.*-format errors\\*\\'"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t)
                 (window-height lambda
                                (w)
                                (fit-window-to-buffer w
                                                      (/
                                                       (frame-height)
                                                       2)
                                                      10))))

  (reformatter-define clang-format
    :program "clang-format"
    :args (list "--assume-filename" (buffer-file-name)))
  (reformatter-define json-format
    :program "jq"
    :args '("." "--monochrome-output" "--indent" "2"))
  (reformatter-define nxml-format
    :program "tidy"
    :args '("-indent" "-wrap" "0" "-omit" "-quiet" "-utf8" "-xml"))
  (reformatter-define python-format
    :program "black"
    :args '("-"))
  (reformatter-define jsonnet-format
    :program "jsonnetfmt"
    :args '("-"))
  (reformatter-define terraform-format
    :program "terraform"
    :args '("fmt" "-no-color" "-"))

  :hook
  (c-mode-common
   . (lambda ()
       (bind-key "<f12>" #'clang-format-buffer c-mode-base-map)))
  (json-mode
   . (lambda ()
       (bind-key "<f12>" #'json-format-buffer json-mode-map)))
  (nxml-mode
   . (lambda ()
       (bind-key "<f12>" #'nxml-format-buffer nxml-mode-map)))
  (python-mode
   . (lambda ()
       (bind-key "<f12>" #'python-format-buffer python-mode-map)))
  (jsonnet-mode
   . (lambda ()
       (bind-key "<f12>" #'jsonnet-format-buffer jsonnet-mode-map)))
  (terraform-mode
   . (lambda ()
       (bind-key "<f12>" #'terraform-format-buffer terraform-mode-map))))


(use-package google-c-style
  :ensure t
  :defer t
  :hook
  (c-mode-common
   . (lambda ()
       (google-set-c-style)
       (google-make-newline-indent))))


(use-package prog-mode
  :defer t
  :preface
  (defun indent-delete-trailing-whitespace (&optional beg end)
    "Delete trailing whitespace and indent for selected region. If
no region is activated, this will operate on the entire buffer."
    (interactive
     (progn
       (barf-if-buffer-read-only)
       (if (use-region-p)
           (list (region-beginning) (region-end))
         (list (point-min) (point-max)))))
    (save-excursion
      (unless (eq beg end)
        (delete-trailing-whitespace beg end)
        (indent-region beg end))))

  :hook
  (prog-mode
   . (lambda ()
       (setq-local comment-auto-fill-only-comments t)
       (font-lock-add-keywords
        nil '(("\\<\\(FIXME\\|DEBUG\\|TODO\\):"
               1 font-lock-warning-face prepend)))))

  :bind (:map prog-mode-map
              ("<f12>" . indent-delete-trailing-whitespace)))


(use-package conf-mode
  :defer t
  :hook
  (conf-mode
   . (lambda ()
       (electric-indent-local-mode -1)
       ;; Just change the value of `indent-line-function' to the
       ;; `insert-tab' function and configure tab insertion as 4 spaces.
       ;; https://stackoverflow.com/a/1819405
       (setq-local indent-line-function #'insert-tab)))

  :mode
  (("/\\.htaccess\\'"        . conf-unix-mode)
   ("/\\.tmux\\.conf\\'"     . conf-unix-mode)
   ("/\\.aws/credentials\\'" . conf-unix-mode)
   ("/\\.properties\\'"      . conf-javaprop-mode)))


(use-package lisp-mode
  :defer t
  :hook
  (emacs-lisp-mode
   . (lambda ()
       (add-hook 'after-save-hook #'check-parens nil t)))

  :preface
  (defun describe-symbol-at-point ()
    "Describe the symbol at point."
    (interactive)
    (describe-symbol (or (symbol-at-point)
                         (user-error "No symbol at point"))))

  :bind (:map emacs-lisp-mode-map
              ("C-q" . describe-symbol-at-point)))


(use-package make-mode
  :defer t
  :mode ("/Makefile\\..*" . makefile-gmake-mode)
  :hook
  (makefile-mode . (lambda () (setq-local indent-tabs-mode t))))


(use-package sh-script
  :mode ("\\.zsh_custom\\'" . sh-mode)
  :defer t
  :custom
  (sh-basic-offset 2))


(use-package cc-mode
  :defer t
  :bind
  (:map c-mode-base-map
        ("M-q" . c-fill-paragraph))

  :mode (("\\.h\\(h?\\|xx\\|pp\\)\\'" . c++-mode)
         ("\\.m\\'"                   . c-mode)
         ("\\.mm\\'"                  . c++-mode))
  :hook
  (c-mode-common . cwarn-mode)

  :config
  (unbind-key "C-c C-c" c++-mode-map))


(use-package python
  :interpreter ("python" . python-mode)
  :mode ("\\.pyx?\\'" . python-mode)
  :defer t)


(use-package nxml-mode
  :defer t
  :hook
  (nxml-mode
   . (lambda ()
       (setq-local indent-line-function #'nxml-indent-line)
       (when (and
              buffer-file-name
              (file-exists-p buffer-file-name)
              (string= (file-name-extension
                        (file-name-nondirectory buffer-file-name))
                       "plist"))
         (setq-local indent-tabs-mode t)
         (setq-local nxml-child-indent 4)
         (setq-local nxml-outline-child-indent 4))))

  :custom
  (nxml-child-indent 2)
  (nxml-outline-child-indent 2)
  (nxml-slash-auto-complete-flag t)

  :config
  (require 'sgml-mode))


(use-package js
  :if (>= emacs-major-version 27)
  :defer t
  :mode ("\\.pac\\'" . js-mode)
  :mode ("\\.jsx?\\'" . js-jsx-mode)
  :custom
  (js-indent-level 2))


(use-package ruby-mode
  :disabled
  :defer t
  :interpreter "ruby")


(use-package enh-ruby-mode
  :ensure t
  :defer t
  :mode "\\(?:\\.rb\\|ru\\|rake\\|thor\\|jbuilder\\|gemspec\\|podspec\\|/\\(?:Gem\\|Rake\\|Cap\\|Thor\\|Vagrant\\|Guard\\|Pod\\)file\\)\\'"
  :interpreter "ruby"
  :hook
  (enh-ruby-mode . (lambda () (setq-local tab-width 2)))
  :custom
  (enh-ruby-check-syntax nil))


(use-package lua-mode
  :ensure t
  :defer t
  :interpreter ("lua" . lua-mode)
  :mode "\\.lua\\.erb\\'"
  :custom
  (lua-indent-level 2)
  (lua-indent-nested-block-content-align nil))


(use-package go-mode
  :ensure t
  :defer t
  :bind
  (:map go-mode-map ("<f12>" . gofmt))
  :hook
  (go-mode
   . (lambda ()
       (setq-local indent-tabs-mode t)
       (setq-local tab-width 4)
       (add-hook 'before-save-hook #'gofmt t t)))
  :custom
  (gofmt-command "goimports")
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*\\(Gofmt Errors\\|go-rename\\)\\*\\'"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t)
                 (window-height lambda
                                (w)
                                (fit-window-to-buffer w
                                                      (/
                                                       (frame-height)
                                                       2)
                                                      10)))))


(use-package go-rename
  :ensure t
  :after go-mode)


(use-package rust-mode
  :ensure t
  :defer t
  :bind
  (:map rust-mode-map ("<f12>" . rust-format-buffer))
  :custom
  (rust-format-on-save t))


(use-package vimrc-mode
  :ensure t
  :defer t)


(use-package yaml-mode
  :ensure t
  :defer t
  :mode "/\\.config/yamllint/config\\'"
  :mode "/\\(group\\|host\\)_vars/"
  :mode "/\\.flyrc\\'"
  :mode "/\\.clang-format\\'")


(use-package terraform-mode
  :ensure t
  :defer t
  :hook (terraform-mode . turn-off-auto-fill))


(use-package protobuf-mode
  :ensure t
  :defer t
  :hook
  (protobuf-mode
   . (lambda ()
       (c-add-style "my-protobuf-style"
                    '((c-basic-offset   . 2)
                      (indent-tabs-mode . nil))
                    t))))


(use-package json-mode
  :ensure t
  :defer t
  :hook
  (json-mode . (lambda () (setq-local tab-width 2))))


(use-package jsonnet-mode
  :ensure t
  :bind (:map jsonnet-mode-map
              ("M-." . jsonnet-jump))
  :defer t
  :mode "\\.\\(jsonnet\\|libsonnet\\)\\'"
  :config
  ;; Unbind non-standard keybindings for `jsonnet-jump' and
  ;; `jsonnet-reformat-buffer'
  (unbind-key "C-c C-f" jsonnet-mode-map)
  (unbind-key "C-c C-r" jsonnet-mode-map)
  :custom
  (jsonnet-indent-level 2)
  (jsonnet-use-smie t))


(use-package jinja2-mode
  :ensure t
  :defer t)


(use-package dockerfile-mode
  :ensure t
  :defer t)


(use-package ssh-config-mode
  :ensure t
  :defer t
  :hook
  (ssh-config-mode
   . (lambda ()
       (setq-local indent-line-function #'indent-relative))))


(use-package cmake-mode
  :ensure t
  :defer t)


(use-package jenkinsfile-mode
  :ensure t
  :defer t)


(use-package plantuml-mode
  :ensure t
  :defer t
  :custom
  (plantuml-jar-path "~/plantuml.jar")
  (plantuml-default-exec-mode 'jar)
  (plantuml-indent-level 2))


(use-package zenburn-theme
  :disabled
  :ensure t
  :init
  (unless (display-graphic-p)
    (setq zenburn-override-colors-alist
          '(("zenburn-bg" . "unspecified-bg")
            ("zenburn-fg" . "unspecified-fg"))))
  :config
  (load-theme 'zenburn t)
  ;; (zenburn-with-color-variables
  ;;  (custom-set-faces
  ;;   '(eglot-mode-line ((t (:inherit font-lock-constant-face :weight normal))))))
  )


(use-package color-theme-sanityinc-tomorrow
  :ensure t
  :config
  (load-theme 'sanityinc-tomorrow-night t)
  ;; (set-face-attribute 'font-lock-comment-delimiter-face nil :slant 'normal)
  ;; (set-face-attribute 'font-lock-comment-face nil :slant 'normal)
  ;; (unless (display-graphic-p)
  ;;   (set-face-attribute 'default nil :background "unspecified-bg"))
  :custom
  (custom-safe-themes t))


(when (display-graphic-p)
  (add-hook 'after-init-hook
            #'(lambda ()
                ;; Set frame font
                (cond
                 ((equal system-type 'gnu/linux)
                  (set-face-attribute
                   'default nil :font
                   "-*-Hack-regular-normal-normal-*-16-*-*-*-*-0-iso10646-1"))
                 ((equal system-type 'darwin)
                  (set-face-attribute
                   'default nil :font
                   "-*-Menlo-regular-normal-normal-*-14-*-*-*-*-0-iso10646-1")))
                (set-frame-parameter nil 'fullscreen 'maximized))
            t))


;;
;; Configure additional keybindings
;;
(defun close-help-or-keyboard-quit ()
  "Close *Help* window if visible, otherwise `keyboard-quit'."
  (interactive)
  (if-let ((win (get-buffer-window "*Help*")))
      (quit-window nil win)
    (keyboard-quit)))

;; `C-g' is `keyboard-quit' by default, but I want it to close the
;; *Help* window if it's visible.
(bind-key "C-g" #'close-help-or-keyboard-quit)
;; `C-x k' is `kill-buffer' by default.
(bind-key "C-x k" #'kill-current-buffer)
;; `C-z' is `suspend-frame' by default, but I don't use it and might
;; accidentally suspend Emacs.
(when (display-graphic-p) (unbind-key "C-z"))

;; GC was suspended in the early-init.el during startup to speed up
;; initialization. Restore GC config and run GC after Emacs startup.
;; `after-init-hook' runs right after your init file is loaded, but
;; before the initial frame is fully set up and before the startup
;; screen/scratch buffer is displayed.
;; `emacs-startup-hook' runs after `after-init-hook', and after the
;; command-line has been fully processed, the startup screen has been
;; displayed, and everything is ready.
(add-hook 'after-init-hook
          #'(lambda ()
              (setq gc-cons-percentage 0.5
                    gc-cons-threshold (* 128 1024 1024))
              (garbage-collect))
          t)

;;
;; Display elapsed time and GC count
;;
;; https://github.com/jwiegley/dot-emacs/blob/master/init.org
(defun report-time-since-load (&optional suffix)
  (message "Loading init...done (%.3fs) (GC: %d)%s"
           (float-time (time-subtract (current-time) emacs-start-time))
           gcs-done
           (or suffix "")))

(add-hook 'after-init-hook
          #'(lambda () (report-time-since-load " [after-init]"))
          t)

(report-time-since-load)
