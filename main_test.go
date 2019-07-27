package main

import (
	"net/http"
	"sync/atomic"
	"testing"
)

func Test_healthz(t *testing.T) {
	type args struct {
		w http.ResponseWriter
		r *http.Request
	}
	tests := []struct {
		name string
		args args
	}{
	// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			healthz(tt.args.w, tt.args.r)
		})
	}
}

func Test_readyz(t *testing.T) {
	type args struct {
		w       http.ResponseWriter
		r       *http.Request
		isReady *atomic.Value
	}
	tests := []struct {
		name string
		args args
	}{
	// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			readyz(tt.args.w, tt.args.r, tt.args.isReady)
		})
	}
}

func TestSetupCloseHandler(t *testing.T) {
	tests := []struct {
		name string
	}{
	// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			SetupCloseHandler()
		})
	}
}

func Test_main(t *testing.T) {
	tests := []struct {
		name string
	}{
	// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			main()
		})
	}
}
