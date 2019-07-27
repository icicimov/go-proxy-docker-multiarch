package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"time"

	//"strings"
	"sync"
	"sync/atomic"
	"syscall"
)

var port = 8989
var mutex = &sync.Mutex{}
var tURL = "http://my-cdn.s3-website.my-region.amazonaws.com/maintenance/myapp/"

const tout int = 1

// HANDLERS //

// healthz: Health handler
func healthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "OK")
}

// readyz: Rediness handler
func readyz(w http.ResponseWriter, r *http.Request, isReady *atomic.Value) {
	if isReady == nil || !isReady.Load().(bool) {
		http.Error(w, http.StatusText(http.StatusServiceUnavailable), http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "OK")
}

// SetupCloseHandler Interupt handler
func SetupCloseHandler() {
	c := make(chan os.Signal, 2)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		fmt.Println("\rCaught sig interrupt...exiting.")
		// Do something on exit, DeleteFiles() etc.
		os.Exit(0)
	}()
}

func main() {
	SetupCloseHandler()

	// Liveness probe
	http.HandleFunc("/healthz", healthz)

	// Rediness probe (simulate X seconds load time)
	isReady := &atomic.Value{}
	isReady.Store(false)
	go func() {
		log.Printf("Ready NOK")
		time.Sleep(time.Duration(tout) * time.Second)
		isReady.Store(true)
		log.Printf("Ready OK")
	}()
	http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		readyz(w, r, isReady)
	})

	// Change the port via env var
	penv := os.Getenv("PORT")
	if penv != "" {
		eport, err := strconv.Atoi(penv)
		if err != nil {
			panic(err)
		}
		port = eport
	}
	// Change the proxy url via env var
	proxyenv := os.Getenv("PROXY_TARGET_URL")
	if proxyenv != "" {
		tURL = proxyenv
	}

	pflag := flag.String("port", "", "service port")
	proxyflag := flag.String("proxy_target_url", "", "target url for proxy")
	flag.Parse()
	// Change the port via command line flag
	if *pflag != "" {
		cport, err := strconv.Atoi(*pflag)
		if err != nil {
			panic(err)
		}
		port = cport
	}
	sport := ":" + strconv.Itoa(port)
	// Change the proxy url via command line flag
	if *proxyflag != "" {
		tURL = *proxyflag
	}

	target, err := url.Parse(tURL)
	log.Printf("forwarding to -> %s://%s\n", target.Scheme, target.Host)

	if err != nil {
		log.Fatal(err)
	}

	http.DefaultTransport = &http.Transport{
		Dial: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).Dial,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		MaxIdleConnsPerHost:   50,
	}

	proxy := httputil.NewSingleHostReverseProxy(target)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Println(r.URL)
		//log.Println(r.URL.Path[1:])

		// Rewrite the style sheet req to /css/style.css,
		// anything else should go to the index page
		re := regexp.MustCompile(`\/\w+\/\w+\.css$`)
		if r.URL.Path != "/" {
			if re.FindString(r.URL.Path) != "" {
				r.URL.Path = re.FindString(r.URL.Path)
			} else {
				r.URL.Path = "/"
			}
		}

		r.Host = r.URL.Host // if you remove this line the Host header will
		// be set to "localhost" and response will fail

		w.Header().Set("X-Proxy", "localhost")
		proxy.ServeHTTP(w, r)
	})

	log.Print("Starting the service listening on port " + sport + " ...")
	log.Fatal(http.ListenAndServe(sport, nil))
}
