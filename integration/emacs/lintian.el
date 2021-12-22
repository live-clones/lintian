;; Thanks to bpalmer on Libera:#emacs for help with this module
(require 'shr)
(defcustom lintian-command "lintian" "*The path to the lintian executable")
;;;###autoload
(defun lintian-run-file
    (file) "Runs the lintian executable on the specified FILE."
  (interactive "fFile: ")
  (let
      ((newbuf
        (get-buffer-create "*packaging-hints*")))
    (switch-to-buffer newbuf)
    (erase-buffer)
    (call-process lintian-command nil newbuf nil "--exp-output" "format=html" file)
    (shr-render-region
     (point-min)
     (point-max))
    (goto-char (point-min))))
(provide 'lintian)
