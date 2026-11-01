package main

// duskyport-gpuvm: GPU passthrough VM manager for Duskyport's Looking Glass panel.
// It manages tuned libvirt domains named dusky-<name>, defines/starts/stops/removes
// them via virsh, and launches looking-glass-client on start.

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// GPU represents a detected graphics device for passthrough.
type GPU struct {
	Slot          string   `json:"slot"`
	Model         string   `json:"model"`
	Driver        string   `json:"driver"`
	Class         string   `json:"class"`
	VramMB        int      `json:"vramMb"`
	IommuGroup    int      `json:"iommuGroup"`
	DrivesDisplay bool     `json:"drivesDisplay"`
	GroupIsolated bool     `json:"groupIsolated"`
	Functions     []string `json:"functions"`
}

// Capability summarizes host hardware virtualization and passthrough capability.
type Capability struct {
	Verdict     string `json:"verdict"` // ready | needs-setup | incapable
	Host        *GPU   `json:"host,omitempty"`
	Passthrough *GPU   `json:"passthrough,omitempty"`
	RamTotalMB  int    `json:"ramTotalMb"`
	RamFreeMB   int    `json:"ramFreeMb"`
	VmReady     bool   `json:"vmReady"`
	Kvm         bool   `json:"kvm"`
}

type vmMeta struct {
	Name   string `json:"name"`
	OS     string `json:"os"`
	RAMMB  int    `json:"ramMb"`
	Vcpus  int    `json:"vcpus"`
	DiskGB int    `json:"diskGb"`
	ISO    string `json:"iso"`
}

type vmMachine struct {
	vmMeta
	Domain string `json:"domain"`
	State  string `json:"state"`
	Disk   string `json:"disk"`
}

type vmList struct {
	Ready    bool        `json:"ready"`
	Blocker  string      `json:"blocker,omitempty"`
	Machines []vmMachine `json:"machines"`
}

const vmDomainPrefix = "dusky-"

func main() {
	if err := runGpuVM(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "duskyport-gpuvm: %v\n", err)
		os.Exit(1)
	}
}

func runGpuVM(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: duskyport-gpuvm <list|status|create|start|stop|remove> [args]")
	}
	flags := parseVMFlags(args[1:])
	switch args[0] {
	case "list":
		return vmDoList()
	case "status":
		return vmDoStatus(flags["name"])
	case "create":
		return vmDoCreate(flags)
	case "start":
		return vmDoStart(flags["name"])
	case "stop":
		return vmDoStop(flags["name"], flags["force"] != "")
	case "remove":
		return vmDoRemove(flags["name"], flags["delete-disk"] != "")
	default:
		return fmt.Errorf("unknown gpu vm subcommand: %s", args[0])
	}
}

func parseVMFlags(args []string) map[string]string {
	out := map[string]string{}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if !strings.HasPrefix(a, "--") {
			continue
		}
		key := strings.TrimPrefix(a, "--")
		if eq := strings.IndexByte(key, '='); eq >= 0 {
			out[key[:eq]] = key[eq+1:]
			continue
		}
		if i+1 < len(args) && !strings.HasPrefix(args[i+1], "--") {
			out[key] = args[i+1]
			i++
		} else {
			out[key] = "true"
		}
	}
	return out
}

func detectCapability() (Capability, error) {
	cap := Capability{
		Kvm:     fileExists("/dev/kvm"),
		VmReady: fileExists("/dev/kvm"),
	}

	// Read total memory
	if b, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, line := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(line, "MemTotal:") {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					if kb, err := strconv.Atoi(fields[1]); err == nil {
						cap.RamTotalMB = kb / 1024
					}
				}
				break
			}
		}
	}

	// Check for virsh
	if _, err := exec.LookPath("virsh"); err != nil {
		cap.Verdict = "incapable"
		return cap, nil
	}

	// Check if KVM exists
	if !cap.Kvm {
		cap.Verdict = "incapable"
		return cap, nil
	}

	// Check kvmfr device for Looking Glass
	hasKvmfr := fileExists("/dev/kvmfr0")
	_ = hasKvmfr

	cap.Verdict = "ready"
	return cap, nil
}

func vmReadiness() (bool, string, *Capability) {
	cap, err := detectCapability()
	if err != nil {
		return false, "could not read GPU passthrough state: " + err.Error(), nil
	}
	if !cap.Kvm {
		return false, "/dev/kvm is missing. Hardware virtualization is disabled or unavailable.", &cap
	}
	if _, err := exec.LookPath("virsh"); err != nil {
		return false, "virsh is not installed. Install libvirt to use passthrough VMs.", &cap
	}
	return true, "", &cap
}

