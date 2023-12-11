:- module(ocra_agent, [ocra_validate/5]).

ocra_validate(_Claim, _Context, AArgs, XRef, Status) :-
	format('~n*** running ocra agent...', []),
	
				% get the evidence placeholder
	atomic_list_concat(['evidence/ocra/', XRef], Repository),
	
				% get the actual arguments
	member( arg(_, model:id, ModelId), AArgs),
        member( arg(_, check:type, CheckType), AArgs),
                                % copy slim model in the repository
	atomic_list_concat( [ 'models/', ModelId, '/System.slim' ], SlimFileName),
	copy_file(SlimFileName, Repository),
                                % select the correct check that must be performed to the
                                % model
        (
          CheckType = 'consistency' ->
          check_contract_consistency(AArgs, Repository, Status) ;
          CheckType = 'refinement' ->
          check_contract_refinement(AArgs, Repository, Status) ;
          format('~n*** ERROR: ~s is not a valid check for ocra...', [CheckType]),
          fail
        ), 
        !.        
	
ocra_validate(_Claim, _Context, _AArgs, _XRef, 'ongoing') :-      
	true.

check_contract_consistency(AArgs, Repository, Status) :-
        format('~n*** running check_consistency option...', []),
        (member( arg(_, consistency:deep, DeepCheck), AArgs) ->
          (DeepCheck ->  
             (
               format('~n*** running check_consistency with deep_check option enabled', []),
               atomic_list_concat( ParametersList, ' ','System.slim --deep-check-consistency')
             );
             (
              format('~n*** running check_consistency with deep_check option disabled',[]),
              atomic_list_concat(ParametersList, ' ', 'System.slim')
             )
          ) ;
          format('~n*** running check_consistency with deep_check option disabled',[]),
          atomic_list_concat(ParametersList, ' ', 'System.slim')
        ),
        process_create('../../../../Code/compass3/scripts/check_contracts_consistency.py',
                       ParametersList,
                       [ cwd(Repository), stdout(pipe(Out)) ]),
        read_stream_to_codes(Out, Codes), close(Out),
        string_codes(OutputStr, Codes),
        
                                % output interpretation
        (
          sub_string(OutputStr,_, _, _,'Success:') -> 
          Status = 'valid' ; Status = 'invalid'
        ),
        !.

check_contract_refinement(AArgs, Repository, Status) :-
        ModelName = 'System.slim',
        format("~n*** running check_refinement option...", []),
                                % if contract option is enabled we pass it
                                % to the script
        (member( arg(_, contract:name, ContractName), AArgs) *->
          (format("~n*** running refinement check on contract: ~s", [ContractName]), 
            atomic_list_concat([ModelName, ' --contract ', ContractName],Parameters));
          format("~n*** running refinement check on all contracts.."),
          atomic_list_concat([ModelName], Parameters)
        ),

        atomic_list_concat(ParametersList, ' ', Parameters),
        write(ParametersList),
                                % launch the script
        process_create('../../../../Code/compass3/scripts/check_contracts_refinement.py',
                                %process_create('../../../../Code/compass3/scripts/check_contracts_refinement.py',
                       ParametersList,
	              [ cwd(Repository), stdout(pipe(Out)) ]),
	read_stream_to_codes(Out, Codes), close(Out),
        string_codes(OutputStr, Codes),
                                % output interpretation
        (
          sub_string(OutputStr,_, _, _,'everything is OK') -> 
          Status = 'valid' ; Status = 'invalid'
        ),
        !.


