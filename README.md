# http-server-protocol

CLOS HTTP **server** lifecycle for [cl-stack](https://github.com/egao1980/cl-stack). Apps are **Clack** functions.

| System | Role |
|--------|------|
| `http-server-protocol` | `serve` / `start` / `stop` / `with-server` |
| `http-server-backend-hunchentoot` | **Default** — Windows + Unix |
| `http-server-backend-woo` | Unix / libev (call `use-woo-backend`) |

Brief: [`cl-stack/docs/capabilities/http-server.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/http-server.md).

```lisp
(asdf:load-system "http-server-backend-hunchentoot")

(defun app (env)
  (declare (ignore env))
  '(200 (:content-type "text/plain") ("ok")))

(stack-http-server:with-server (s #'app :port 8080)
  …)
```

## License

MIT — see [LICENSE](LICENSE).
