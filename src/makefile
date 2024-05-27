etb:	agents/axiom_agent.pl agents/certificate_agent.pl agents/ichecker_agent.pl agents/ocra_agent.pl \
	com/command.pl com/param.pl com/procs.pl com/test.pl com/ui.pl \
	models_api/common.pl models_api/configuration.pl models_api/model.pl models_api/platform.pl models_api/policy.pl \
	../KB/PATTERNS/patterns_MILS.pl ../KB/PATTERNS/patterns_ISO_81001.pl \
	agent.pl assurance.pl command_etb.pl demo.pl etb_server.pl etb.pl evidence.pl export.pl instantiate.pl kb.pl \
	patterns.pl procs_etb.pl stringutil.pl
	swipl -v -o ../BUILD/etb -g etb -c etb.pl

clean: clean_cap clean_repo

clean_cap:
	find -d ../CAP -not \( -name "README.md" -or -name "CAP" \) -delete

clean_repo:
	find -d ../REPOSITORY/CASES -not \( -name "README.md" -or -name "CASES" \) -delete
	find -d ../REPOSITORY/EVIDENCE -not \( -name "README.md" -or -name "EVIDENCE" -or -name "axiom" -or -name "certificate" -or -name "ichecker" -or -name "ocra" -or -name "unknown" \) -delete
	echo "assert(ac_evidence_counter(10000))." > ../REPOSITORY/EVIDENCE/repository.pl

