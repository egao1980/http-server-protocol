(defpackage #:http-server-protocol
  (:nicknames #:stack-http-server)
  (:use #:cl)
  (:shadow #:start)
  (:export #:http-server-error
           #:http-server-bind-error
           #:http-server-start-error
           #:http-server-not-running
           #:http-server-error-message
           #:*http-server-backend*
           #:http-server
           #:http-server-backend
           #:backend-make-server
           #:start
           #:stop
           #:running-p
           #:serve
           #:with-server
           #:server-host
           #:server-port
           #:server-app
           #:server-running-p
           #:mark-running))

(in-package #:http-server-protocol)
