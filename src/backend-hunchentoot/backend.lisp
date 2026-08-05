(in-package #:http-server-backend-hunchentoot)

;;; Uses clack.handler.hunchentoot's acceptor class + hunchentoot:start/stop
;;; so BACKGROUND works (clack.handler.hunchentoot:run joins the accept thread).

(defclass hunchentoot-backend (http-server-backend) ())

(defclass hunchentoot-server (http-server)
  ((acceptor :initform nil :accessor %acceptor)
   (ssl-cert :initarg :ssl-cert :initform nil :reader %ssl-cert)
   (ssl-key :initarg :ssl-key :initform nil :reader %ssl-key)))

(defun make-hunchentoot-backend ()
  (make-instance 'hunchentoot-backend))

(defun use-hunchentoot-backend ()
  "Bind *HTTP-SERVER-BACKEND* to Hunchentoot. Returns the backend."
  (setf *http-server-backend* (make-hunchentoot-backend)))

(defun %clack-acceptor-class (&key ssl)
  (if ssl
      (find-symbol "CLACK-SSL-ACCEPTOR" :clack.handler.hunchentoot)
      (find-symbol "CLACK-ACCEPTOR" :clack.handler.hunchentoot)))

(defmethod backend-make-server ((backend hunchentoot-backend)
                                &key (host "127.0.0.1") (port 8080) app
                                  ssl-cert ssl-key backlog)
  (declare (ignore backlog))
  (unless app
    (error 'http-server-start-error :message "APP is required"))
  (make-instance 'hunchentoot-server
                 :host host :port port :app app
                 :ssl-cert ssl-cert :ssl-key ssl-key))

(defmethod start ((server hunchentoot-server) &key (background t))
  (declare (ignore background))
  (when (server-running-p server)
    (return-from start server))
  (let* ((init (find-symbol "INITIALIZE" :clack.handler.hunchentoot))
         (ssl (and (%ssl-cert server) (%ssl-key server)))
         (class (%clack-acceptor-class :ssl ssl)))
    (unless class
      (error 'http-server-start-error
             :message "clack.handler.hunchentoot acceptor class not found"))
    (when init (funcall init))
    (let ((acceptor
            (if ssl
                (make-instance class
                               :app (server-app server)
                               :address (server-host server)
                               :port (server-port server)
                               :ssl-certificate-file (%ssl-cert server)
                               :ssl-privatekey-file (%ssl-key server)
                               :access-log-destination nil
                               :persistent-connections-p t)
                (make-instance class
                               :app (server-app server)
                               :address (server-host server)
                               :port (server-port server)
                               :access-log-destination nil
                               :error-template-directory nil
                               :persistent-connections-p t))))
      (handler-case
          (progn
            (hunchentoot:start acceptor)
            (setf (%acceptor server) acceptor)
            (mark-running server t))
        (error (e)
          (error 'http-server-bind-error
                 :message (format nil "hunchentoot start failed: ~a" e))))))
  server)

(defmethod stop ((server hunchentoot-server) &key soft)
  (let ((acceptor (%acceptor server)))
    (when acceptor
      (handler-case
          (hunchentoot:stop acceptor :soft (not (null soft)))
        (error (e)
          (warn "hunchentoot stop: ~a" e)))
      (setf (%acceptor server) nil)
      (mark-running server nil)))
  server)

(use-hunchentoot-backend)
