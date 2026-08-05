;;;; Install Woo backend deps (Unix / libev CI job).

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

(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(call-with-ci-muffles
 (lambda ()
   (cl-repo:ensure-system-dependencies "http-server-backend-woo"
     :with '("http-server-protocol" "rove" "usocket")
     :sources '(("rove" :ql)
                ("alexandria" :ql)
                ("bordeaux-threads" :ql)
                ("cl-ppcre" :ql)
                ("flexi-streams" :ql)
                ("split-sequence" :ql)
                ("trivial-features" :ql)))))

(format t "~&; ci: woo install phase done~%")
(uiop:quit 0)
