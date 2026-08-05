(defsystem "http-server-protocol"
  :version "0.1.0"
  :description "CLOS HTTP server protocol for cl-stack (Clack app contract)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("bordeaux-threads")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "http-server-protocol/tests"))))

(defsystem "http-server-backend-hunchentoot"
  :version "0.1.0"
  :description "http-server-protocol backend — Hunchentoot via Clack handler"
  :author "egao1980"
  :license "MIT"
  :depends-on ("http-server-protocol"
               "clack-handler-hunchentoot"
               "hunchentoot"
               "bordeaux-threads")
  :serial t
  :pathname "src/backend-hunchentoot"
  :components ((:file "package")
               (:file "backend")))

(defsystem "http-server-backend-woo"
  :version "0.1.0"
  :description "http-server-protocol backend — Woo (Unix / libev)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("http-server-protocol"
               "clack-handler-woo"
               "woo"
               "bordeaux-threads")
  :serial t
  :pathname "src/backend-woo"
  :components ((:file "package")
               (:file "backend")))

(defsystem "http-server-protocol/tests"
  :depends-on ("http-server-protocol"
               "http-server-backend-hunchentoot"
               "rove"
               "usocket")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