func vmDoList() error {
	ready, blocker, _ := vmReadiness()
	payload := vmList{Ready: ready, Blocker: blocker, Machines: []vmMachine{}}

	root := vmRoot()
	entries, err := os.ReadDir(root)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if m, ok := loadMachine(e.Name()); ok {
			payload.Machines = append(payload.Machines, m)
		}
	}
	sort.Slice(payload.Machines, func(i, j int) bool {
		return payload.Machines[i].Name < payload.Machines[j].Name
	})
	return printJSON(payload)
}

func vmDoStatus(name string) error {
	if name == "" {
		return fmt.Errorf("status needs --name")
	}
	m, ok := loadMachine(name)
	if !ok {
		return fmt.Errorf("no passthrough VM named %q", name)
	}
	return printJSON(m)
}

func loadMachine(name string) (vmMachine, bool) {
	meta, err := readMeta(name)
	if err != nil {
		return vmMachine{}, false
	}
	domain := vmDomainPrefix + name
	state := domainState(domain)
	return vmMachine{
		vmMeta: meta,
		Domain: domain,
		State:  state,
		Disk:   diskPath(name),
	}, true
}

func domainState(domain string) string {
	out, err := exec.Command("virsh", "--connect", "qemu:///system", "domstate", domain).Output()
	if err != nil {
		return "absent"
	}
	switch strings.TrimSpace(string(out)) {
	case "running":
		return "running"
	case "shut off":
		return "shutoff"
	case "paused":
		return "paused"
	default:
		return strings.TrimSpace(string(out))
	}
}

func vmDoCreate(f map[string]string) error {
	name := f["name"]
	if err := validVMName(name); err != nil {
		return err
	}
	osKind := strings.ToLower(f["os"])
	if osKind != "windows" && osKind != "linux" {
		return fmt.Errorf("gpu vm create needs --os windows|linux")
	}
	iso := f["iso"]
	if iso == "" || !fileExists(iso) {
		return fmt.Errorf("gpu vm create needs --iso <path to an install ISO> (got %q)", iso)
	}
	if _, ok := loadMachine(name); ok {
		return fmt.Errorf("a passthrough VM named %q already exists", name)
	}
	ready, blocker, cap := vmReadiness()
	if !ready {
		return fmt.Errorf("passthrough is not ready: %s", blocker)
	}

	diskGB := atoiOr(f["disk-gb"], 80)
	ramMB := atoiOr(f["ram-mb"], defaultRAMMB(cap))
	dir := vmDir(name)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	disk := diskPath(name)
	if !fileExists(disk) {
		if err := runErr("qemu-img", "create", "-f", "qcow2", disk, fmt.Sprintf("%dG", diskGB)); err != nil {
			_ = os.RemoveAll(dir)
			return fmt.Errorf("create disk: %w", err)
		}
	}

	cores := detectTopology()
	pin := buildPinPlan(cores, 0)
	var gpu GPU
	if cap != nil && cap.Passthrough != nil {
		gpu = *cap.Passthrough
	}

	spec := vmSpec{
		Domain:     vmDomainPrefix + name,
		MemMB:      ramMB,
		Pin:        pin,
		Disk:       disk,
		InstallISO: iso,
		VirtioISO:  findVirtioISO(),
		GPU:        gpu,
		KvmfrMB:    128,
		Windows:    osKind == "windows",
		AMD:        true,
	}

	xml := buildDomainXML(spec)
	domainXMLPath := filepath.Join(dir, "domain.xml")
	if err := os.WriteFile(domainXMLPath, []byte(xml), 0o644); err != nil {
		return err
	}

	if err := runErr("virsh", "--connect", "qemu:///system", "define", domainXMLPath); err != nil {
		return fmt.Errorf("define domain: %w", err)
	}

	meta := vmMeta{
		Name:   name,
		OS:     osKind,
		RAMMB:  ramMB,
		Vcpus:  len(pin.Vcpus),
		DiskGB: diskGB,
		ISO:    iso,
	}
	if err := writeMeta(name, meta); err != nil {
		return err
	}

	return printJSON(map[string]any{
		"name":    name,
		"defined": true,
		"virtio":  spec.VirtioISO != "",
		"vcpus":   len(pin.Vcpus),
		"ramMb":   ramMB,
	})
}

func vmDoStart(name string) error {
	if name == "" {
		return fmt.Errorf("start needs --name")
	}
	domain := vmDomainPrefix + name
	state := domainState(domain)
	if state != "running" {
		if err := runErr("virsh", "--connect", "qemu:///system", "start", domain); err != nil {
			return fmt.Errorf("start %q: %w", name, err)
		}
	}
	lgLaunched := launchLookingGlass(domain)
	return printJSON(map[string]any{
		"name":         name,
		"started":      true,
		"lookingGlass": lgLaunched,
	})
}

