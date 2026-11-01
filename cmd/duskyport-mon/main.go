// duskyport-mon: live control of a running quickemu VM through the sockets quickemu
// already creates -- the HMP text monitor and, when the guest runs
// qemu-guest-agent, the QGA JSON socket. No QEMU flag injection, no engine
// changes. Each verb prints one JSON object to stdout; errors go to stderr with
// a nonzero exit.
//
// Usage:
//
//	duskyport-mon stats   <monitorSock> <agentSock|-> <pidFile|->
//	duskyport-mon power   <monitorSock> <pause|resume|reset|shutdown>
//	duskyport-mon balloon <monitorSock> <MB>
//	duskyport-mon pin     <monitorSock> <pidFile> <auto|off>
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"net"
	"os"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

const (
	dialTimeout = 800 * time.Millisecond  // socket connect budget
	cmdDeadline = 1500 * time.Millisecond // per-HMP-command read budget
	qgaDeadline = 600 * time.Millisecond  // guest agent is best-effort, keep it snappy
	cpuSample   = 300 * time.Millisecond  // gap between the two /proc CPU samples
)

func emit(v map[string]any) {
	b, _ := json.Marshal(v)
	fmt.Println(string(b))
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, "duskyport-mon: "+msg)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 2 {
		fail("usage: duskyport-mon <stats|power|balloon|pin> ...")
	}
	switch os.Args[1] {
	case "stats":
		if len(os.Args) != 5 {
			fail("usage: duskyport-mon stats <monitorSock> <agentSock|-> <pidFile|->")
		}
		doStats(os.Args[2], os.Args[3], os.Args[4])
	case "power":
		if len(os.Args) != 4 {
			fail("usage: duskyport-mon power <monitorSock> <pause|resume|reset|shutdown>")
		}
		doPower(os.Args[2], os.Args[3])
	case "balloon":
		if len(os.Args) != 4 {
			fail("usage: duskyport-mon balloon <monitorSock> <MB>")
		}
		doBalloon(os.Args[2], os.Args[3])
	case "pin":
		if len(os.Args) != 5 {
			fail("usage: duskyport-mon pin <monitorSock> <pidFile> <auto|off>")
		}
		doPin(os.Args[2], os.Args[3], os.Args[4])
	default:
		fail("unknown verb " + os.Args[1])
	}
}

// --- HMP monitor client -----------------------------------------------------

// ansi strips the CSI escapes QEMU's readline emits while echoing typed input
// (cursor moves and line erases); the prompt "(qemu)" itself is plain bytes.
var ansi = regexp.MustCompile(`\x1b\[[0-9;?]*[ -/]*[@-~]`)

type monitor struct{ conn net.Conn }

func dialMonitor(sock string) (*monitor, error) {
	conn, err := net.DialTimeout("unix", sock, dialTimeout)
	if err != nil {
		return nil, err
	}
	m := &monitor{conn}
	m.readReply() // consume the banner and first prompt
	return m, nil
}

func (m *monitor) close() { m.conn.Close() }

// readReply reads until the next "(qemu)" prompt or the read deadline, then
// returns the ANSI-stripped text. QEMU echoes each typed character with cursor
// escapes but never reprints the prompt mid-reply, so the marker reliably ends
// one command's output.
func (m *monitor) readReply() string {
	m.conn.SetReadDeadline(time.Now().Add(cmdDeadline))
	buf := make([]byte, 4096)
	var acc []byte
	for {
		n, err := m.conn.Read(buf)
		if n > 0 {
			acc = append(acc, buf[:n]...)
			if strings.Contains(string(acc), "(qemu)") {
				break
			}
		}
		if err != nil {
			break
		}
	}
	return ansi.ReplaceAllString(string(acc), "")
}

func (m *monitor) cmd(command string) string {
	m.conn.Write([]byte(command + "\n"))
	return m.readReply()
}

var (
	reStatus  = regexp.MustCompile(`VM status:\s*(\S+)`)
	reBalloon = regexp.MustCompile(`actual=(\d+)`)
	reThread  = regexp.MustCompile(`thread_id=(\d+)`)
)

