;; -*- lexical-binding: t; -*-

;; Disable native compilation entirely
(setq native-comp-speed -1
      native-comp-jit-compilation nil)

;; Set the garbage collector threshold, to avoid collections
;; To avoid collections while loading the `init.el', they must be set using
;; the `early-init.el'.
(setq gc-cons-percentage 0.5
      gc-cons-threshold (* 128 1024 1024))

;; Disable UI elements early
;; https://github.com/doomemacs/doomemacs/blob/master/lisp/doom-start.el#L110
(push '(menu-bar-lines . 0)   default-frame-alist)
(push '(tool-bar-lines . 0)   default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
