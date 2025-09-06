% Minimal TVRA Pattern
ac_pattern('simple_threat_analysis',
    [arg('SystemName', system:name)],
    goal('G1', 
        'System {SystemName} is secure',
        [],
        [evidence(simple_threat, 'Threat analysis for {SystemName}', [])]
    )
). 