(in-package #:http-server-backend-woo)

;;; Woo runs its libev loop in the calling thread — BACKGROUND starts a BT thread.

(defclass woo-backend (http-server-backend) ())

(defclass woo-server (http-server)
  ((thread :initform nil :accessor %thread)
   (stop-fn :initform nil :accessor %stop-fn)))

(defun make-woo-backend ()
  (make-instance 'woo-backend))

(defun use-woo-backend ()
  "Bind *HTTP-SERVER-BACKEND* to Woo. Returns the backend."
  (setf *http-server-backend* (make-woo-backend)))

(defmethod backend-make-server ((backend woo-backend)
                                &key (host "127.0.0.1") (port 8080) app
                                  ssl-cert ssl-key backlog)
  (declare (ignore ssl-cert ssl-key backlog))
  (unless app
    (error 'http-server-start-error :message "APP is required"))
  #+win32
  (error 'http-server-start-error
         :message "Woo backend is Unix-only (libev)")
  (make-instance 'woo-server :host host :port port :app app))

(defmethod start ((server woo-server) &key (background t))
  (when (server-running-p server)
    (return-from start server))
  (let* ((run (find-symbol "RUN" :clack.handler.woo))
         (app (server-app server))
         (host (server-host server))
         (port (server-port server)))
    (unless run
      (error 'http-server-start-error
             :message "clack.handler.woo:run not found"))
    (flet ((loop-fn ()
             (handler-case
                 (funcall run app :address host :port port :debug nil)
               (error (e)
                 (warn "woo loop exited: ~a" e)))))
      (if background
          (setf (%thread server)
                (bt:make-thread #'loop-fn :name (format nil "woo-~a" port)))
          (progn
            (mark-running server t)
            (loop-fn)
            (return-from start server)))
      ;; Give the accept loop a moment to bind.
      (sleep 0.1)
      (mark-running server t)))
  server)

(defmethod stop ((server woo-server) &key soft)
  (declare (ignore soft))
  ;; Woo has no clean public stop from another thread in all versions;
  ;; destroy the loop thread as a last resort.
  (let ((th (%thread server)))
    (when (and th (bt:thread-alive-p th))
      (ignore-errors (bt:destroy-thread th)))
    (setf (%thread server) nil)
    (mark-running server nil))
  server)

;; Do not auto-bind — loading Woo must not displace the Hunchentoot default.
;; Call USE-WOO-BACKEND explicitly on Unix.