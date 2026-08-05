(in-package #:http-server-protocol/tests)

(defun %free-port ()
  "Ask the OS for an ephemeral port."
  (let* ((sock (usocket:socket-listen "127.0.0.1" 0 :reuseaddress t))
         (port (usocket:get-local-port sock)))
    (usocket:socket-close sock)
    port))

(defun %http-get (host port path)
  (let* ((sock (usocket:socket-connect host port :element-type 'character
                                       :timeout 5))
         (stream (usocket:socket-stream sock)))
    (unwind-protect
         (progn
           (format stream "GET ~a HTTP/1.0~c~cHost: ~a~c~cConnection: close~c~c~c~c"
                   path #\return #\linefeed host
                   #\return #\linefeed #\return #\linefeed
                   #\return #\linefeed)
           (finish-output stream)
           (with-output-to-string (out)
             (loop for line = (read-line stream nil nil)
                   while line
                   do (write-line line out))))
      (ignore-errors (usocket:socket-close sock)))))

(defun %echo-app (env)
  (declare (ignore env))
  '(200 (:content-type "text/plain") ("ok")))

(deftest serve-get-ok
  (let* ((port (%free-port))
         (server (srv:serve #'%echo-app :host "127.0.0.1" :port port
                            :background t)))
    (unwind-protect
         (progn
           (ok (srv:running-p server))
           (sleep 0.15)
           (let ((body (%http-get "127.0.0.1" port "/")))
             (ok (search "200" body))
             (ok (search "ok" body))))
      (srv:stop server)
      (ok (not (srv:running-p server))))))

(deftest with-server-stops
  (let ((port (%free-port))
        (saw nil))
    (srv:with-server (s #'%echo-app :host "127.0.0.1" :port port)
      (setf saw (srv:running-p s))
      (sleep 0.1)
      (ok (search "ok" (%http-get "127.0.0.1" port "/"))))
    (ok saw)))

(deftest stop-idempotent
  (let* ((port (%free-port))
         (s (srv:serve #'%echo-app :host "127.0.0.1" :port port)))
    (srv:stop s)
    (ok (not (srv:running-p s)))
    (srv:stop s)
    (ok (not (srv:running-p s)))))
