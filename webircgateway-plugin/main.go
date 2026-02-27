package main

import (
	"log"
	"net/http"
)

var router *http.ServeMux
var server *http.Server

// securityMiddleware strips identifying server headers and adds baseline
// security headers to every response. This prevents leaking the real
// server IP or software version to clients.
func securityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Del("Server")
		w.Header().Del("X-Powered-By")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

func main() {
	router = http.NewServeMux()
	startGravatar(router)

	if config.ListenAddress == "" {
		log.Println("Config error listen_address missing")
		return
	}

	server = &http.Server{
		Addr:    config.ListenAddress,
		Handler: securityMiddleware(router),
	}
	log.Printf("Listening on %s", config.ListenAddress)
	server.ListenAndServe()
}
