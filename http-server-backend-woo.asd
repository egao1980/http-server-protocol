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
   (:ci (:with ("http-server-protocol" "rove" "usocket")
         :sources (("babel" :ql) ("rove" :ql) ("alexandria" :ql)
                   ("bordeaux-threads" :ql) ("cffi" :ql) ("cl-ppcre" :ql)
                   ("flexi-streams" :ql) ("split-sequence" :ql)
                   ("trivial-features" :ql)))))
  :serial t
  :pathname "src/backend-woo"
  :components ((:file "package")
               (:file "backend")))
