(defpackage #:http-server-backend-woo
  (:use #:cl #:http-server-protocol)
  (:local-nicknames (#:bt #:bordeaux-threads))
  (:export #:woo-backend
           #:make-woo-backend
           #:use-woo-backend))

(in-package #:http-server-backend-woo)
