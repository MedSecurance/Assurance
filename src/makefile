etb:	com/command.pl com/param.pl com/procs.pl com/test.pl com/ui.pl \
	models_api/common.pl models_api/configuration.pl models_api/model.pl models_api/platform.pl models_api/policy.pl \
	../KB/PATTERNS/patterns_MILS.pl ../KB/PATTERNS/patterns_ISO_81001.pl ../KB/PATTERNS/patterns_IoMT.pl \
	../KB/PATTERNS/patterns_MS_Risk.pl \
	agent_interface.pl assurance.pl command_etb.pl etb_server.pl etb.pl evidence.pl export.pl instantiate.pl kb.pl \
	patterns.pl procs_etb.pl stringutil.pl \
	aco/aco aco/aco_apl.pl aco/aco_ascii_tree.pl aco/aco_cli.pl aco/aco_core.pl aco/aco_processor.pl
	swipl -v -o ../BUILD/etb -g etb -c etb.pl

image:
	docker build -t o-etb ..

person-examp:	../BUILD/etb
	../BUILD/etb -c "instantiate_pattern(person, [marius, programming], 'person_examp')"

clean: clean_cap clean_repos

clean_cap:
	find ../CAP -mindepth 1 -not \( -name "README.md" -or -path "../CAP/iomt_system_example/*" -or -name "iomt_system_example.txt" -or -name "iomt_system_example" -or -path "../CAP/iso_system_example/*" -or -name "iso_system_example.txt" -or -name "iso_system_example" -or -path "../CAP/mils_system_example/*" -or -name "mils_system_example.txt" -or -name "mils_system_example" -or -path "../CAP/mils_found_only/*" -or -name "mils_found_only.txt" -or -name "mils_found_only" -or -path "../CAP/mils_op_only/*" -or -name "mils_op_only.txt" -or -name "mils_op_only" -or -path "../CAP/n_mils_found_only/*" -or -name "n_mils_found_only.txt" -or -name "n_mils_found_only" -or -path "../CAP/n_mils_op_only/*" -or -name "n_mils_op_only.txt" -or -name "n_mils_op_only" -or -path "../CAP/n_mils_system_example/*" -or -name "n_mils_system_example.txt" -or -name "n_mils_system_example" \) -delete

clean_repos: clean_cases clean_evidence clean_outlines

clean_cases:
	find ../REPOSITORY/CASES -depth -not \( -name "README.md" -or -name "CASES" \) -delete
	# echo "assert(ac_inatance_id_counter(0))." > ../REPOSITORY/CASES/repository.pl
	# echo "assert(ac_instid_counter(0))." >> ../REPOSITORY/CASES/repository.pl

clean_evidence:
	find ../REPOSITORY/EVIDENCE -depth -not \( -name "README.md" -or -name "EVIDENCE" -or -name "axiom" -or -name "certificate" -or -name "iomtmodeling" -or -name "ichecker" -or -name "ocra" -or -name "unknown" \) -delete
	echo "assert(ac_evidence_counter(10000))." > ../REPOSITORY/EVIDENCE/repository.pl

clean_outlines:
