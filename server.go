package main

import (
	"fmt"
	"net/http"
	"path/filepath"
)

func main() {
	// Ruta a la carpeta que contiene los archivos
	webDir := "./zig-out/web"

	// Servir archivos estáticos con los tipos MIME correctos
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Obtener la ruta del archivo solicitado
		filePath := filepath.Join(webDir, r.URL.Path)

		// Configurar CORS
		w.Header().Set("Access-Control-Allow-Origin", "*")

		// Determinar el tipo MIME basado en la extensión del archivo
		switch filepath.Ext(filePath) {
		case ".js":
			w.Header().Set("Content-Type", "application/javascript")
		case ".wasm":
			w.Header().Set("Content-Type", "application/wasm")
		case ".html":
			w.Header().Set("Content-Type", "text/html")
		default:
			// Para otros archivos, usar el tipo MIME predeterminado
			w.Header().Set("Content-Type", http.DetectContentType([]byte{}))
		}

		// Servir el archivo
		http.ServeFile(w, r, filePath)
	})

	// Iniciar el servidor
	fmt.Println("Servidor iniciado en http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Error al iniciar el servidor: %s\n", err)
	}
}
