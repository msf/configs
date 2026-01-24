package main

import (
	"net"
	"testing"
)

func TestIPParsingReal(t *testing.T) {
	t.Run("fetch real IPv4", func(t *testing.T) {
		ip, err := getIP(checkIPv4)
		if err != nil {
			t.Fatalf("getIP(IPv4) failed: %v", err)
		}
		if net.ParseIP(ip) == nil {
			t.Errorf("got invalid IP: %q", ip)
		}
		t.Logf("IPv4: %s", ip)
	})

	t.Run("fetch real IPv6", func(t *testing.T) {
		ip, err := getIP(checkIPv6)
		if err != nil {
			t.Fatalf("getIP(IPv6) failed: %v", err)
		}
		parsed := net.ParseIP(ip)
		if parsed == nil {
			t.Errorf("got invalid IP: %q", ip)
		}
		if parsed.To4() != nil {
			t.Errorf("expected IPv6, got IPv4: %s", ip)
		}
		t.Logf("IPv6: %s", ip)
	})
}
