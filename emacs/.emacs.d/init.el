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
  '()
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


;; (use-package emacs ...) is a common idiom for configuring built-in
;; Emacs settings that don't belong to any specific package.  Since
;; "emacs" is not a real package, `use-package' treats it as always
;; loaded, so all forms (:init, :config, :custom) run immediately at
;; init time with no deferral.
;; Refer to lisp/loadup.el for the core libraries always loaded
;; during Emacs startup, and src/*.c for C-level primitives and
;; their default values.
(use-package emacs
  :diminish auto-fill-function

  :hook
  ((prog-mode protobuf-mode) . turn-on-auto-fill)
  :hook
  (text-mode . visual-line-mode)

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

  ;; simple.el
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

  (next-line-add-newlines nil)

  (visual-line-fringe-indicators
   '(left-curly-arrow right-curly-arrow))

  ;; startup.el
  ;; `simple' is one of Emacs's core built-in libraries. It provides a
  ;; large collection of fundamental editing commands and utilities
  ;; that are so basic they're loaded by default.
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
  :init
  (electric-indent-mode))


(use-package elec-pair
  :init
  (electric-pair-mode))


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
  :bind ("C-c s b" . flyspell-buffer)

  :preface
  ;; https://github.com/abo-abo/oremacs/blob/github/modes/ora-flyspell.el
  (defun flyspell-ignore-http-and-https ()
    "Function used for `flyspell-generic-check-word-predicate' to
ignore stuff starting with \"http\" or \"https\"."
    (save-excursion
      (forward-whitespace -1)
      (not (looking-at "[\t ]+https?\\b"))))

  :hook
  (text-mode . flyspell-mode)
  :custom
  (flyspell-sort-corrections t)
  :config
  (dolist (mode '(text-mode org-mode)) ;; need to specify all derived modes
    (put mode 'flyspell-mode-predicate #'flyspell-ignore-http-and-https)))


