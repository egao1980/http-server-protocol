(defsystem "http-server-backend-http2"
  :version "0.2.0"
  :description "HTTP/2 Clack backend (RFC 8441 Extended CONNECT) for http-server-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("http-server-protocol")
  :serial t
  :pathname "src"
  :components ((:file "http2-package")
               (:file "http2-backend"))
  :in-order-to ((test-op (test-op "http-server-backend-http2/tests"))))

(defsystem "http-server-backend-http2/tests"
  :depends-on ("http-server-backend-http2" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "http2-package")
               (:file "http2-backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
