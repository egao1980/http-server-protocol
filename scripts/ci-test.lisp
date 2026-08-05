;;;; Phase 2: load + test (Hunchentoot backend).

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

(setf asdf:*compile-file-failure-behaviour* :warn)

(defun call-with-ci-muffles (fn)
  #+sbcl
  (handler-bind ((sb-ext:defconstant-uneql
                  (lambda (c)
                    (let ((r (find-restart 'continue c)))
                      (when r (invoke-restart r))))))
    (funcall fn))
  #-sbcl
  (funcall fn))

(call-with-ci-muffles (lambda () (asdf:load-system "cl-repository-client")))
(cl-repository-client/asdf-integration:configure-asdf-source-registry)
(call-with-ci-muffles
 (lambda ()
   (cl-repository-client/asdf-integration:load-system-init-files)))

(call-with-ci-muffles
 (lambda ()
   (dolist (n '("rove" "alexandria" "bordeaux-threads" "usocket"
                "hunchentoot" "clack-handler-hunchentoot" "clack-socket"
                "chunga" "cl-fad" "md5" "rfc2388" "trivial-backtrace"
                "flexi-streams" "split-sequence" "cl-ppcre" "cl-base64"))
     (unless (asdf:find-system n nil)
       (format t "~&; ci: ensure ~a~%" n)
       (ignore-errors (cl-repo:ensure-systems (list n)))
       (unless (asdf:find-system n nil)
         (format t "~&; ci: ql fallback ~a~%" n)
         (ignore-errors (ql:quickload n :silent t)))))
   (asdf:load-system "http-server-backend-hunchentoot")
   (asdf:test-system "http-server-protocol")))

(format t "~&; ci: tests ok~%")
(uiop:quit 0)
