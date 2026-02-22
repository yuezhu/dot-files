;;; early-init.el --- ... -*- lexical-binding: t -*-

;; Disable native compilation entirely
(setq native-comp-speed -1
      native-comp-jit-compilation nil)

;; GC runs when new allocations since the last GC exceed a
;; threshold: max(gc-cons-threshold, gc-cons-percentage * heap-size)
;; Suppress GC during init
(setq gc-cons-threshold most-positive-fixnum)

;; Disable UI elements early
;; https://github.com/doomemacs/doomemacs/blob/master/lisp/doom-start.el#L110
(push '(menu-bar-lines . 0)   default-frame-alist)
(push '(tool-bar-lines . 0)   default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