func parseStatus(reply string) string {
	if m := reStatus.FindStringSubmatch(reply); m != nil {
		return m[1]
	}
	return "unknown"
}

// parseBalloon reads "balloon: actual=<MiB>"; absent when the VM has no balloon
// device, in which case the field is omitted.
func parseBalloon(reply string) (int, bool) {
	if m := reBalloon.FindStringSubmatch(reply); m != nil {
		n, _ := strconv.Atoi(m[1])
		return n, true
	}
	return 0, false
}

// parseCpus returns the vCPU thread ids in cpu-index order.
func parseCpus(reply string) []int {
	ms := reThread.FindAllStringSubmatch(reply, -1)
	tids := make([]int, 0, len(ms))
	for _, m := range ms {
		n, _ := strconv.Atoi(m[1])
		tids = append(tids, n)
	}
	return tids
}

// --- verbs ------------------------------------------------------------------

func doStats(monSock, agentSock, pidFile string) {
	m, err := dialMonitor(monSock)
	if err != nil {
		// a stopped VM has no live monitor; report it plainly, not as an error.
		emit(map[string]any{"running": false})
		return
	}
	defer m.close()

	out := map[string]any{"running": true}
	out["status"] = parseStatus(m.cmd("info status"))
	if mb, ok := parseBalloon(m.cmd("info balloon")); ok {
		out["balloonMB"] = mb
	}
	tids := parseCpus(m.cmd("info cpus"))
	out["vcpus"] = len(tids)

	// guest agent facts (ip, pretty-name) when the socket is real and answers
	if agentSock != "" && agentSock != "-" {
		if ip, osName := qgaInfo(agentSock); ip != "" || osName != "" {
			if ip != "" {
				out["ip"] = ip
			}
			if osName != "" {
				out["guestOS"] = osName
			}
		}
	}

	// host-side metrics via /proc/<pid>: CPU%, memory RSS, and affinity
	if pidFile != "" && pidFile != "-" {
		if pid := readPid(pidFile); pid > 0 {
			if rss := processRssMB(pid); rss > 0 {
				out["hostRssMB"] = rss
			}
			if pct, ok := sampleCPU(pid); ok {
				out["hostCpuPct"] = pct
			}
			if counters, ok := sampleProcIO(pid); ok {
				for k, v := range counters {
					out[k] = v
				}
			}
			if upSeconds, ok := processUptime(pid); ok {
				out["uptimeSeconds"] = upSeconds
			}
			out["pinned"] = allPinned(pid, tids)
		}
	}

	emit(out)
}

func doPower(monSock, action string) {
	m, err := dialMonitor(monSock)
	if err != nil {
		fail(err.Error())
	}
	defer m.close()

	var c string
	switch action {
	case "pause":
		c = "stop"
	case "resume":
		c = "c"
	case "reset":
		c = "system_reset"
	case "shutdown":
		c = "system_powerdown"
	default:
		fail("unknown action " + action)
	}
	m.cmd(c)
	// verify the state landed
	emit(map[string]any{"action": action, "status": parseStatus(m.cmd("info status"))})
}

func doBalloon(monSock, mbStr string) {
	mb, err := strconv.Atoi(mbStr)
	if err != nil || mb <= 0 {
		fail("invalid balloon target: " + mbStr)
	}
	m, err := dialMonitor(monSock)
	if err != nil {
		fail(err.Error())
	}
	defer m.close()

	m.cmd(fmt.Sprintf("balloon %d", mb))
	actual, ok := parseBalloon(m.cmd("info balloon"))
	emit(map[string]any{"targetMB": mb, "actualMB": actual, "supported": ok})
}

