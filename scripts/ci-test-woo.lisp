;;;; Woo smoke (Ubuntu + libev).

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

#+win32
(progn
  (format t "~&; ci: woo skipped on Windows~%")
  (uiop:quit 0))

(call-with-ci-muffles (lambda () (asdf:load-system "cl-repository-client")))
(cl-repository-client/asdf-integration:configure-asdf-source-registry)
(call-with-ci-muffles
 (lambda ()
   (cl-repository-client/asdf-integration:load-system-init-files)))

(call-with-ci-muffles
 (lambda ()
   (asdf:load-system "http-server-backend-woo")
   (asdf:load-system "usocket")
   (uiop:symbol-call :http-server-backend-woo :use-woo-backend)
   (let* ((port
           (let* ((sock (usocket:socket-listen "127.0.0.1" 0 :reuseaddress t))
                  (p (usocket:get-local-port sock)))
             (usocket:socket-close sock)
             p))
          (app (lambda (env)
                 (declare (ignore env))
                 '(200 (:content-type "text/plain") ("woo-ok"))))
          (server (uiop:symbol-call :http-server-protocol :serve
                                    app :host "127.0.0.1" :port port
                                    :background t)))
     (unwind-protect
          (progn
            (sleep 0.25)
            (unless (uiop:symbol-call :http-server-protocol :running-p server)
              (error "woo server not running"))
            (let* ((sock (usocket:socket-connect "127.0.0.1" port
                                                 :element-type 'character
                                                 :timeout 5))
                   (stream (usocket:socket-stream sock))
                   (body nil))
              (unwind-protect
                   (progn
                     (format stream
                             "GET / HTTP/1.0~c~cHost: 127.0.0.1~c~cConnection: close~c~c~c~c"
                             #\return #\linefeed #\return #\linefeed
                             #\return #\linefeed #\return #\linefeed)
                     (finish-output stream)
                     (setf body (with-output-to-string (out)
                                  (loop for line = (read-line stream nil nil)
                                        while line
                                        do (write-line line out)))))
                (ignore-errors (usocket:socket-close sock)))
              (unless (and (search "200" body) (search "woo-ok" body))
                (error "woo GET failed: ~a" body))
              (format t "~&; ci: woo smoke ok~%")))
       (ignore-errors (uiop:symbol-call :http-server-protocol :stop server))))))

(uiop:quit 0)
