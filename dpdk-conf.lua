-- configuration for all DPDK command line parameters
-- see DPDK documentation at http://dpdk.org/doc/guides/testpmd_app_ug/run_app.html for details
-- MoonGen tries to choose reasonable defaults, so this config file can almost always be empty
-- Be careful when running MoonGen in a VM that also uses another virtio NIC, e.g., for internet access.
-- In this case it may be necessary to use the blacklist or whitelist feature in some configurations
DPDKConfig {
	-- configure the CPU cores to use, default: all cores
	--cores = {0, 1, 3, 5},
	
	-- max number of shared tasks running on core 0
	--sharedCores = 8,

	-- black or whitelist devices to limit which PCI devs are used by DPDK
	-- only one of the following examples can be used
	--pciBlacklist = {"0000:81:00.3","0000:81:00.1"},
	--pciWhitelist = {"0000:81:00.3","0000:81:00.1"},
	
	-- arbitrary DPDK command line options
	-- the following configuration allows multiple DPDK instances (use together with pciWhitelist)
	-- cf. http://dpdk.org/doc/guides/prog_guide/multi_proc_support.html#running-multiple-independent-dpdk-applications
	--cli = {
	--	"--file-prefix", "m1",
	--	"--socket-mem", "512,512",
	--}

}
