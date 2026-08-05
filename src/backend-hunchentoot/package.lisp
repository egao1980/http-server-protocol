(defpackage #:http-server-backend-hunchentoot
  (:use #:cl #:http-server-protocol)
  (:export #:hunchentoot-backend
           #:make-hunchentoot-backend
           #:use-hunchentoot-backend))

(in-package #:http-server-backend-hunchentoot)
