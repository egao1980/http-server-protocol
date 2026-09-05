(in-package #:http-server-backend-http2)

;;; Clack env in, H2 multiplex out via zellerin `http2/server`.
;;; RFC 8441: advertise SETTINGS_ENABLE_CONNECT_PROTOCOL, accept :protocol,
;;; dispatch CONNECT on END_HEADERS (client does not END_STREAM).
;;; Requires TLS certs. http2/server/threaded may fail to load on Windows (grovel).

(defclass http2-server-backend (http-server-protocol:http-server-backend) ())

(defclass http2-server (http-server-protocol:http-server)
  ((ssl-cert :initarg :ssl-cert :initform nil :accessor http2-server-ssl-cert)
   (ssl-key :initarg :ssl-key :initform nil :accessor http2-server-ssl-key)
   (handler :initform nil :accessor http2-server-handler)))

(defvar *http2-connect-ready* nil)

(defgeneric http2-connect-app (connection))
(defgeneric http2-stream-protocol (stream))
(defgeneric (setf http2-stream-protocol) (value stream))
(defgeneric http2-stream-request-headers (stream))
(defgeneric http2-stream-connect-dispatched-p (stream))
(defgeneric (setf http2-stream-connect-dispatched-p) (value stream))

(defun make-http2-server-backend ()
  (make-instance 'http2-server-backend))

(defun use-http2-server-backend ()
  (setf http-server-protocol:*http-server-backend* (make-http2-server-backend)))

(defun http2-server-available-p ()
  (ignore-errors (asdf:load-system "http2/server/threaded") t))

(defun %method-string (method)
  (cond
    ((null method) "")
    ((symbolp method) (symbol-name method))
    (t (string method))))

(defun connect-method-p (method)
  (string-equal (%method-string method) "CONNECT"))

(defun header-map-get (headers name)
  (when (hash-table-p headers)
    (or (gethash name headers)
        (gethash (string-downcase name) headers)
        (gethash (string-upcase name) headers)
        (gethash (intern (string-upcase name) :keyword) headers))))

(defun env-connect-protocol (env)
  "RFC 8441 :protocol from a Clack ENV plist."
  (or (getf env :protocol)
      (header-map-get (getf env :headers) "protocol")
      (header-map-get (getf env :headers) ":protocol")))

(defun extended-connect-request-p (env)
  "True for Extended CONNECT WebSocket (RFC 8441)."
  (and (connect-method-p (getf env :request-method))
       (string-equal (env-connect-protocol env) "websocket")))

(defun %split-path-query (path)
  (let* ((p (or path "/"))
         (q (position #\? p)))
    (if q
        (values (subseq p 0 q) (subseq p (1+ q)))
        (values p nil))))

(defun %split-authority (authority)
  (let* ((a (or authority ""))
         (colon (position #\: a :from-end t)))
    (if (and colon (plusp colon)
             (every #'digit-char-p (subseq a (1+ colon))))
        (values (subseq a 0 colon) (parse-integer (subseq a (1+ colon))))
        (values a 443))))

(defun %h2-sym (name &rest packages)
  (or (loop for p in packages
            for s = (and (find-package p) (find-symbol name p))
            when s return s)
      (error "http2 symbol ~A not found in ~A" name packages)))

(defun %ensure-http2 ()
  (asdf:load-system "http2/server/threaded")
  t)

(defun ensure-http2-connect-classes ()
  (%ensure-connect-classes))

(defun %ensure-connect-classes ()
  "Define CONNECT-aware connection/stream after http2 is loadable."
  (%ensure-http2)
  (when *http2-connect-ready*
    (return-from %ensure-connect-classes t))
  (let ((vanilla (or (find-symbol "VANILLA-SERVER-CONNECTION" :http2/server)
                     (find-symbol "VANILLA-SERVER-CONNECTION" :http2/server/shared)))
        (server-stream (%h2-sym "SERVER-STREAM" :http2/core))
        (header-m (%h2-sym "HEADER-COLLECTING-MIXIN" :http2/core))
        (get-settings (%h2-sym "GET-SETTINGS" :http2/core))
        (add-header (%h2-sym "ADD-HEADER" :http2/core))
        (process-end (%h2-sym "PROCESS-END-HEADERS" :http2/core))
        (peer-ends (%h2-sym "PEER-ENDS-HTTP-STREAM" :http2/core))
        (send-headers (%h2-sym "SEND-HEADERS" :http2/core))
        (get-method (%h2-sym "GET-METHOD" :http2/core))
        (get-path (%h2-sym "GET-PATH" :http2/core))
        (get-scheme (%h2-sym "GET-SCHEME" :http2/core))
        (get-authority (%h2-sym "GET-AUTHORITY" :http2/core))
        (get-connection (%h2-sym "GET-CONNECTION" :http2/core))
        (make-out (find-symbol "MAKE-TRANSPORT-OUTPUT-STREAM" :http2/core)))
    (unless vanilla
      (error 'http-server-protocol:http-server-start-error
             :message "http2 missing VANILLA-SERVER-CONNECTION"))
    (unless (find-class 'http2-connect-connection nil)
      (eval `(defclass http2-connect-connection (,vanilla)
               ((app :initarg :app :accessor http2-connect-app))
               (:documentation
                "H2 server connection that advertises ENABLE_CONNECT_PROTOCOL."))))
    (unless (find-class 'http2-connect-stream nil)
      (eval `(defclass http2-connect-stream (,server-stream ,header-m)
               ((request-headers :initarg :request-headers
                                 :accessor http2-stream-request-headers)
                (protocol :initform nil :accessor http2-stream-protocol)
                (connect-dispatched-p :initform nil
                                      :accessor http2-stream-connect-dispatched-p))
               (:default-initargs :request-headers (make-hash-table :test 'equal)))))
    (eval `(defmethod ,get-settings append ((connection http2-connect-connection))
             '((:enable-connect-protocol . 1))))
    (eval `(defmethod ,add-header (connection (stream http2-connect-stream) name value)
             (cond
               ((or (eq name :protocol)
                    (and (stringp name)
                         (or (string-equal name ":protocol")
                             (string-equal name "protocol"))))
                (setf (http2-stream-protocol stream) value)
                (setf (gethash "protocol" (http2-stream-request-headers stream))
                      value))
               ((keywordp name)
                (call-next-method))
               (t
                (setf (gethash name (http2-stream-request-headers stream))
                      value)))))
    (eval `(defmethod ,process-end :after (connection (stream http2-connect-stream))
             (declare (ignore connection))
             (when (and (connect-method-p (,get-method stream))
                        (string-equal (http2-stream-protocol stream) "websocket")
                        (not (http2-stream-connect-dispatched-p stream)))
               (%dispatch-clack stream :connect t))))
    (eval `(defmethod ,peer-ends ((stream http2-connect-stream))
             (if (http2-stream-connect-dispatched-p stream)
                 nil
                 (%dispatch-clack stream :connect nil))))
    (setf *http2-connect-ready* t)
    (values send-headers get-method get-path get-scheme get-authority
            get-connection make-out)))

(defun %clack-env (stream &key connect-p)
  (let* ((get-method (%h2-sym "GET-METHOD" :http2/core))
         (get-path (%h2-sym "GET-PATH" :http2/core))
         (get-scheme (%h2-sym "GET-SCHEME" :http2/core))
         (get-authority (%h2-sym "GET-AUTHORITY" :http2/core))
         (path (or (funcall get-path stream) "/"))
         (authority (or (funcall get-authority stream) ""))
         (method (funcall get-method stream)))
    (multiple-value-bind (path-info query) (%split-path-query path)
      (multiple-value-bind (server-name server-port) (%split-authority authority)
        (list :request-method (if (stringp method)
                                  (intern (string-upcase method) :keyword)
                                  method)
              :script-name ""
              :path-info path-info
              :query-string query
              :url-scheme (or (funcall get-scheme stream) "https")
              :server-name server-name
              :server-port server-port
              :server-protocol :http/2
              :request-uri path
              :raw-body stream
              :headers (http2-stream-request-headers stream)
              :protocol (http2-stream-protocol stream)
              :connect-p (and connect-p t))))))

(defun %octets (body start end)
  (cond
    ((stringp body)
     (let* ((s (or start 0))
            (e (or end (length body)))
            (out (make-array (- e s) :element-type '(unsigned-byte 8))))
       (loop for i from s below e
             for j from 0
             do (setf (aref out j) (logand #xff (char-code (char body i)))))
       out))
    ((and (zerop (or start 0))
          (or (null end) (eql end (length body))))
     body)
    (t (subseq body (or start 0) end))))

(defun %send-status-headers (stream status headers)
  (let ((send (%h2-sym "SEND-HEADERS" :http2/core)))
    (funcall send stream
             (cons (list :status (format nil "~D" status))
                   (loop for (key value) on headers by #'cddr
                         collect (list (string-downcase
                                        (if (symbolp key)
                                            (symbol-name key)
                                            (string key)))
                                       (princ-to-string value))))
             :end-stream nil :end-headers t)))

(defun %write-clack-body (stream body)
  (let ((make-out (find-symbol "MAKE-TRANSPORT-OUTPUT-STREAM" :http2/core)))
    (unless make-out
      (error 'http-server-protocol:http-server-start-error
             :message "http2 missing MAKE-TRANSPORT-OUTPUT-STREAM"))
    (with-open-stream (out (funcall make-out stream :utf8 nil))
      (etypecase body
        (null)
        (cons (dolist (string body) (princ string out)))
        (vector (write-sequence body out))
        (pathname
         (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8))))
           (with-open-file (in body :element-type '(unsigned-byte 8))
             (loop for len = (read-sequence buffer in)
                   while (plusp len)
                   do (write-sequence buffer out :end len)))))))))

(defun %connect-responder (stream)
  (lambda (status-and-headers)
    (%send-status-headers stream (first status-and-headers)
                          (second status-and-headers))
    (lambda (body &key (start 0) (end (and body (length body)))
                    &allow-other-keys)
      (when body
        (let ((write (%h2-sym "WRITE-DATA-FRAME" :http2/core))
              (chunk (%octets body start end)))
          (funcall write stream chunk :end-stream nil))))))

(defun %http-responder (stream)
  (lambda (status-and-headers)
    (%send-status-headers stream (first status-and-headers)
                          (second status-and-headers))
    (lambda (body &key (start 0) (end (and body (length body)))
                    &allow-other-keys)
      (when body
        (%write-clack-body stream
                           (if (or (stringp body) (vectorp body))
                               (%octets body start end)
                               body))))))

(defun %dispatch-clack (stream &key connect-p)
  (when connect-p
    (setf (http2-stream-connect-dispatched-p stream) t))
  (let* ((get-connection (%h2-sym "GET-CONNECTION" :http2/core))
         (conn (funcall get-connection stream))
         (app (http2-connect-app conn))
         (response (funcall app (%clack-env stream :connect-p connect-p))))
    (cond
      ((functionp response)
       (funcall response
                (if connect-p
                    (%connect-responder stream)
                    (%http-responder stream))))
      ((consp response)
       (destructuring-bind (status headers body) response
         (%send-status-headers stream status headers)
         (unless connect-p
           (%write-clack-body stream body))))
      (t
       (%send-status-headers stream 500 '(:content-type "text/plain"))
       (unless connect-p
         (%write-clack-body stream '("dispatch error")))))))

(defmethod http-server-protocol:backend-make-server
    ((backend http2-server-backend) &key host port app ssl-cert ssl-key backlog)
  (declare (ignore backlog))
  (make-instance 'http2-server
                 :host host :port port :app app
                 :ssl-cert ssl-cert :ssl-key ssl-key))

(defmethod http-server-protocol:start ((server http2-server) &key (background t))
  (declare (ignore background))
  (unless (and (http2-server-ssl-cert server) (http2-server-ssl-key server))
    (error 'http-server-protocol:http-server-start-error
           :message "HTTP/2 server requires :ssl-cert and :ssl-key"))
  (%ensure-connect-classes)
  (let* ((start (%h2-sym "START" :http2/server))
         (dispatcher-class
           (symbol-value
            (or (find-symbol "*VANILLA-SERVER-DISPATCHER*" :http2/server)
                (find-symbol "*VANILLA-SERVER-DISPATCHER*" :http2/server/shared))))
         (handler
           (funcall start
                    (http-server-protocol:server-port server)
                    :host (http-server-protocol:server-host server)
                    :dispatcher
                    (make-instance
                     dispatcher-class
                     :private-key-file
                     (namestring (http2-server-ssl-key server))
                     :certificate-file
                     (namestring (http2-server-ssl-cert server))
                     :connection-class 'http2-connect-connection
                     :connection-args
                     (list :app (http-server-protocol:server-app server)
                           :stream-class 'http2-connect-stream)))))
    (setf (http2-server-handler server) handler)
    (http-server-protocol:mark-running server t)
    server))

(defmethod http-server-protocol:stop ((server http2-server) &key soft)
  (declare (ignore soft))
  (let ((stop (and (find-package :http2/server)
                   (find-symbol "STOP" :http2/server)))
        (handler (http2-server-handler server)))
    (when (and stop handler)
      (ignore-errors (funcall stop handler))))
  (http-server-protocol:mark-running server nil)
  server)
