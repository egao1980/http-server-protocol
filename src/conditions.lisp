(in-package #:http-server-protocol)

(define-condition http-server-error (error)
  ((message :initarg :message :reader http-server-error-message :initform nil))
  (:report (lambda (c s)
             (format s "http-server error: ~a"
                     (or (http-server-error-message c) c)))))

(define-condition http-server-bind-error (http-server-error) ())
(define-condition http-server-start-error (http-server-error) ())
(define-condition http-server-not-running (http-server-error) ())