(use-package flyspell-correct
  :ensure t
  :after flyspell
  :bind (:map flyspell-mode-map
              ("C-c s w" . flyspell-correct-wrapper)))


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
  :defer t
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
  (imenu-max-item-length "Unlimited"))


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
  :init
  (vertico-mode)

  :hook
  (minibuffer-setup
   . (lambda ()
       "Allow `vertico' to use half the frame height."
       (setq-local vertico-count (/ (frame-height) 2))))

  :custom
  ;; (vertico-scroll-margin 0) ;; Different scroll margin
  ;; (vertico-count 20) ;; Show more candidates
  ;; (vertico-resize t) ;; Grow and shrink the Vertico minibuffer
  ;; (vertico-cycle t) ;; Enable cycling for `vertico-next/previous'
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
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ([remap Info-search] . consult-info)
         ;; C-x bindings in `ctl-x-map'
         ("C-x M-:" . consult-complex-command)     ;; orig. repeat-complex-command
         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab)    ;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
         ("C-x C-r" . consult-recent-file)
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store)          ;; orig. abbrev-prefix-mark (unrelated)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ;; ("M-y" . consult-yank-pop)                ;; orig. yank-pop
         ("M-y" . consult-yank-replace)
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g r" . consult-grep-match)
         ("M-g f" . consult-flymake)               ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)             ;; orig. goto-line
         ("M-g M-g" . consult-goto-line)           ;; orig. goto-line
         ("M-g o" . consult-outline)               ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-find)                  ;; Alternative: consult-fd
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
         ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)                 ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  ;; The :init configuration is always executed (Not lazy)
  :init

  ;; Tweak the register preview for `consult-register-load',
  ;; `consult-register-store' and the built-in commands.  This improves the
  ;; register formatting, adds thin separator lines, register sorting and hides
  ;; the window mode line.
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)

  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  ;; Configure other variables and modes in the :config section,
  ;; after lazily loading the package.
  :config

  ;; Explicitly require `recentf' in order to use `consult-recent-file'.
  (require 'recentf)

  ;; Optionally configure preview. The default value
  ;; is 'any, such that any key triggers the preview.
  ;; (setq consult-preview-key 'any)
  (setq consult-preview-key "M-.")
  ;; (setq consult-preview-key '("S-<down>" "S-<up>"))
  ;; For some commands and buffer sources it is useful to configure the
  ;; :preview-key on a per-command basis using the `consult-customize' macro.
  ;; (consult-customize
  ;;  consult-theme :preview-key '(:debounce 0.2 any)
  ;;  consult-ripgrep consult-git-grep consult-grep consult-man
  ;;  consult-bookmark consult-recent-file consult-xref
  ;;  consult-source-bookmark consult-source-file-register
  ;;  consult-source-recent-file consult-source-project-recent-file
  ;;  ;; :preview-key "M-."
  ;;  :preview-key '(:debounce 0.4 any))

  ;; Optionally configure the narrowing key.
  ;; Both < and C-+ work reasonably well.
  (setq consult-narrow-key "<") ;; "C-+"

  ;; Optionally make narrowing help available in the minibuffer.
  ;; You may want to use `embark-prefix-help-command' or which-key instead.
  ;; (keymap-set consult-narrow-map (concat consult-narrow-key " ?") #'consult-narrow-help)
  )


;; Enable rich annotations using the Marginalia package
(use-package marginalia
  :ensure t
  :after vertico

  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  :bind (:map minibuffer-local-map
              ("M-A" . marginalia-cycle))

  ;; The :init section is always executed.
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
  :after (embark consult))


(use-package corfu
  :ensure t
  :custom
  (corfu-auto nil)
  (corfu-min-width 80)
  (corfu-max-width corfu-min-width)     ; Always have the same width
  (corfu-count 14)
  (corfu-scroll-margin 4)
  (corfu-cycle nil)                ;; Enable cycling for `corfu-next/previous'

  :init
  (global-corfu-mode))


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
  ;; Bind prefix keymap providing all Cape commands under a mnemonic key.
  ;; Press C-c p ? to for help.
  :bind ("C-c p" . cape-prefix-map) ;; Alternative key: M-<tab>, M-p, M-+
  ;; Alternatively bind Cape commands individually.
  ;; :bind (("C-c p d" . cape-dabbrev)
  ;;        ("C-c p h" . cape-history)
  ;;        ("C-c p f" . cape-file)
  ;;        ...)
  :init
  ;; Add to the global default value of `completion-at-point-functions' which is
  ;; used by `completion-at-point'.  The order of the functions matters, the
  ;; first function returning a result wins.  Note that the list of buffer-local
  ;; completion functions takes precedence over the global list.
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block)
  ;; (add-hook 'completion-at-point-functions #'cape-history)
  ;; ...
  )


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

  :preface
  (defun org-babel-enable-languages (&rest langs)
    "Enable one or more org-babel languages.
Each element of LANGS should be a cons cell (STRING . SYMBOL),
e.g. (\"plantuml\" . plantuml).
Duplicates are skipped based on the language name (car)."
    (dolist (lang langs)
      (unless (assoc (car lang) org-babel-load-languages)
        (add-to-list 'org-babel-load-languages lang)))
    ;; Call `org-babel-do-load-languages' to ensure that the new
    ;; language is registered.
    (org-babel-do-load-languages 'org-babel-load-languages
                                 org-babel-load-languages))

  (defun org-copy-top-heading-id ()
    "Copy the org ID of the topmost heading of the current section to the
kill ring.  Displays the heading text in the minibuffer. If no ID
exists, does nothing."
    (interactive)
    (save-excursion
      (unless (org-before-first-heading-p)
        (org-back-to-heading t)
        (while (org-up-heading-safe))
        (let* ((heading (org-get-heading t t t t))
               (id (org-id-get)))
          (if (not id)
              (message "No org ID found for heading '%s'" heading)
            (kill-new id)
            (message "Copied ID for heading '%s': %s" heading id))))))

  :hook
  (org-capture-prepare-finalize . org-copy-top-heading-id)

  :custom
  ;; Root directory for all org files
  (org-directory "~/org")

  (org-agenda-files `(,(file-name-as-directory org-directory)))

  ;; (org-default-notes-file (concat
  ;;                          (file-name-as-directory org-directory)
  ;;                          "notes.org"))

  ;; Do not ask for confirmation when evaluating code blocks
  (org-confirm-babel-evaluate nil)

  (org-export-default-language "en")
  (org-export-with-creator t)
  (org-export-with-section-numbers nil)
  (org-export-with-sub-superscripts '{})

  ;; Include a table of contents in exported documents
  (org-export-with-toc t)

  ;; Do not hide markup characters (e.g. show bold instead of *bold*)
  (org-hide-emphasis-markers nil)

  ;; Hide the first N-1 stars in a headline
  (org-hide-leading-stars t)

  ;; Allow single character alphabetical bullets
  (org-list-allow-alphabetical t)
  (org-log-done 'time)
  (org-log-reschedule 'time)

  ;; Do no timestamp checking and always publish all files
  (org-publish-use-timestamps-flag nil)

  ;; When editing source code blocks, use the current window
  (org-src-window-setup 'current-window)

  ;; Visually indent content under headings to align with heading
  ;; text. No actual spaces are inserted; this is purely a display
  ;; effect.
  (org-startup-indented t)

  ;; Do not fold heading content on startup
  (org-startup-folded 'nofold)

  ;; Hide drawers (including :PROPERTIES:) on startup
  (org-hide-drawer-startup t)

  ;; Do not auto-break long lines when typing; keep paragraphs on one
  ;; line
  (org-auto-align-tags nil)

  ;; Display tags immediately after the heading text, without column
  ;; alignment
  (org-tags-column 0)

  ;; When creating a link to a heading, automatically assign an org ID
  ;; to it. This enables precise heading-level links.
  ;; (org-id-link-to-org-use-id t)
  ;; Remove ID property of clones of a subtree
  (org-clone-delete-id t)

  (org-yank-adjusted-subtrees t)

  (org-capture-templates
   '(("j" "Journal" entry
      (file+olp+datetree "journal.org")
      "* %?\n%i"
      :jump-to-captured t)))

  (org-publish-project-alist
   '(("org-file"
      :base-directory "~/org/"
      :base-extension "org"
      :publishing-function org-html-publish-to-html
      :publishing-directory "~/.www/org"
      :recursive t)
     ("org-static"
      :base-directory "~/org/"
      :base-extension "png\\|jpg\\|jpeg\\|gif\\|svg\\|css\\|pdf"
      :publishing-function org-publish-attachment
      :publishing-directory "~/.www/org/"
      :recursive t)
     ("org" :components ("org-file" "org-static"))
     ("org-roam-file"
      :base-directory "~/org-roam/"
      :base-extension "org"
      :publishing-function org-html-publish-to-html
      :publishing-directory "~/.www/org-roam"
      :recursive t)
     ("org-roam-static"
      :base-directory "~/org-roam/"
      :base-extension "png\\|jpg\\|jpeg\\|gif\\|svg\\|css\\|pdf"
      :publishing-function org-publish-attachment
      :publishing-directory "~/.www/org-roam/"
      :recursive t)
     ("org-roam" :components ("org-file" "org-static")))

   (org-todo-keywords
    '((sequence "TODO(t)" "IN-PROGRESS(i)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)"))))

  :config
  (make-directory org-directory t)

  ;; Make org agenda and org capture buffers appear at the bottom of
  ;; the frame, and prevent them from taking over the current window.
  (add-to-list 'display-buffer-alist
               '("\\`\\*Org Select\\*\\|\\*Agenda Commands\\*\\'"
                 (display-buffer-at-bottom)
                 (inhibit-same-window . t)))

  ;; Set the path to the PlantUML JAR file for org-babel. This allows
  ;; you to execute PlantUML code blocks in org files and have them
  ;; render diagrams using the specified JAR.
  (with-eval-after-load 'plantuml-mode
    (setq org-plantuml-jar-path plantuml-jar-path))

  ;; Enable execution of PlantUML code blocks in org files
  (org-babel-enable-languages '(plantuml . t)))


;; `org-indent-mode' is a minor mode that visually indents text
;; according to the outline structure of the document. It is bundled
;; with `org'; no separate :ensure needed.
(use-package org-indent
  :defer t
  :after org
  :diminish org-indent-mode)


;; `org-make-toc-mode' is a minor mode that automatically generates a
;; table of contents for an org file.
(use-package org-make-toc
  :ensure t
  :after org
  :hook (org-mode . org-make-toc-mode))


;; `ox-gfm' is an org export backend that exports to GitHub Flavored
;; Markdown.
(use-package ox-gfm
  :ensure t
  :after org)


;; `org-modern' is a minor mode that provides modern visual
;; enhancements for `org-mode'.
(use-package org-modern
  :ensure t
  :after org
  :defer t)


;; `ob-mermaid' is an org-babel language extension that allows you to
;; execute Mermaid code blocks in org files and have them render
;; diagrams.
(use-package ob-mermaid
  :ensure t
  :after org
  :config
  ;; Enable execution of Mermaid code blocks in org files
  (org-babel-enable-languages '(mermaid . t)))


;; `org-roam' is a note-taking tool that allows you to create and
;; manage a network of interconnected notes.
(use-package org-roam
  :ensure t
  :defer t
  :preface
  (defun org-roam-node-hierarchy (node)
    "Return full hierarchy path for NODE."
    (let ((title (org-roam-node-title node))
          (olp (org-roam-node-olp node))
          (file-title (org-roam-node-file-title node)))
      (string-join
       (delq nil
             (append
              (when (and file-title (not (string= file-title title)))
                (list file-title))
              olp
              (list title)))
       " > ")))

  :custom
  ;; Root directory that `org-roam' files; all node files live here
  (org-roam-directory "~/org-roam")

  ;; Location of the SQLite database that indexes all nodes and links
  (org-roam-db-location "~/org-roam/org-roam.db")

  ;; Automatically update the database whenever a roam file is saved.
  ;; This keeps backlinks accurate in real time at a small cost to
  ;; save speed.
  (org-roam-db-update-on-save t)

  ;; Allow org headings that have an :ID: property to be treated as
  ;; first-class roam nodes, not just the file-level #+title node.
  ;; This is what makes it possible to link to a specific meeting-log
  ;; heading (e.g. "** 2026-03-01") rather than just the top of the
  ;; meeting file.
  (org-roam-db-node-include-refs t)

  ;; Control how each node appears in the completion list shown by
  ;; `org-roam-node-find' and `org-roam-node-insert'.
  (org-roam-node-display-template
   (concat "${hierarchy:*} " (propertize "${tags:40}" 'face 'bold)))

  ;; Subdirectory for daily note files, relative to
  ;; org-roam-directory.  Resolves to ~/org/roam/daily/
  (org-roam-dailies-directory "daily/")

  (org-roam-capture-templates
   '(
     ;; Default Notes
     ("d" "Default" plain
      "%?"
      ;; ${slug} is the URL-safe version of ${title}:
      ;; spaces become hyphens, special characters are dropped.
      ;; e.g. title "My Project Notes" → slug "my-project-notes"
      :target (file+head
               "%<%Y%m%d%H%M%S>-${slug}.org"
               "#+title: ${title}
#+created: %T
")
      :unnarrowed t)

     ;; Meeting Notes
     ;;
     ;; Single template that handles both first-time creation and
     ;; subsequent appends for the same meeting node.
     ;;
     ;; First run (file does not exist): `org-roam' prompts for a
     ;;   title, then file+head+olp creates the file using the header
     ;;   template (which includes the Context section, prompted by
     ;;   %^{Context}), creates the "Meeting Notes" heading, and
     ;;   inserts the first dated entry.
     ;;
     ;; Later runs (file already exists): The header template is
     ;;   skipped entirely. `org-roam' finds the existing file via the
     ;;   title search, navigates to "Meeting Notes", and appends a
     ;;   new dated entry with a freshly generated ID.  The
     ;;   %^{Context} prompt does NOT appear because they live inside
     ;;   the header which is now ignored.
     ("m" "Meeting Notes" entry
      ;; entry type: `org-capture' prepends "* " automatically, so
      ;; this content becomes a sub-heading under "Meeting Notes".
      ;; %^u pops up a calendar; the chosen date becomes the heading
      ;; title.  Using inactive timestamp so individual meeting
      ;; headings do not flood the org agenda.
      ;; %(org-id-new) is evaluated at expansion time and produces a
      ;; %UUID.
      "
* %^u
:PROPERTIES:
:ID:       %(org-id-new)
:END:
%?"
      :target (file+head+olp
               ;; path: node files go into the meetings/ subdirectory
               "meetings/${slug}.org"
               ;; header: used only when the file is created for the
               ;; first time; %^{} prompts appear here because this is
               ;; first-run only
               "
#+title: ${title}
#+filetags: :meeting:

* Context
%^{Context}

* Meeting Notes
"
               ;; olp: always insert under the "Meeting Notes" heading
               ("Meeting Notes"))
      :prepend t)
     ))

  ;; These are separate from `org-roam-capture-templates' and are
  ;; only triggered by org-roam-dailies-* commands.
  ;; The :target path is relative to `org-roam-dailies-directory'.
  (org-roam-dailies-capture-templates
   '(
     ;; Timestamped daily journal entry
     ("d" "Daily Journal" entry
      ;; A top-level heading with the current time as its title
      "* %<%H:%M> %?"
      :target (file+head "%<%Y-%m-%d>.org"
                         "
#+title: %<%Y-%m-%d>
#+filetags: :daily:
"))

     ;; Meeting Notes reference entry
     ;;
     ;; Use this after finishing a meeting capture (template "m"
     ;; above). By the time you trigger this template the meeting ID
     ;; should be copied to the clipboard, so you only need to type
     ;; C-c C-l → id: → C-y to paste it as a link.
     ;;
     ;; Workflow:
     ;;   1. C-c n c → m          capture the meeting entry (ID auto-copied)
     ;;   2. C-c n d c → l        open this template in today's daily
     ;;   3. at the Link: line:   C-c C-l → type "id:" → C-y to paste the ID
     ;;                           → RET → type a description → RET
     ;;   4. C-c C-c              confirm and save
     ("l" "Meeting Link" entry
      ;; %^{Meeting name} prompts for the meeting name used as the heading title
      "
* %?"
      :target (file+head+olp
               "%<%Y-%m-%d>.org"
               "
#+title: %<%Y-%m-%d>
#+filetags: :daily:
"
               ;; All meeting references in a daily go under the
               ;; "Meetings" section
               ("Meetings")))
     ))

  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)

         ;; `org-roam-dailies' commands
         ("C-c n d t" . org-roam-dailies-goto-today)      ;; open today's daily note
         ("C-c n d y" . org-roam-dailies-goto-yesterday)  ;; open yesterday's daily note
         ("C-c n d c" . org-roam-dailies-capture-today)   ;; capture into today's daily
         ("C-c n d n" . org-roam-dailies-goto-next-note)  ;; navigate to the next day
         ("C-c n d p" . org-roam-dailies-goto-prev-note)  ;; navigate to the previous day
         )

  :config
  ;; Ensure the meetings/ subdirectory exists. The Meeting Notes
  ;; capture template expects to find it.
  (make-directory (concat (file-name-as-directory org-roam-directory)
                          "meetings")
                  t)

  ;; Start the background process that keeps the database in sync with
  ;; files on disk
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
  (push `(json-mode . ,hes-js-escape-sequence-re) hes-mode-alist))


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
              ("C-q" . describe-symbol-at-point))

  :custom
  (emacs-lisp-docstring-fill-column fill-column))


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
