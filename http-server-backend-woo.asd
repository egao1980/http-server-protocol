(defsystem "http-server-backend-woo"
  :version "0.1.0"
  :description "http-server-protocol backend — Woo (Unix / libev)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("http-server-protocol"
               "clack-handler-woo"
               "woo"
               "bordeaux-threads")
  :properties
  (:cl-repo
   (:ci (:with ("http-server-protocol" "rove" "usocket"))))
  :serial t
  :pathname "src/backend-woo"
  :components ((:file "package")
               (:file "backend")))