// doPin auto-pins each vCPU thread to an exclusive physical core (avoiding CPU
// 0, which host I/O and interrupts share), or clears affinity to the full set.
func doPin(monSock, pidFile, mode string) {
	pid := readPid(pidFile)
	if pid <= 0 {
		fail("cannot read pid from " + pidFile)
	}
	m, err := dialMonitor(monSock)
	if err != nil {
		fail(err.Error())
	}
	defer m.close()

	tids := parseCpus(m.cmd("info cpus"))
	if len(tids) == 0 {
		fail("no vCPU threads reported by monitor")
	}

	numCPU := runtime.NumCPU()
	all := make([]int, numCPU)
	for i := range all {
		all[i] = i
	}

	switch mode {
	case "off":
		for _, tid := range tids {
			if err := setAffinity(tid, all); err != nil {
				fail(fmt.Sprintf("clear affinity for tid %d: %v", tid, err))
			}
		}
		emit(map[string]any{"pinned": false, "vcpus": len(tids)})
	case "auto":
		// stride across available CPUs, skipping 0 when we have >= 4 cores
		base := 0
		if numCPU >= 4 {
			base = 1
		}
		usable := numCPU - base
		if usable <= 0 {
			usable = numCPU
			base = 0
		}
		for i, tid := range tids {
			target := base + (i % usable)
			if err := setAffinity(tid, []int{target}); err != nil {
				fail(fmt.Sprintf("pin tid %d to cpu %d: %v", tid, target, err))
			}
		}
		emit(map[string]any{"pinned": true, "vcpus": len(tids), "hostCpus": numCPU})
	default:
		fail("pin mode must be 'auto' or 'off'")
	}
}

// --- /proc inspection -------------------------------------------------------

func readPid(path string) int {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	n, _ := strconv.Atoi(strings.TrimSpace(string(b)))
	return n
}

func processRssMB(pid int) int {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/statm", pid))
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(b))
	if len(fields) < 2 {
		return 0
	}
	pages, err := strconv.Atoi(fields[1])
	if err != nil {
		return 0
	}
	return (pages * os.Getpagesize()) / (1024 * 1024)
}

func readProcCPU(pid int) (uint64, error) {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return 0, err
	}
	// comm is parenthesized and can contain spaces/parentheses: find the LAST ')'
	end := strings.LastIndexByte(string(b), ')')
	if end < 0 {
		return 0, fmt.Errorf("malformed stat")
	}
	fields := strings.Fields(string(b)[end+1:])
	// utime is field 14, stime is field 15; in fields[] (0-indexed after comm)
	// they are indices 11 and 12.
	if len(fields) <= 12 {
		return 0, fmt.Errorf("truncated stat")
	}
	utime, err1 := strconv.ParseUint(fields[11], 10, 64)
	stime, err2 := strconv.ParseUint(fields[12], 10, 64)
	if err1 != nil || err2 != nil {
		return 0, fmt.Errorf("bad ticks")
	}
	return utime + stime, nil
}

// sampleCPU measures process CPU ticks across a 300ms window and returns the
// percentage of one host core used (can exceed 100% on multi-vCPU machines).
func sampleCPU(pid int) (float64, bool) {
	t1, err := readProcCPU(pid)
	if err != nil {
		return 0, false
	}
	time.Sleep(cpuSample)
	t2, err := readProcCPU(pid)
	if err != nil {
		return 0, false
	}
	// standard Linux USER_HZ is 100 ticks/sec
	const userHz = 100.0
	seconds := cpuSample.Seconds()
	ticks := float64(t2 - t1)
	pct := (ticks / userHz / seconds) * 100.0
	return math.Round(pct*10) / 10, true
}

func sampleProcIO(pid int) (map[string]uint64, bool) {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/io", pid))
	if err != nil {
		return nil, false
	}
	values := map[string]uint64{}
	for _, line := range strings.Split(string(b), "\n") {
		key, raw, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		n, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 64)
		if err == nil {
			values[key] = n
		}
	}
	readBytes, readOK := values["read_bytes"]
	writeBytes, writeOK := values["write_bytes"]
	rchar, rcharOK := values["rchar"]
	wchar, wcharOK := values["wchar"]
	if !readOK || !writeOK {
		return nil, false
	}
	netRX, netTX := uint64(0), uint64(0)
	if rcharOK && rchar > readBytes {
		netRX = rchar - readBytes
	}
	if wcharOK && wchar > writeBytes {
		netTX = wchar - writeBytes
	}
	return map[string]uint64{
		"diskReadBytes":  readBytes,
		"diskWriteBytes": writeBytes,
		"netRxBytes":     netRX,
		"netTxBytes":     netTX,
	}, true
}

