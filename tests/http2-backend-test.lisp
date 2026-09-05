(in-package #:http-server-backend-http2/tests)

(deftest backend-class
  (ok (typep (make-http2-server-backend) 'http2-server-backend)))

(deftest make-server-needs-certs-on-start
  (let* ((b (make-http2-server-backend))
         (s (http-server-protocol:backend-make-server
             b :host "127.0.0.1" :port 1
             :app (lambda (env) (declare (ignore env)) '(200 nil ("ok"))))))
    (ok (typep s 'http2-server))
    (ok (signals (http-server-protocol:start s)
                 'http-server-protocol:http-server-start-error))))

(deftest connect-method-p-accepts-keyword-and-string
  (ok (connect-method-p :connect))
  (ok (connect-method-p "CONNECT"))
  (ok (connect-method-p :CONNECT))
  (ng (connect-method-p :get))
  (ng (connect-method-p "POST")))

(deftest extended-connect-request-p-from-env
  (let ((headers (make-hash-table :test 'equal)))
    (setf (gethash "protocol" headers) "websocket")
    (ok (extended-connect-request-p
         (list :request-method :connect :headers headers)))
    (ok (extended-connect-request-p
         (list :request-method "CONNECT" :protocol "websocket")))
    (ng (extended-connect-request-p
         (list :request-method :connect :protocol "connect-udp")))
    (ng (extended-connect-request-p
         (list :request-method :get :protocol "websocket")))))

(deftest env-connect-protocol-reads-headers
  (let ((headers (make-hash-table :test 'equal)))
    (setf (gethash "protocol" headers) "websocket")
    (ok (equal "websocket"
               (env-connect-protocol (list :headers headers))))
    (ok (equal "websocket"
               (env-connect-protocol (list :protocol "websocket"))))))

(deftest enable-connect-protocol-in-settings
  (if (not (http2-server-available-p))
      (skip "http2/server/threaded not loadable")
      (progn
        (ensure-http2-connect-classes)
        (let* ((get-settings (find-symbol "GET-SETTINGS" :http2/core))
               (conn (ignore-errors
                       (make-instance 'http2-connect-connection
                                      :app (lambda (env)
                                             (declare (ignore env))
                                             '(200 nil nil)))))
               (settings (and conn get-settings
                              (ignore-errors (funcall get-settings conn)))))
          (if (null settings)
              (skip "could not instantiate http2-connect-connection")
              (ok (eql 1 (cdr (assoc :enable-connect-protocol settings)))))))))

(deftest add-header-accepts-protocol-pseudo
  (if (not (http2-server-available-p))
      (skip "http2/server/threaded not loadable")
      (progn
        (ensure-http2-connect-classes)
        (let* ((add (find-symbol "ADD-HEADER" :http2/core))
               (conn (ignore-errors
                       (make-instance 'http2-connect-connection
                                      :app (lambda (env)
                                             (declare (ignore env))
                                             '(200 nil nil)))))
               (stream (and conn
                            (ignore-errors
                              (make-instance 'http2-connect-stream
                                             :connection conn)))))
          (if (not (and add stream))
              (skip "could not instantiate http2-connect-stream")
              (progn
                (funcall add conn stream :protocol "websocket")
                (ok (equal "websocket" (http2-stream-protocol stream)))
                (funcall add conn stream ":protocol" "websocket")
                (ok (equal "websocket" (http2-stream-protocol stream)))
                (ok (equal "websocket"
                           (gethash "protocol"
                                    (http2-stream-request-headers stream))))))))))
