;;; posacs.el --- POSIX functions for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Stéphane Marks <shipmints@gmail.com>
;; Maintainer: Stéphane Marks <shipmints@gmail.com>
;; Created: 2025-12-10
;; Version: 1.0
;; Package-Requires: ((emacs "28.1"))
;; URL: https://github.com/shipmints/posacs
;; Keywords: utilities

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Posacs provides a dynamically loaded native Emacs dynamic module that
;; exposes a few POSIX functions to Elisp including getenv, setenv, and
;; unsetenv.
;;
;; These functions are useful in situations where other Emacs native modules
;; depend on the POSIX environment variables in the Emacs process itself and
;; which may differ from the Emacs `process-environment`.  This can arise if
;; Emacs is launched via a GUI desktop such as macOS Dock, desktop icon, or
;; Spotlight Search, or GNU/Linux desktop that might not itself have the suite
;; of environment variables you prefer that would be established in your
;; terminal environment, for example.
;;
;; The popular https://github.com/purcell/exec-path-from-shell package imports
;; environment variables from a shell environment that it runs in a
;; subprocess, BUT, it loads those variable values into the Emacs
;; `process-environment` and not into the process POSIX environment, so that
;; doesn't help dynamic modules that use the in-process Emacs POSIX
;; environment.
;;
;; One real-world example is the popular spell-checker
;; https://github.com/minad/jinx.  Jinx's dynamic module loads `libenchant`
;; into the Emacs process itself.  If you want to use a directory structure
;; other than the default XDG config assumption, then you must change the
;; environment variable `ENCHANT_CONFIG_DIR` in advance of loading Jinx.
;; Using Emacs `setenv` will not achieve this on its own, affecting only the
;; Emacs `process-environment` which is used for subprocesses but not the
;; Emacs process POSIX environment proper.
;;
;; (posics-setenv "ENCHANT_CONFIG_DIR" "~/my-preferred-dictionary-directory")
;; needs to be run before loading Jinx.
;;
;; Jinx's dynamic module handling inspired the Posacs implementation.
;;
;; Installing Posacs requires a C compiler, which is discovered from the CC
;; environment variable, or from the PATH environment variable.  Posacs should
;; be compatible on GNU/Linux and macOS platforms.
;;
;; Loading Posacs via `require` is sufficient to compile and load its native
;; Emacs module and initialize the package for use.

;;; Code:

(defvar posacs--load-file-dir (expand-file-name
                               (file-name-directory load-file-name)))


(declare-function posacs--getenv "posacs-module")

(defun posacs-getenv (variable)
  "Return value of the environment VARIABLE.
Return a string, or nil if VARIABLE does not exist in process's POSIX
environment, not the Emacs `process-environment`."
  (posacs--getenv variable))

(declare-function posacs--setenv "posacs-module")

(defun posacs-setenv (variable value &optional update-process-environment)
  "Set the environment VARIABLE to VALUE.
If VARIABLE is nil or an empty string, do nothing, otherwise set
VARIABLE in the process's POSIX environment.  If
UPDATE-PROCESS-ENVIRONMENT is non-nil, also update
`process-environment`."
  (when (and (posacs--setenv variable value)
             update-process-environment)
    (setenv variable value)))

(declare-function posacs--unsetenv "posacs-module")

(defun posacs-unsetenv (variable &optional update-process-environment)
  "Unset the environment VARIABLE.
If VARIABLE is nil or an empty string, do nothing, otherwise unset
VARIABLE in the process's POSIX environment.  If
UPDATE-PROCESS-ENVIRONMENT is non-nil, also update
`process-environment`."
  (when (and (posacs--unsetenv variable)
             update-process-environment)
    (setenv variable)))

(defun posacs-load-module ()
  "Load posacs dynamic module; compile if necessary."
  (unless (fboundp #'posacs--getenv)
    (unless module-file-suffix
      (error "Posacs: Dynamic modules are not supported"))
    (let* ((mod-name (file-name-with-extension "posacs-module" module-file-suffix))
           (mod-file (or (locate-library mod-name 'nosuffix)
                         (locate-library mod-name 'nosuffix
                                         (list posacs--load-file-dir)))))
      (unless mod-file
        (let* ((cc (or (getenv "CC")
                       (seq-find #'executable-find '("gcc" "clang" "cc"))
                       (error "Posacs: No C compiler found")))
               (c-name (file-name-with-extension mod-name ".c"))
               (c-file (or (locate-library c-name t)
                           (expand-file-name c-name posacs--load-file-dir)))
               (default-directory (file-name-directory
                                   (or c-file
                                       (error "Posacs: %s not found" c-name))))
               (command
                `(,cc "-I." "-O2" "-Wall" "-Wextra" "-fPIC" "-shared"
                      "-o" ,mod-name ,c-name)))
          (with-current-buffer (get-buffer-create "*posacs module compilation*")
            (let ((inhibit-read-only t))
              (erase-buffer)
              (compilation-mode)
              (insert (string-join command " ") "\n")
              (if (equal 0 (apply #'call-process (car command) nil
                                  (current-buffer) t (cdr command)))
                  (insert (message "Posacs: %s compiled successfully" mod-name))
                (let ((msg (format "Posacs: Compilation of %s failed" mod-name)))
                  (insert msg)
                  (pop-to-buffer (current-buffer))
                  (error msg)))))
          (setq mod-file (expand-file-name mod-name))))
      (module-load mod-file))))

(posacs-load-module)

(provide 'posacs)

;;; posacs.el ends here
