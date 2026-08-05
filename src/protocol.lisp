(in-package #:http-server-protocol)

;;; App contract = Clack application:
;;;   (lambda (env) → (status headers body))

(defvar *http-server-backend* nil
  "Current HTTP server backend (satisfies BACKEND-MAKE-SERVER).")

(defclass http-server-backend () ()
  (:documentation "Base class for http-server-protocol backends."))

(defclass http-server ()
  ((host :initarg :host :reader server-host)
   (port :initarg :port :reader server-port)
   (app :initarg :app :reader server-app)
   (running :initform nil :accessor server-running-p))
  (:documentation "Backend listener wrapping a Clack app."))

(defun mark-running (server value)
  "Backend helper: set running flag."
  (setf (server-running-p server) value))

(defgeneric backend-make-server (backend &key host port app ssl-cert ssl-key backlog)
  (:documentation "Return a stopped HTTP-SERVER ready to START."))

(defgeneric start (server &key background)
  (:documentation "Bind/listen/accept. BACKGROUND T → return immediately."))

(defgeneric stop (server &key soft)
  (:documentation "Stop accepting. SOFT drains when the backend supports it."))

(defgeneric running-p (server)
  (:method ((server http-server))
    (server-running-p server)))

(defun serve (app &key (host "127.0.0.1") (port 8080) (background t)
                    ssl-cert ssl-key backlog
                    (backend *http-server-backend*))
  "Make + start a server for Clack APP. Returns the SERVER."
  (unless backend
    (error 'http-server-start-error
           :message "*http-server-backend* unbound — load http-server-backend-hunchentoot"))
  (let ((server (backend-make-server backend
                                     :host host :port port :app app
                                     :ssl-cert ssl-cert :ssl-key ssl-key
                                     :backlog backlog)))
    (start server :background background)
    server))

(defmacro with-server ((var app &rest keys) &body body)
  "Bind SERVER from (SERVE APP …); STOP with unwind-protect."
  `(let ((,var (serve ,app ,@keys)))
     (unwind-protect
          (progn ,@body)
       (ignore-errors (stop ,var)))))