func processUptime(pid int) (int64, bool) {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return 0, false
	}
	end := strings.LastIndexByte(string(b), ')')
	if end < 0 {
		return 0, false
	}
	fields := strings.Fields(string(b)[end+1:])
	if len(fields) <= 19 {
		return 0, false
	}
	startTicks, err := strconv.ParseUint(fields[19], 10, 64)
	if err != nil {
		return 0, false
	}
	up, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0, false
	}
	var upSeconds float64
	if _, err := fmt.Sscanf(string(up), "%f", &upSeconds); err != nil {
		return 0, false
	}
	const clockTicks = 100
	seconds := int64(upSeconds) - int64(startTicks/clockTicks)
	if seconds < 0 {
		seconds = 0
	}
	return seconds, true
}

func cpusAllowedList(pid, tid int) (string, bool) {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/task/%d/status", pid, tid))
	if err != nil {
		return "", false
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "Cpus_allowed_list:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "Cpus_allowed_list:")), true
		}
	}
	return "", false
}

func allPinned(pid int, tids []int) bool {
	if len(tids) == 0 {
		return false
	}
	for _, tid := range tids {
		list, ok := cpusAllowedList(pid, tid)
		if !ok || list == "" || strings.ContainsAny(list, ",-") {
			return false
		}
	}
	return true
}

func setAffinity(tid int, cpus []int) error {
	var mask [128]byte
	for _, c := range cpus {
		if c >= 0 && c/8 < len(mask) {
			mask[c/8] |= 1 << (uint(c) % 8)
		}
	}
	_, _, errno := syscall.Syscall(syscall.SYS_SCHED_SETAFFINITY,
		uintptr(tid), uintptr(len(mask)), uintptr(unsafe.Pointer(&mask[0])))
	if errno != 0 {
		return errno
	}
	return nil
}

// --- QGA guest agent (optional) ---------------------------------------------

func qgaInfo(sock string) (ip, osName string) {
	conn, err := net.DialTimeout("unix", sock, dialTimeout)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(qgaDeadline))
	dec := json.NewDecoder(conn)

	id := int(time.Now().UnixNano() & 0x7fffffff)
	fmt.Fprintf(conn, "{\"execute\":\"guest-sync\",\"arguments\":{\"id\":%d}}\n", id)
	for {
		var r struct {
			Return json.Number `json:"return"`
		}
		if dec.Decode(&r) != nil {
			return
		}
		if n, _ := r.Return.Int64(); int(n) == id {
			break
		}
	}

	fmt.Fprint(conn, `{"execute":"guest-network-get-interfaces"}`+"\n")
	var nif struct {
		Return []struct {
			Name string `json:"name"`
			IPs  []struct {
				Type string `json:"ip-address-type"`
				Addr string `json:"ip-address"`
			} `json:"ip-addresses"`
		} `json:"return"`
	}
	if dec.Decode(&nif) == nil {
		for _, iface := range nif.Return {
			if iface.Name == "lo" {
				continue
			}
			for _, a := range iface.IPs {
				if a.Type == "ipv4" && a.Addr != "127.0.0.1" {
					ip = a.Addr
					break
				}
			}
			if ip != "" {
				break
			}
		}
	}

	fmt.Fprint(conn, `{"execute":"guest-get-osinfo"}`+"\n")
	var osi struct {
		Return struct {
			PrettyName string `json:"pretty-name"`
		} `json:"return"`
	}
	if dec.Decode(&osi) == nil {
		osName = osi.Return.PrettyName
	}
	return
}
