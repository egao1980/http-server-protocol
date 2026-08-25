(defsystem "http-server-protocol"
  :version "0.1.0"
  :description "CLOS HTTP server protocol for cl-stack (Clack app contract)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("bordeaux-threads")
  :properties
  (:cl-repo
   (:ci (:with ("http-server-backend-hunchentoot" "rove" "usocket")
         :sources (("rove" :ql) ("alexandria" :ql) ("bordeaux-threads" :ql)
                   ("cl-ppcre" :ql) ("flexi-streams" :ql) ("split-sequence" :ql)
                   ("cl-base64" :ql) ("trivial-features" :ql))
         :load-before-test ("http-server-backend-hunchentoot"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "http-server-protocol/tests"))))

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
