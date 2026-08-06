#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 18081
JENKINS_WEBHOOK_URL = "http://127.0.0.1:18080/github-webhook/"


class WebhookProxyHandler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length)

        forwarded_headers = {
            "Content-Type": "application/json",
        }

        # Jenkins GitHub plugin relies on these headers.
        for header_name in (
            "X-GitHub-Event",
            "X-GitHub-Delivery",
            "X-Hub-Signature",
            "X-Hub-Signature-256",
            "User-Agent",
        ):
            value = self.headers.get(header_name)
            if value:
                forwarded_headers[header_name] = value

        request = Request(
            JENKINS_WEBHOOK_URL,
            data=body,
            headers=forwarded_headers,
            method="POST",
        )

        try:
            with urlopen(request, timeout=30) as response:
                response_body = response.read()
                self.send_response(response.status)

                response_content_type = response.headers.get("Content-Type")
                if response_content_type:
                    self.send_header("Content-Type", response_content_type)

                self.end_headers()
                self.wfile.write(response_body)

                print(
                    f"Forwarded {self.headers.get('X-GitHub-Event', 'unknown')} "
                    f"event to Jenkins: HTTP {response.status}",
                    flush=True,
                )

        except HTTPError as error:
            response_body = error.read()
            self.send_response(error.code)
            self.end_headers()
            self.wfile.write(response_body)

            print(
                f"Jenkins rejected webhook: HTTP {error.code}",
                flush=True,
            )

        except Exception as error:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(error).encode("utf-8"))

            print(f"Proxy error: {error}", flush=True)

    def log_message(self, format_string: str, *args: object) -> None:
        print(format_string % args, flush=True)


if __name__ == "__main__":
    server = ThreadingHTTPServer(
        (LISTEN_HOST, LISTEN_PORT),
        WebhookProxyHandler,
    )

    print(
        f"Webhook proxy listening on "
        f"http://{LISTEN_HOST}:{LISTEN_PORT}",
        flush=True,
    )
    print(f"Forwarding to {JENKINS_WEBHOOK_URL}", flush=True)

    server.serve_forever()
