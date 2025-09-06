% Minimal procedure
proc(simple, [
    % Load the pattern
    load_patterns('/Assurance/KB/PATTERNS/pattern_simple.pl'),
    update,
    
    % Set variables
    set_v(CaseId, simple_case),
    set_v(SystemName, 'simple_system'),
    
    % Instantiate the pattern
    instantiate_pattern('simple_threat_analysis', [SystemName], CaseId),
    
    % Export the case
    % export_case(CaseId, html),
    
    % Cleanup
    detach_case,
    etb_reset
]). 