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
