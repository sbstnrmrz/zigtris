package main

import (
	"net/http"
	"log"
)

func main() {
	// Handle the root route ("/") and serve the HTML file
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "zig-out/web/zigtris.html")
	})

	// Start the server on port 8080
	log.Println("Starting server on http://localhost:8080...")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
