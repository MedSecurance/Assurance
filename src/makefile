etb:	com/command.pl com/param.pl com/procs.pl com/test.pl com/ui.pl \
	models_api/common.pl models_api/configuration.pl models_api/model.pl models_api/platform.pl models_api/policy.pl \
	../KB/PATTERNS/patterns_MILS.pl ../KB/PATTERNS/patterns_ISO_81001.pl ../KB/PATTERNS/patterns_IoMT.pl \
	../KB/PATTERNS/patterns_MS_Risk.pl \
	agent_interface.pl assurance.pl command_etb.pl etb_server.pl etb.pl evidence.pl export.pl instantiate.pl kb.pl \
	patterns.pl procs_etb.pl stringutil.pl
	swipl -v -o ../BUILD/etb -g etb -c etb.pl

person-examp:	../BUILD/etb
	../BUILD/etb -c "instantiate_pattern(person, [marius, programming], 'person_examp')"

clean: clean_cap clean_repos

clean_cap:
	find ../CAP -depth -not \( -name "README.md" -or -name "CAP" -or -path "../CAP/iomt_system_example/*" -or -name "iomt_system_example.txt" -or -name "iomt_system_example" -or -path "../CAP/iso_system_example/*" -or -name "iso_system_example.txt" -or -name "iso_system_example" \) -delete

clean_repos: clean_cases clean_evidence

clean_cases:
	find ../REPOSITORY/CASES -depth -not \( -name "README.md" -or -name "CASES" \) -delete

clean_evidence:
	find ../REPOSITORY/EVIDENCE -depth -not \( -name "README.md" -or -name "EVIDENCE" -or -name "axiom" -or -name "certificate" -or -name "iomtmodeling" -or -name "ichecker" -or -name "ocra" -or -name "unknown" \) -delete
	echo "assert(ac_evidence_counter(10000))." > ../REPOSITORY/EVIDENCE/repository.pl
