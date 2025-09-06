% Minimal TVRA Agent
:- module(simple_agent, [simple_threat_validate/5]).

% Always return valid status
simple_threat_validate(_Claim, _Context, _Args, _XRef, Status) :-
    format('~n*** Starting Simple Threat Validation Agent for: ~w', [_Xref]),
    format(atom(Command), 'python3 /Assurance/KB/AGENTS/simple_gateway.py', []),
    % Call the Python script with error handling
    (   shell(Command, ResultCode)
    ->  (   ResultCode = 0
        ->  format('~n*** Python script executed successfully', []),
            % Read the result from the JSON file
            (   exists_file('/Assurance/KB/AGENTS/simple_result.txt')
            ->  open('/Assurance/KB/AGENTS/simple_result.txt', read, Stream),
                read_string(Stream, _, ResultString),
                close(Stream),
                % Remove quotes from JSON string if present
                (   sub_atom(ResultString, 0, 1, _, '"'),
                    sub_atom(ResultString, _, 1, 0, '"')
                ->  sub_atom(ResultString, 1, _, 1, CleanResult)
                ;   CleanResult = ResultString
                ),
                % Set the Status based on the result
                atom_string(Status, CleanResult),
                format('~n*** Simple Threat Validation Result: ~w ', [Status])
            ;   format('~n*** Error: simple_result.txt not found', []),
                Status = error
            )
        ;   format('~n*** Python script failed with code ~w', [ResultCode]),
            Status = error
        )
    ;   format('~n*** Error: Failed to execute Python script', []),
        Status = error
    ),
    !.