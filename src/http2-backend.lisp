(in-package #:http-server-backend-http2)

;;; Clack env in, H2 multiplex out via zellerin `http2/server` + clack/http2.lisp.
;;; Requires TLS certs. http2/server/threaded may fail to load on Windows (grovel).

(defclass http2-server-backend (http-server-protocol:http-server-backend) ())

(defclass http2-server (http-server-protocol:http-server)
  ((ssl-cert :initarg :ssl-cert :initform nil :accessor http2-server-ssl-cert)
   (ssl-key :initarg :ssl-key :initform nil :accessor http2-server-ssl-key)
   (handler :initform nil :accessor http2-server-handler)))

(defun make-http2-server-backend ()
  (make-instance 'http2-server-backend))

(defun use-http2-server-backend ()
  (setf http-server-protocol:*http-server-backend* (make-http2-server-backend)))

(defun http2-server-available-p ()
  (and (ignore-errors (asdf:load-system "http2/server/threaded") t)
       (ignore-errors (asdf:load-system "clack") t)
       (let ((root (ignore-errors (asdf:system-source-directory "http2/core"))))
         (when root
           (probe-file (merge-pathnames "clack/http2.lisp" root))))))

(defun %ensure-clack-http2 ()
  (asdf:load-system "http2/server/threaded")
  (asdf:load-system "clack")
  (let* ((root (asdf:system-source-directory "http2/core"))
         (file (merge-pathnames "clack/http2.lisp" root)))
    (unless (probe-file file)
      (error 'http-server-protocol:http-server-start-error
             :message "http2 clack/http2.lisp not found"))
    (load file :verbose nil)))

(defmethod http-server-protocol:backend-make-server
    ((backend http2-server-backend) &key host port app ssl-cert ssl-key backlog)
  (declare (ignore backlog))
  (make-instance 'http2-server
                 :host host :port port :app app
                 :ssl-cert ssl-cert :ssl-key ssl-key))

(defmethod http-server-protocol:start ((server http2-server) &key (background t))
  (unless (and (http2-server-ssl-cert server) (http2-server-ssl-key server))
    (error 'http-server-protocol:http-server-start-error
           :message "HTTP/2 server requires :ssl-cert and :ssl-key"))
  (%ensure-clack-http2)
  (let ((clackup (find-symbol "CLACKUP" :clack)))
    (setf (http2-server-handler server)
          (funcall clackup
                   (http-server-protocol:server-app server)
                   :server :http2
                   :address (http-server-protocol:server-host server)
                   :port (http-server-protocol:server-port server)
                   :ssl-key-file (namestring (http2-server-ssl-key server))
                   :ssl-cert-file (namestring (http2-server-ssl-cert server))
                   :use-thread background))
    (http-server-protocol:mark-running server t)
    server))

(defmethod http-server-protocol:stop ((server http2-server) &key soft)
  (declare (ignore soft))
  (let ((stop (and (find-package :clack) (find-symbol "STOP" :clack)))
        (handler (http2-server-handler server)))
    (when (and stop handler)
      (ignore-errors (funcall stop handler))))
  (http-server-protocol:mark-running server nil)
  server)