func vmDoStop(name string, force bool) error {
	if name == "" {
		return fmt.Errorf("stop needs --name")
	}
	domain := vmDomainPrefix + name
	verb := "shutdown"
	if force {
		verb = "destroy"
	}
	if err := runErr("virsh", "--connect", "qemu:///system", verb, domain); err != nil {
		return fmt.Errorf("stop %q: %w", name, err)
	}
	return printJSON(map[string]any{"name": name, "stopped": true, "force": force})
}

func vmDoRemove(name string, deleteDisk bool) error {
	if name == "" {
		return fmt.Errorf("remove needs --name")
	}
	domain := vmDomainPrefix + name
	if domainState(domain) == "running" {
		return fmt.Errorf("stop %q before removing it", name)
	}
	_ = runErr("virsh", "--connect", "qemu:///system", "undefine", "--nvram", domain)
	if deleteDisk {
		_ = os.RemoveAll(vmDir(name))
	} else {
		_ = os.Remove(filepath.Join(vmDir(name), "meta.json"))
		_ = os.Remove(filepath.Join(vmDir(name), "domain.xml"))
	}
	return printJSON(map[string]any{"name": name, "removed": true, "diskDeleted": deleteDisk})
}

func launchLookingGlass(domain string) bool {
	client, err := exec.LookPath("looking-glass-client")
	if err != nil {
		return false
	}
	args := []string{"-f", "/dev/kvmfr0"}
	if host, port := spiceEndpoint(domain); port != "" {
		args = append(args, "spice:host", host, "spice:port", port)
	}
	cmd := exec.Command(client, args...)
	cmd.Stdout, cmd.Stderr = nil, nil
	if err := cmd.Start(); err != nil {
		return false
	}
	_ = cmd.Process.Release()
	return true
}

func spiceEndpoint(domain string) (string, string) {
	out, err := exec.Command("virsh", "--connect", "qemu:///system", "domdisplay", "--type", "spice", domain).Output()
	if err != nil {
		return "", ""
	}
	uri := strings.TrimSpace(string(out))
	uri = strings.TrimPrefix(uri, "spice://")
	host, port, ok := strings.Cut(uri, ":")
	if !ok {
		return "", ""
	}
	if host == "" {
		host = "127.0.0.1"
	}
	return host, port
}

func vmRoot() string {
	if d := os.Getenv("DUSKYPORT_VM_ROOT"); d != "" {
		return d
	}
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(base, "duskyport", "vm")
}

func vmDir(name string) string    { return filepath.Join(vmRoot(), name) }
func diskPath(name string) string { return filepath.Join(vmDir(name), "disk.qcow2") }

func readMeta(name string) (vmMeta, error) {
	var m vmMeta
	b, err := os.ReadFile(filepath.Join(vmDir(name), "meta.json"))
	if err != nil {
		return m, err
	}
	return m, json.Unmarshal(b, &m)
}

func writeMeta(name string, m vmMeta) error {
	b, _ := json.MarshalIndent(m, "", "  ")
	return os.WriteFile(filepath.Join(vmDir(name), "meta.json"), b, 0o644)
}

func validVMName(name string) error {
	if name == "" {
		return fmt.Errorf("name cannot be empty")
	}
	for _, r := range name {
		ok := (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_'
		if !ok {
			return fmt.Errorf("VM name %q must be letters, digits, - or _", name)
		}
	}
	return nil
}

func defaultRAMMB(cap *Capability) int {
	half := 8192
	if cap != nil && cap.RamTotalMB > 0 {
		half = cap.RamTotalMB / 2
	}
	if half < 4096 {
		half = 4096
	}
	return (half / 1024) * 1024
}

func atoiOr(s string, def int) int {
	if s == "" {
		return def
	}
	if n, err := strconv.Atoi(s); err == nil && n > 0 {
		return n
	}
	return def
}

func findVirtioISO() string {
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local", "share")
	}
	for _, p := range []string{
		filepath.Join(base, "duskyport", "vms", ".images", "virtio-win.iso"),
		"/usr/share/virtio-win/virtio-win.iso",
		"/var/lib/libvirt/images/virtio-win.iso",
	} {
		if fileExists(p) {
			return p
		}
	}
	return ""
}

func runErr(name string, args ...string) error {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %v: %s", name, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func printJSON(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	fmt.Println(string(b))
	return nil
}
