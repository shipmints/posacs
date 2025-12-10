# posacs: POSIX bindings for Emacs

Posacs provides a dynamically loaded native Emacs dynamic module that exposes a few POSIX functions to Elisp including getenv,
setenv, and unsetenv.

These functions are useful in situations where other Emacs native modules depend on the POSIX environment variables in the Emacs
process itself and which may differ from the Emacs `process-environment`. This can arise if Emacs is launched via a GUI desktop
such as macOS Dock, desktop icon, or Spotlight Search, or GNU/Linux desktop that might not itself have the suite of environment
variables you prefer that would be established in your terminal environment, for example.

The popular https://github.com/purcell/exec-path-from-shell package imports environment variables from a shell environment that it
runs in a subprocess, __but__, it loads those variable values into the Emacs `process-environment` and not into the process POSIX
environment, so that doesn't help dynamic modules that use the in-process Emacs POSIX environment.

# Installation & Configuration

Installing Posacs requires a C compiler, which is discovered from the CC environment variable, or from the PATH environment
variable. Posacs should be compatible on GNU/Linux, macOS platforms, and other Unix-like platforms.

Loading Posacs via `require` or `use-package` is sufficient to compile and load its native Emacs module and initialize the package
for use.

Posacs requires no additional configuration.

If and until Posacs is available via an Emacs archive, you can install it like this.
``` elisp
(use-package posacs
  :vc ( :url "https://github.com/shipmints/posacs.git"))
```

# Example & Example Usage

One real-world example is the popular spell-checker https://github.com/minad/jinx. Jinx's dynamic module loads `libenchant` into
the Emacs process itself. If you want to use a directory structure other than the default XDG config assumption, then you must
change the environment variable `ENCHANT_CONFIG_DIR` in advance of loading Jinx. Using Emacs `setenv` will not achieve this on its
own, affecting only the Emacs `process-environment` which is used for subprocesses but not the Emacs process POSIX environment
proper.

```elisp
(use-package posacs)

(use-package jinx
:after (posacs)
:init
  (posics-setenv "ENCHANT_CONFIG_DIR" "~/my-preferred-dictionary-directory")
:config
  (setq jinx-delay 0.3)
  (setq jinx-suggestion-distance 3)
  (setq jinx-menu-suggestions 10)
...
)
```

# Related Packages

If there were any, I'd have used them instead.

### Acknowledgments

The native module handling was inspired by Jinx.
