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
