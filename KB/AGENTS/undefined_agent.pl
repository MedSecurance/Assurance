% Minimal placeholder agent for provisional/undefined evidence categories.
% It simply leaves the evidence in 'pending' status (no automatic validation).

:- module(undefined_agent, [provisional_validate/5]).

% provisional_validate(+Claim, +Context, +AArgs, +XRef, -Status)
%
% Called via agent_interface:evidence_validate/5 when
%   - evidence_category(provisional, ..., undefined_method) is selected
%   - validation_method(undefined_method, ..., undefined_agent) resolves here
%   - Category = provisional, so the predicate name is provisional_validate/5

provisional_validate(_Claim, _Context, _AArgs, _XRef, Status) :-
    % No automatic validation for provisional/undefined categories.
    % was: Keep the evidence in 'pending' so it can be reviewed or revalidated later.
    % was: Status = pending.
    % Now:
    Status = provisional.
